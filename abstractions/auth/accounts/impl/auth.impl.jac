impl with_devices(db: any) {
    db.execute(DEVICES);
}

impl with_links(db: any) {
    db.execute("alter table users add column checked integer not null default 0");
    db.execute(LINKS);
}

impl FileBook.postinit {
    self.turn = threading.RLock();
    self.key = secrets.token_bytes(32);
}

impl FileBook.session(key: str) -> tuple[str, float] | None {
    with self.turn {
        for r in self.db.execute(
            "select user_id, expires from sessions where token_hash = ?", (key,)
        ) {
            return (str(r[0]), float(r[1]));
        }
    }
    return None;
}

impl FileBook.begin(key: str, user: str, expires: float, now: float) {
    with self.turn {
        self.db.execute("delete from sessions where expires <= ?", (now,));
        self.db.execute("insert into sessions values (?, ?, ?)", (key, user, expires));
        self.db.commit();
    }
}

impl FileBook.end(key: str) {
    with self.turn {
        self.db.execute("delete from sessions where token_hash = ?", (key,));
        self.db.commit();
    }
}

impl FileBook.account(name: str) -> tuple[str, str] | None {
    with self.turn {
        for r in self.db.execute(
            "select username, password from users where username = ? or (email != '' and email = ?)",
            (name, name),
        ) {
            return (str(r[0]), str(r[1]));
        }
    }
    return None;
}

impl FileBook.add(username: str, email: str, password: str, now: float) -> bool {
    with self.turn {
        for r in self.db.execute(
            "select username from users where username = ? or (email != '' and email = ?)",
            (username, email),
        ) {
            return False;
        }
        self.db.execute(
            "insert into users (username, email, password, created) values (?, ?, ?, ?)",
            (username, email, password, now),
        );
        self.db.commit();
    }
    return True;
}

impl FileBook.known(provider: str, external_id: str) -> str {
    with self.turn {
        for r in self.db.execute(
            "select user_id from identities where provider = ? and external_id = ?",
            (provider, external_id),
        ) {
            return str(r[0]);
        }
    }
    return "";
}

impl FileBook.identity(provider: str, external_id: str, user: str, now: float) -> str {
    with self.turn {
        for r in self.db.execute(
            "select user_id from identities where provider = ? and external_id = ?",
            (provider, external_id),
        ) {
            return str(r[0]);
        }
        self.db.execute(
            "insert into identities values (?, ?, ?, ?)", (provider, external_id, user, now)
        );
        self.db.commit();
    }
    return user;
}

impl FileBook.identities(provider: str) -> list[str] {
    with self.turn {
        return [
            str(r[0])
            for r in self.db.execute(
                "select external_id from identities where provider = ? order by created",
                (provider,),
            )
        ];
    }
}

impl FileBook.away_key -> bytes {
    return self.key;
}

impl FileBook.expect(code: str, key: str, expires: float, now: float) -> bool {
    with self.turn {
        self.db.execute("delete from devices where expires <= ?", (now,));
        taken = len(self.db.execute("select code from devices where code = ?", (code,)).fetchall())
            > 0;
        if not taken {
            self.db.execute("insert into devices values (?, ?, 0, '', ?)", (code, key, expires));
        }
        self.db.commit();
    }
    return not taken;
}

impl FileBook.decide(code: str, user: str, now: float) -> bool {
    with self.turn {
        said = self.db.execute(
            "update devices set answered = 1, user_id = ? where code = ? and answered = 0 and expires > ?",
            (user, code, now),
        ).rowcount;
        self.db.commit();
    }
    return said == 1;
}

impl FileBook.collect(key: str, now: float) -> tuple[bool, str] | None {
    with self.turn {
        found = self.db.execute(
            "select answered, user_id from devices where key = ? and expires > ?", (key, now)
        ).fetchall();
        if len(found) == 0 {
            return None;
        }
        answered = int(found[0][0]) == 1;
        if answered {
            self.db.execute("delete from devices where key = ?", (key,));
            self.db.commit();
        }
        return (answered, str(found[0][1]));
    }
}

impl FileBook.address(user: str) -> tuple[str, bool] {
    with self.turn {
        for r in self.db.execute("select email, checked from users where username = ?", (user,)) {
            return (str(r[0] or ""), int(r[1]) == 1);
        }
    }
    return ("", False);
}

impl FileBook.give_address(user: str, email: str) -> bool {
    with self.turn {
        for r in self.db.execute("select username from users where email = ?", (email,)) {
            return False;
        }
        given = self.db.execute(
            "update users set email = ? where username = ? and coalesce(email, '') = ''",
            (email, user),
        ).rowcount;
        self.db.commit();
    }
    return given == 1;
}

impl FileBook.link(key: str, user: str, purpose: str, expires: float, now: float) {
    with self.turn {
        self.db.execute("delete from links where expires <= ?", (now,));
        self.db.execute("insert into links values (?, ?, ?, ?)", (key, user, purpose, expires));
        self.db.commit();
    }
}

impl FileBook.followed(key: str, purpose: str, now: float) -> str {
    found = self.db.execute(
        "select user_id from links where token_hash = ? and purpose = ? and expires > ?",
        (key, purpose, now),
    ).fetchall();
    if len(found) == 0 {
        return "";
    }
    taken = self.db.execute(
        "delete from links where token_hash = ? and purpose = ? and expires > ?",
        (key, purpose, now),
    ).rowcount;
    return str(found[0][0]) if taken == 1 else "";
}

impl FileBook.check(key: str, now: float) -> str {
    with self.turn {
        user = self.followed(key, "check", now);
        if user != "" {
            self.db.execute("update users set checked = 1 where username = ?", (user,));
            self.db.execute("delete from links where user_id = ? and purpose = 'check'", (user,));
        }
        self.db.commit();
    }
    return user;
}

impl FileBook.reset(key: str, password: str, now: float) -> str {
    with self.turn {
        user = self.followed(key, "reset", now);
        if user != "" {
            self.db.execute(
                "update users set password = ?, checked = 1 where username = ?", (password, user)
            );
            self.db.execute("delete from sessions where user_id = ?", (user,));
            self.db.execute("delete from links where user_id = ?", (user,));
        }
        self.db.commit();
    }
    return user;
}

impl Accounts.kept_as -> str {
    return self.path if self.path != "" else os.path.join(self.data_dir, "accounts.db");
}

impl Accounts.open_book(host: dyn AuthHost) -> dyn Book {
    return FileBook(
        db=open_db(
            self.kept_as(),
            ACCOUNTS_FORMAT,
            [
                "create table users (username text primary key, email text, password text not null, created real, checked integer not null default 0)",
                "create table identities (provider text, external_id text, user_id text not null unique, created real, primary key (provider, external_id))",
                "create table sessions (token_hash text primary key, user_id text not null, expires real not null)",
                DEVICES,
                LINKS,
            ],
            ACCOUNTS_UPGRADES,
            host,
        ),
    );
}
