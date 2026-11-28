impl from_layout_2(db: any) {
    db.execute("alter table rows add column version integer not null default 1");
    db.execute("alter table rows add column mark integer not null default 0");
    for made in STORE_TABLES[1:10] {
        db.execute(made);
    }
    db.execute("insert into kinds select type, count(*) from rows group by type");
    top = 0;
    for r in db.execute("select coalesce(max(ord), -1) + 1 from rows") {
        top = int(r[0]);
    }
    db.execute("insert into counts values ('mark', 0)");
    db.execute("insert into counts values ('ord', ?)", (top,));
}

impl row_of(r: any) -> Row {
    return Row(
        id=str(r[0]),
        kind=str(r[1]),
        type_name=str(r[2]),
        data=str(r[3]),
        src=str(r[4]),
        dst=str(r[5]),
        ord=int(r[6]),
        version=int(r[7]),
    );
}

impl SqliteStore.postinit {
    self.db = None;
    self.data_dir = "";
}

impl SqliteStore.kept_as -> str {
    return self.path if self.path != "" else os.path.join(self.data_dir, "graph.db");
}

impl SqliteStore.open(host: dyn Host) {
    self.data_dir = host.data_dir();
    self.db = open_db(self.kept_as(), STORE_FORMAT, STORE_TABLES, STORE_UPGRADES, host);
    self.db.execute("pragma busy_timeout = 30000");
    self.db.execute("pragma journal_mode = wal");
    self.db.execute("insert or ignore into counts values ('mark', 0)");
    self.db.execute("insert or ignore into counts values ('ord', 0)");
    self.db.commit();
}

impl SqliteStore.count(name: str) -> int {
    for r in self.db.execute("select n from counts where name = ?", (name,)) {
        return int(r[0]);
    }
    return 0;
}

impl SqliteStore.types -> dict[str, int] {
    out: dict[str, int] = {};
    for r in self.db.execute("select type, n from kinds where n > 0") {
        out[str(r[0])] = int(r[1]);
    }
    return out;
}

impl SqliteStore.shapes -> dict[str, str] {
    out: dict[str, str] = {};
    for r in self.db.execute("select type, shape from shapes") {
        out[str(r[0])] = str(r[1]);
    }
    return out;
}

impl SqliteStore.of_type(type_name: str) -> list[Row] {
    out = [
        row_of(r)
        for r in self.db.execute(f"select {COLUMNS} from rows where type = ?", (type_name,))
    ];
    return out;
}

impl SqliteStore.rows(ids: list[str]) -> list[Row] {
    out: list[Row] = [];
    k = 0;
    while k < len(ids) {
        some = ids[k:k + 500];
        k += 500;
        marks = ", ".join(["?" for _ in some]);
        for r in self.db.execute(f"select {COLUMNS} from rows where id in ({marks})", tuple(some)) {
            out.append(row_of(r));
        }
    }
    return out;
}

impl SqliteStore.edges(id: str) -> list[Row] {
    out = [
        row_of(r)
        for r in self.db.execute(
            f"select {COLUMNS} from rows where kind = 'e' and src = ? union all select {COLUMNS} "
            f"from rows where kind = 'e' and dst = ? and src != dst order by ord",
            (id, id),
        )
    ];
    return out;
}

impl SqliteStore.mark -> int {
    at = self.count("mark");
    return at;
}

impl SqliteStore.since(mark: int) -> Changed | None {
    if mark < self.count("mark") - KEPT_GONE {
        return None;
    }
    out = Changed();
    out.rows = [
        row_of(r)
        for r in self.db.execute(
            f"select {COLUMNS} from rows where mark > ? order by mark, ord", (mark,)
        )
    ];
    out.gone = [str(r[0]) for r in self.db.execute("select id from gone where mark > ?", (mark,))];
    return out;
}

impl SqliteStore.write(w: Writing) -> int {
    db = self.db;
    lost: list[str] = [];
    mark = 0;
    try {
        db.execute("begin immediate");
        mark = self.count("mark") + 1;
        ord = self.count("ord");
        more: dict[str, int] = {};
        for r in w.rows {
            if r.version == 0 {
                place = r.ord;
                if r.kind == "e" and place < 0 {
                    place = ord;
                    ord += 1;
                }
                try {
                    db.execute(
                        "insert into rows values (?, ?, ?, ?, ?, ?, ?, 1, ?)",
                        (r.id, r.kind, r.type_name, r.data, r.src, r.dst, place, mark),
                    );
                    more[r.type_name] = more.get(r.type_name, 0) + 1;
                } except sqlite3.IntegrityError {
                    lost.append(r.id);
                }
                continue;
            }
            done = db.execute(
                "update rows set data = ?, version = version + 1, mark = ? where id = ? and "
                "version = ?",
                (r.data, mark, r.id, r.version),
            );
            if done.rowcount != 1 {
                lost.append(r.id);
            }
        }
        for r in w.gone {
            was = "";
            at = -1;
            for still in db.execute("select type, version from rows where id = ?", (r.id,)) {
                was = str(still[0]);
                at = int(still[1]);
            }
            if at < 0 {
                continue;
            }
            if at != r.version {
                lost.append(r.id);
                continue;
            }
            db.execute("delete from rows where id = ?", (r.id,));
            db.execute("insert into gone values (?, ?)", (r.id, mark));
            more[was] = more.get(was, 0) - 1;
        }
        for (user, id) in w.roots.items() {
            try {
                db.execute("insert into roots values (?, ?)", (user, id));
            } except sqlite3.IntegrityError {
                lost.append("the root of " + user);
            }
        }
        if w.shared != "" {
            for had in db.execute("select id from shared") {
                lost.append("the shared root");
            }
            db.execute("insert into shared values (?)", (w.shared,));
        }
        if len(lost) > 0 {
            db.rollback();
            raise StoreConflict(ids=lost);
        }
        for (name, shape) in w.shapes.items() {
            db.execute("insert or replace into shapes values (?, ?)", (name, shape));
        }
        for (name, change) in more.items() {
            db.execute("insert or ignore into kinds values (?, 0)", (name,));
            db.execute("update kinds set n = n + ? where type = ?", (change, name));
        }
        db.execute("update counts set n = ? where name = 'mark'", (mark,));
        db.execute("update counts set n = ? where name = 'ord'", (ord,));
        db.execute("delete from gone where mark <= ?", (mark - KEPT_GONE,));
        db.commit();
    } except sqlite3.Error {
        db.rollback();
        raise;
    }
    return mark;
}

impl SqliteStore.every -> Iterator[Row] {
    for r in self.db.execute("select id, kind, src, dst, version from rows") {
        yield Row(
            id=str(r[0]),
            kind=str(r[1]),
            type_name="",
            data="",
            src=str(r[2]),
            dst=str(r[3]),
            version=int(r[4]),
        );
    }
}

impl SqliteStore.root_of(user: str) -> str {
    found = "";
    for r in self.db.execute("select id from roots where user = ?", (user,)) {
        found = str(r[0]);
    }
    return found;
}

impl SqliteStore.roots -> list[str] {
    out = [str(r[0]) for r in self.db.execute("select id from roots")];
    return out;
}

impl SqliteStore.shared_root -> str {
    found = "";
    for r in self.db.execute("select id from shared") {
        found = str(r[0]);
    }
    return found;
}
