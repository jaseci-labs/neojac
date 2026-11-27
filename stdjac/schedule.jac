import os;
import from jaclang.comptime { apply, args_type, note, noted, params, restore }
import from schedule.contract { Scheduled, Scheduler }

comptime def schedule(f: Callable, interval: float = 0.0, at: str = "");
def run_scheduled(f: Callable[[], any]);
def:pub scheduled -> list[Scheduled];
def:pub start_schedule(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]);
