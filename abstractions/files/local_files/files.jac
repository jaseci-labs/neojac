import os;
import threading;
import time;
import from common.contract { Host }
import from files.contract { Files, Kept }
import from sqlfile { open_db }

glob FILES_FORMAT: int = 1;

glob FILES_TABLES: list[str] = [
    "create table files (id text primary key, type text not null, size integer not null, made real "
        "not null, whole integer not null)",
];

glob COLUMNS: str = "id, size, type, made, whole";

glob PIECE: int = 4194304;
def kept_of(r: any) -> Kept;

obj LocalFiles(Files) {
    has path: str = "";

    has db: any postinit,
        data_dir: str postinit,
        turn: any postinit;

    def postinit;

    def kept_as -> str;

    def open(host: dyn Host);
    def bytes_at(id: str) -> str;
    def known(id: str) -> Kept | None;

    def piece -> int;

    def begin(id: str, ctype: str);

    def append(id: str, offset: int, piece: bytes) -> int;

    def finish(id: str) -> Kept;

    def stat(id: str) -> Kept | None;

    def read(id: str, start: int, most: int) -> bytes;

    def drop(ids: list[str]);

    def every -> Iterator[Kept];
}
