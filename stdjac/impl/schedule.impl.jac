impl schedule(f: Callable, interval: float = 0.0, at: str = "") {
    comptime assert len(params(f)) == 0, "a scheduled function takes no parameters";
    comptime assert interval >= 0.0, "@schedule's interval is a number of seconds, more than none";
    comptime assert (interval > 0.0)
        != (at != ""), "@schedule takes an interval or a time to run at, one of the two";
    note(f, "schedule", (interval, at));
}

impl run_scheduled(f: Callable[[], any]) {
    kept_call(
        "",
        lambda -> any {
            settle(f());
            return None;
        },
    );
}

impl scheduled -> list[Scheduled] {
    out: list[Scheduled] = [];
    off = os.environ.get("JAC_TICKS_OFF", "").split(",");
    comptime for n in noted("schedule") {
        if "all" not in off and n.module + "." + n.name not in off and n.name not in off {
            out.append(
                Scheduled(
                    name=n.module + "." + n.name,
                    every=n.value[0],
                    at=n.value[1],
                    run=lambda {
                        run_scheduled(
                            lambda -> any {
                                a = restore(args_type(n.decl));
                                return apply(n.decl, a);
                            },
                        )
                    },
                ),
            );
        }
    }
    return out;
}

impl start_schedule(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) {
    if len(work) == 0 {
        return;
    }
    s: dyn Scheduler = bound("schedule");
    s.open(host());
    s.start(work, on_loop);
}
