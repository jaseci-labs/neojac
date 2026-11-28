impl laid_out(db: any) -> tuple[int, int] {
    for r in db.execute(
        "select user_version, (select count(*) from sqlite_master) from pragma_user_version"
    ) {
        return (int(r[0]), int(r[1]));
    }
    return (0, 0);
}

impl open_db(
    path: str,
    format: int,
    tables: list[str],
    upgrades: list[Upgrade] = [],
    host: dyn Host | None = None,
) -> any {
    d = os.path.dirname(path);
    if d != "" {
        os.makedirs(d, exist_ok=True);
    }
    db = sqlite3.connect(path, check_same_thread=False);
    (version, made) = laid_out(db);
    if version == 0 and made == 0 {
        db.execute("begin immediate");
        (version, made) = laid_out(db);
        if version == 0 and made == 0 {
            for t in tables {
                db.execute(t);
            }
            db.execute("pragma user_version = " + str(format));
            db.commit();
            return db;
        }
        db.rollback();
    }
    if version == format {
        return db;
    }
    db.close();
    reads = f"(layout {version}; this one reads layout {format})";
    if version > format {
        raise DataError(path=path, problem=f"is laid out as a newer neojac writes it {reads}");
    }
    steps: list[Upgrade] = [];
    for n in range(version, format) {
        step = [u for u in upgrades if u.since == n];
        if len(step) != 1 {
            raise DataError(
                path=path,
                problem=f"is laid out as an older neojac wrote it, which this one can't upgrade "
                    f"{reads}",
            );
        }
        steps.append(step[0]);
    }
    kept = f"{path}.layout{version}";
    db = sqlite3.connect(path, check_same_thread=False);
    db.execute("begin immediate");
    if laid_out(db)[0] == format {
        db.rollback();
        return db;
    }
    shutil.copyfile(path, kept);
    try {
        for u in steps {
            u.apply(db);
        }
        db.execute("pragma user_version = " + str(format));
        db.commit();
    } except Exception as e {
        db.rollback();
        db.close();
        os.remove(kept);
        raise DataError(
            path=path,
            problem=f"could not be upgraded {reads}, and is as it was: {type(e).__name__}: {e}",
        );
    }
    if host is not None {
        host.upgraded(
            f"upgraded {os.path.basename(path)} from layout {version} to {format}; the file as it "
                f"was is kept as {os.path.basename(kept)}",
        );
    }
    return db;
}
