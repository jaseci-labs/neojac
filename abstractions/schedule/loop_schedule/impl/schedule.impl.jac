impl LoopSchedule.open(host: dyn Host) {}

impl LoopSchedule.start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) {
    tick = self.tick;
    threading.Thread(target=lambda { keep_time(work, on_loop, tick) }, daemon=True).start();
}

impl run_once(s: Scheduled) {
    try {
        s.run();
    } except Exception as e {
        print(s.name + " failed: " + str(e));
    }
}

impl turn_of(s: Scheduled, waiting: list[bool], at: int) -> Callable[[], None] {
    return lambda {
        try {
            run_once(s);
        } finally {
            waiting[at] = False;
        }
    };
}

impl keep_time(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None], tick: float) {
    start = time.time();
    due: list[float] = [first_due(s, start) for s in work];
    waiting: list[bool] = [False for _ in work];
    forever {
        now = time.time();
        for k in range(len(work)) {
            if due[k] <= now and not waiting[k] {
                due[k] = due_after(work[k], now);
                waiting[k] = True;
                on_loop(turn_of(work[k], waiting, k));
            }
        }
        time.sleep(tick);
    }
}

impl due_after(s: Scheduled, now: float) -> float {
    if s.at == "" {
        return now + s.every;
    }
    try {
        return next_at(s.at, now);
    } except ValueError as e {
        print(s.name + " is not scheduled again: " + str(e));
        return float("inf");
    }
}

impl first_due(s: Scheduled, start: float) -> float {
    return start if s.at == "" else due_after(s, start);
}
