import threading;
import time;
import from common.contract { Host }
import from schedule.contract { Scheduled, Scheduler, next_at }

obj LoopSchedule(Scheduler) {
    has tick: float = 0.25;
    def open(host: dyn Host);

    def start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]);
}

def run_once(s: Scheduled);
def turn_of(s: Scheduled, waiting: list[bool], at: int) -> Callable[[], None];
def due_after(s: Scheduled, now: float) -> float;
def first_due(s: Scheduled, start: float) -> float;
def keep_time(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None], tick: float);
