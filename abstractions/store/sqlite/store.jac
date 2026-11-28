import os;
import sqlite3;
import from common.contract { Host }
import from sqlfile { Upgrade, open_db }
import from store.contract { Changed, Row, Store, StoreConflict, Writing }

glob STORE_FORMAT: int = 3;

glob KEPT_GONE: int = 4096;

glob STORE_TABLES: list[str] = [
    "create table rows (id text primary key, kind text, type text, data text, src text, dst text, "
    "ord integer, version integer not null, mark integer not null)",
    "create index rows_src on rows (src) where kind = 'e'",
    "create index rows_dst on rows (dst) where kind = 'e'",
    "create index rows_type on rows (type)",
    "create index rows_mark on rows (mark)",
    "create table gone (id text not null, mark integer not null)",
    "create index gone_mark on gone (mark)",
    "create table counts (name text primary key, n integer not null)",
    "create table kinds (type text primary key, n integer not null)",
    "create table shapes (type text primary key, shape text not null)",
    "create table roots (user text primary key, id text not null)",
    "create table shared (id text not null)",
];
def from_layout_2(db: any);

glob STORE_UPGRADES: list[Upgrade] = [Upgrade(since=2, apply=from_layout_2)];
def row_of(r: any) -> Row;

glob COLUMNS: str = "id, kind, type, data, src, dst, ord, version";

obj SqliteStore(Store) {
    has path: str = "";

    has db: any postinit,
        data_dir: str postinit;

    def postinit;

    def kept_as -> str;

    def open(host: dyn Host);

    def count(name: str) -> int;

    def types -> dict[str, int];

    def shapes -> dict[str, str];

    def of_type(type_name: str) -> list[Row];

    def rows(ids: list[str]) -> list[Row];

    def edges(id: str) -> list[Row];

    def mark -> int;

    def since(mark: int) -> Changed | None;

    def write(w: Writing) -> int;

    def every -> Iterator[Row];

    def root_of(user: str) -> str;

    def roots -> list[str];

    def shared_root -> str;
}
