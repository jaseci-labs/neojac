import datetime;
import from common.contract { Host }

obj Scheduled {
    has name: str,
        every: float,
        run: Callable[[], None],
        at: str = "";
}

obj Scheduler {
    def open(host: dyn Host) abst;
    def start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) abst;
}

def cron_fields(at: str) -> list[list[int]];
def cron_field(text: str, low: int, high: int, what: str) -> list[int];
def next_at(at: str, after: float) -> float;
