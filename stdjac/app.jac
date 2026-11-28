import datetime;
import json;
import os;
import signal;
import sys;
import threading;
import urllib.parse;
import from common.contract { DataError }
import from schedule.contract { Scheduled }
import from store.contract { Store }
import from transport.contract { CannotListen, Claim, Request, Response, Tick, json_fail }

glob _relaunch: list[bool] = [];
def app_route(r: Request) -> Response;
def shown_path(path: str) -> str;

glob FRESH: str = "JAC_FRESH";

glob DEV_LISTEN: str = "JAC_DEV_LISTEN",
     DEV_SERVED: str = "JAC_DEV_SERVED";

obj CannotStart(Exception) {
    has why: str;
}

glob LISTEN_AT: str = "127.0.0.1:8000";
def claim_address(window: bool) -> Claim;
def open_data(callers: bool);
def opened(what: str, opening: Callable[[], bool]) -> bool;
def set_aside(d: str);
def:pub in_process(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes];
def:pub space_scheduled -> list[Scheduled];
def handle(r: Request) -> Response;

def reply_of(got: tuple[int, bytes]) -> Response;
def stream_of(got: tuple[int, bytes, Iterator[bytes] | None]) -> Response;
def too_often(seconds: int) -> Response | None;
def files_request(r: Request, caller: str, trusted: bool) -> Response;
def dispatch(r: Request, caller: str, trusted: bool) -> Response;
def refuse_unserved;

obj ThreadTurns(Turns) {
    has ready: any = threading.Condition(threading.RLock()),
        loop: int = threading.get_ident();

    def take(work: Callable[[], None]);

    def rest;

    def wake;

    def waits -> bool;
}

def start;
def stopped_as_asked;
def ready -> list[Scheduled];

with entry {
    try {
        start();
    } except CannotStart as e {
        sys.stderr.write(e.why + "\n");
        sys.exit(1);
    }
}
