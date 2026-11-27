impl load_cpython_space(space: str, dir: str) -> any {
    sys_ = importlib.import_module("sys");
    sys_.path.insert(0, dir);
    named = "";
    with open(dir + "/@jac/space.json") as f {
        named = str(json.load(f)["runtime"]);
    }
    runtime = importlib.import_module(named);
    main = runtime.install(dir, False);
    importlib.import_module("rt.stdjac.jobs").set_job_command(
        sys.orig_argv[0:len(sys.orig_argv) - len(sys.argv) + 1], space
    );
    return main;
}

impl run_cpython_space(
    space: str,
    dir: str,
    mine: list[str],
    port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
) -> list[Scheduled] {
    main = load_cpython_space(space, dir);
    remote = importlib.import_module("rt.stdjac.remote");
    for sp in mine {
        remote.carry_in_process(sp, port);
    }
    its_port = main.in_process;
    carry_in_process(
        space,
        lambda (path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
            reply = its_port(path, body, caller, trusted);
            status: int = reply[0];
            got: bytes = reply[1];
            return (status, got);
        },
    );
    work: list[Scheduled] = [];
    for t in main.space_scheduled() {
        work.append(space_scheduled(t));
    }
    return work;
}

impl space_scheduled(t: any) -> Scheduled {
    name: str = t.name;
    every: float = t.every;
    at: str = t.at;
    work = t.run;
    return Scheduled(name=name, every=every, at=at, run=lambda { work() });
}

impl run_cpython_job(
    space: str, dir: str, name: str, input: any, note: Callable[[str, str], None]
) -> any {
    load_cpython_space(space, dir);
    theirs = importlib.import_module("json");
    out = importlib.import_module("rt.stdjac.jobs").run_job(
        name, theirs.loads(json.dumps(input)), note
    );
    return json.loads(str(theirs.dumps(out)));
}
