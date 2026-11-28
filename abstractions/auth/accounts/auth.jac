import os;
import secrets;
import threading;
import from accountbook { AccountsAuth, Book }
import from auth.contract { AuthHost }
import from sqlfile { Upgrade, open_db }

glob DEVICES: str = "create table devices (code text primary key, key text not null unique, "
    "answered integer not null, user_id text not null, expires real not null)";
def with_devices(db: any);

glob LINKS: str = "create table links (token_hash text primary key, user_id text not null, purpose "
    "text not null, expires real not null)";
def with_links(db: any);

glob ACCOUNTS_FORMAT: int = 3,
     ACCOUNTS_UPGRADES: list[Upgrade] = [
         Upgrade(since=1, apply=with_devices),
         Upgrade(since=2, apply=with_links),
     ];

obj FileBook(Book) {
    has db: any;

    has turn: any postinit,
        key: bytes postinit;

    def postinit;

    def session(key: str) -> tuple[str, float] | None;

    def begin(key: str, user: str, expires: float, now: float);

    def end(key: str);

    def account(name: str) -> tuple[str, str] | None;

    def add(username: str, email: str, password: str, now: float) -> bool;

    def known(provider: str, external_id: str) -> str;

    def identity(provider: str, external_id: str, user: str, now: float) -> str;

    def identities(provider: str) -> list[str];

    def away_key -> bytes;

    def expect(code: str, key: str, expires: float, now: float) -> bool;

    def decide(code: str, user: str, now: float) -> bool;

    def collect(key: str, now: float) -> tuple[bool, str] | None;

    def address(user: str) -> tuple[str, bool];

    def give_address(user: str, email: str) -> bool;

    def link(key: str, user: str, purpose: str, expires: float, now: float);
    def followed(key: str, purpose: str, now: float) -> str;

    def check(key: str, now: float) -> str;

    def reset(key: str, password: str, now: float) -> str;
}

obj Accounts(AccountsAuth) {
    has path: str = "";

    def kept_as -> str;

    def open_book(host: dyn AuthHost) -> dyn Book;
}
