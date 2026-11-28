import from schedule.contract { Scheduled }

obj:pub SpaceHost {
    has start: Callable[[
            str,
            str,
            list[str],
            Callable[[str, bytes, str, bool], tuple[int, bytes]],
        ], list[Scheduled]],
        job: Callable[[str, str, str, any, Callable[[str, str], None]], any] | None = None;
}

obj:pub WindowHost {
    has run_asked: Callable[[str, int, int, int, int], None],
        open: Callable[[int], None],
        watch: Callable[[], None],
        relaunch: Callable[[], None];
}

glob _window_host: list[WindowHost] = [];

def:pub register_window_host(h: WindowHost) -> bool;

def:pub window_host -> WindowHost;

glob _space_hosts: dict[str, SpaceHost] = {};

def:pub register_space_host(host: str, h: SpaceHost) -> bool;

def:pub space_host(host: str) -> SpaceHost;
