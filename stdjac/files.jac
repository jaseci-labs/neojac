import json;
import re;
import secrets;
import time;
import urllib.parse;
import from jaclang.comptime { holds, note, noted }
import from files.contract { Files, Kept }
import from transport.contract { Request, Response, json_fail }

glob OCTETS: str = "application/octet-stream";

glob READ: int = 4194304;

glob MOST: int = 16777216;

glob UNHELD_SECONDS: float = 3600.0,
     UNFINISHED_SECONDS: float = 86400.0;

glob ID_FORM: str = "[0-9a-f]{64}",
     CTYPE_FORM: str = "[a-z0-9][a-z0-9!#$&^_.+-]{0,62}/[a-z0-9][a-z0-9!#$&^_.+-]{0,62}";

glob BEGINS: dict[str, bytes] = {
    "image/png": b"\x89PNG\r\n\x1a\n",
    "image/jpeg": b"\xff\xd8\xff",
    "image/gif": b"GIF8",
    "image/webp": b"RIFF",
    "application/pdf": b"%PDF-",
};

glob SHOWN: list[str] = [
    "image/png",
    "image/jpeg",
    "image/gif",
    "image/webp",
    "image/avif",
    "audio/mpeg",
    "audio/ogg",
    "audio/wav",
    "video/mp4",
    "video/webm",
    "application/pdf",
    "text/plain",
];

obj FileError(Exception) {
    has detail: str;

    def __str__ -> str;
}

glob _files: list[dyn Files] = [];
def kept -> dyn Files;

obj FilesHost(ProgramHost) {
    def data_dir -> str;
}

glob _wanted: list[bool] = [];
def:pub holds_files -> bool;
def:pub open_files -> str;
def ctype_of(t: str) -> str;
def begins_as(ctype: str, head: bytes);

obj File {
    has id: str = "",
        size: int = 0,
        ctype: str = OCTETS;

    def init(data: bytes | Iterator[bytes] = b"", ctype: str = OCTETS);
    def read -> bytes;
    def chunks(most: int = READ) -> Iterator[bytes];
    def url -> str;
}

def keep(data: bytes | Iterator[bytes], ctype: str) -> Kept;
comptime def accepts(f: Callable, most: int, kinds: list[str] = []);

obj Accepted {
    has most: int = MOST,
        kinds: list[str] = [];
}

glob _accepted: dict[str, Accepted] = {},
     _accepted_read: list[bool] = [],
     _takes: dict[str, bool] = {};
def:pub takes_files(module: str, name: str) -> bool;
def accepted(module: str, name: str) -> Accepted | None;
def fits(a: Accepted, size: int, ctype: str);
def:pub files_in[T](v: T) -> list[str];
def:pub arrive[T](v: T, module: str, name: str);

glob _others: dict[str, Callable[[], list[str] | None]] = {};
def:pub also_held(whose: str, ask: Callable[[], list[str] | None]);
def:pub sweep_files(held: dict[str, bool]) -> int;

def:pub asked(query: str, name: str) -> str;
def ranged(said: str, size: int) -> tuple[int, int] | None;
def sent_headers(k: Kept) -> dict[str, str];
def send_file(r: Request, k: Kept) -> Response;
def pieces_of(id: str, start: int, count: int) -> Iterator[bytes];
def:pub files_route(
    r: Request, admits: Callable[[str, str], Response | None], often: Callable[[str, str], int]
) -> Response;
def begin_file(r: Request, a: Accepted, seconds: int) -> Response;
def take_piece(r: Request, k: Kept, a: Accepted) -> Response;
def finish_file(k: Kept, a: Accepted) -> Response;
