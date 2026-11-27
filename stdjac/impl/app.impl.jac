impl app_route(r: Request) -> Response {
    p = plan();
    if r.path.removeprefix("/__jac/app/") != "arrangement" {
        return json_fail(404, "failed", "no such endpoint");
    }
    if r.method == "POST" {
        got: any = None;
        try {
            got = json.loads(r.body.decode("utf-8")) if len(r.body) > 0 else {};
        } except ValueError {
            got = None;
        }
        if not isinstance(got, dict) {
            return json_fail(400, "rejected", "the request is not a JSON object");
        }
        fields: dict[str, any] = got;
        try {
            keep_arrangement(str(fields.get("name", "")).strip());
        } except ValueError as e {
            return json_fail(400, "rejected", str(e));
        }
        if p.window is not None {
            _relaunch.append(True);
        }
    }
    return json_ok({"names": p.arrangements, "current": p.arrangement, "chosen": p.chosen});
}

impl shown_path(path: str) -> str {
    rel = os.path.relpath(path);
    return path if rel.startswith(os.pardir) else rel;
}

impl claim_address(window: bool) -> Claim {
    p = plan();
    told = env_name(p.app, "LISTEN");
    address: str = os.environ.get(DEV_LISTEN, "");
    elsewhere = "";
    if address != "" and os.environ.get(DEV_SERVED, "") != "" {
        elsewhere = "`neojac dev` chose that address, behind its page's dev server: start it again for another.";
    } elif address != "" {
        elsewhere = f"To listen elsewhere, run `neojac dev {p.app}` with another --listen.";
    } elif not window {
        address = os.environ.get(told, "");
        if address == "" {
            address = LISTEN_AT;
        }
        elsewhere = f"To listen elsewhere, start it with {told}=<host>:<port>.";
    }
    if window {
        address = "127.0.0.1:" + (address.rpartition(":")[2] if address != "" else "0");
    }
    try {
        return transport().claim(address);
    } except CannotListen as e {
        said = f"{p.app} can't listen on {address}: {e.reason}.";
        raise CannotStart(why=said if elsewhere == "" else f"{said} {elsewhere}");
    }
}

impl open_data(callers: bool) {
    wrong: list[DataError] = [];
    if callers {
        try {
            open_auth();
        } except DataError as e {
            wrong.append(e);
        }
    }
    store: dyn Store = bound("store");
    try {
        graph_open(store, StoreCodec(), host());
    } except DataError as e {
        if e.path == "" {
            e.path = store.kept_as();
        }
        wrong.append(e);
    }
    try {
        open_files();
    } except DataError as e {
        wrong.append(e);
    }
    p = plan();
    for done in upgrades_made() {
        sys.stderr.write(f"{p.app}: {done}\n");
    }
    if len(wrong) == 0 {
        return;
    }
    d = data_dir();
    out = f"{p.app} can't start with the data it kept in {shown_path(d)}:\n";
    names = [
        os.path.basename(e.path) if e.path.startswith(os.path.join(d, "")) else e.path
        for e in wrong
    ];
    width = max([len(name) for name in names]);
    for (name, e) in zip(names, wrong) {
        out += f"  {name}{' ' * (width - len(name))}  {e.problem}\n";
    }
    if os.environ.get(env_name(p.app, "DATA"), "") != "" {
        out += "To start empty, move that directory aside.";
    } else {
        out += f"To set that data aside and start empty, run `neojac run {p.app} --fresh` in the project, or start the program with {FRESH}=1.";
    }
    raise CannotStart(why=out);
}

impl opened(what: str, opening: Callable[[], bool]) -> bool {
    try {
        return opening();
    } except DataError as e {
        raise CannotStart(why=f"{plan().app} can't start its {what}: {e}.");
    }
}

impl set_aside(d: str) {
    if os.environ.get(FRESH, "") in ["", "0"] {
        return;
    }
    del os.environ[FRESH];
    p = plan();
    told = env_name(p.app, "DATA");
    if os.environ.get(told, "") != "" {
        raise CannotStart(
            why=f"{p.app} keeps its data where {told} says, in {shown_path(d)}: only a project's own data is set aside for a fresh start. Move that directory yourself.",
        );
    }
    if not os.path.isdir(d) or len(os.listdir(d)) == 0 {
        return;
    }
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S");
    aside = f"{d}.{stamp}";
    k = 1;
    while os.path.exists(aside) {
        k += 1;
        aside = f"{d}.{stamp}-{k}";
    }
    os.rename(d, aside);
    sys.stderr.write(
        f"{p.app}: its data is set aside in {shown_path(aside)}, and it starts with none\n"
    );
}

impl in_process(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
    if path.startswith("/__jac/stream/") {
        return pull_stream(path[len("/__jac/stream/"):len(path)]);
    }
    (at, _mark, query) = path.partition("?");
    reply = dispatch(Request(method="POST", path=at, query=query, body=body), caller, trusted);
    events = reply.events;
    if events is not None {
        return open_stream(events);
    }
    return (reply.status, reply.body);
}

impl space_scheduled -> list[Scheduled] {
    return scheduled();
}

impl handle(r: Request) -> Response {
    return dispatch(r, auth_caller(r.headers), deployment_signed(r));
}

impl reply_of(got: tuple[int, bytes]) -> Response {
    return Response(status=got[0], body=got[1]);
}

impl stream_of(got: tuple[int, bytes, Iterator[bytes] | None]) -> Response {
    return Response(status=got[0], body=got[1], events=got[2]);
}

impl too_often(seconds: int) -> Response | None {
    if seconds <= 0 {
        return None;
    }
    failed = json_fail(429, "rejected", f"called too often: try again in {seconds} seconds");
    failed.headers = {"Retry-After": str(seconds)};
    return failed;
}

impl files_request(r: Request, caller: str, trusted: bool) -> Response {
    p = plan();
    if r.path.rstrip("/") == "/__jac/files/held" {
        if not trusted or r.method != "POST" {
            return json_fail(404, "failed", "no such file");
        }
        return json_ok(held_files());
    }
    target = urllib.parse.unquote(asked(r.query, "for"));
    space = target.split("/")[0]
        if r.method == "POST"
        else urllib.parse.unquote(asked(r.query, "space"));
    if r.method == "POST" and carried(space) {
        return stream_of(carry_stream(space, r.path + "?" + r.query, r.body, caller, trusted));
    }
    if space != "" and space not in p.spaces and not carried(space) {
        if r.method != "POST" {
            url = remote_url(space);
            if url == "" {
                return json_fail(404, "failed", "no such file");
            }
            return Response(
                status=307, ctype="text/plain", headers={"Location": url.rstrip("/") + r.path}
            );
        }
        if "/__jac/call/" + target in p.forwarded or "/__jac/spawn/" + target in p.forwarded {
            return forward_file(remote_url(space), r);
        }
        return json_fail(404, "failed", "no such endpoint");
    }
    return files_route(
        r,
        lambda (module: str, name: str) -> Response | None {
            no = refused(module, name, caller, trusted);
            return reply_of(no) if no is not None else None;
        },
        lambda (module: str, name: str) -> int {
            return 0 if trusted else limited_files(module, name, caller, r.client);
        },
    );
}

impl dispatch(r: Request, caller: str, trusted: bool) -> Response {
    p = plan();
    if r.path.startswith("/__jac/app/") {
        return app_route(r);
    }
    if r.path == "/__jac/files" or r.path.startswith("/__jac/files/") {
        return files_request(r, caller, trusted);
    }
    call = r.path.startswith("/__jac/call/") or r.path.startswith("/__jac/spawn/");
    space = r.path.split("/")[3] if call and r.path.count("/") > 3 else "";
    if r.method == "POST" and call and carried(space) {
        return stream_of(carry_stream(space, r.path, r.body, caller, trusted));
    }
    if p.accounts != "" and r.path.startswith("/__jac/auth") {
        return stream_of(
            forward_remote(
                remote_url(p.accounts), r.path, r.body, r.headers.get("authorization", ""), r.method
            ),
        );
    }
    if r.method == "POST" and r.path in p.forwarded {
        return stream_of(
            forward_remote(
                remote_url(p.forwarded[r.path]),
                r.path,
                r.body,
                r.headers.get("authorization", ""),
                r.method,
            ),
        );
    }
    answered = auth_route(r) if r.path.startswith("/__jac/auth") else None;
    if answered is not None {
        return answered;
    }
    if r.method == "POST" and call and space not in p.spaces {
        return json_fail(404, "failed", "no such endpoint");
    }
    if r.method == "POST" and r.path.startswith("/__jac/") {
        named = r.path.split("/");
        if call and not trusted and len(named) == 6 {
            often = too_often(limited(named[4], named[5], caller, r.client));
            if often is not None {
                return often;
            }
        }
        return stream_of(answer_stream(r.path, r.body, caller, trusted));
    }
    route = route_of(r.method, r.path);
    if route is not None {
        if not trusted {
            often = too_often(limited(route.module, route.name, caller, r.client));
            if often is not None {
                return often;
            }
        }
        (status, ctype, body, sent_with) = route_answer(
            route, r.path, r.query, r.body, caller, trusted
        );
        return Response(status=status, ctype=ctype, body=body, headers=sent_with);
    }
    pages = sorted(p.pages, key=lambda (g: Page) -> int { return -len(g.base); });
    served = os.environ.get(DEV_SERVED, "");
    for g in pages {
        if g.space == served
            or not (g.base == "/" or r.path.startswith(g.base) or r.path == g.base.rstrip("/"))
        {
            continue;
        }
        rest = r.path
            if g.base == "/"
            else r.path[len(g.base):] if len(r.path) > len(g.base) else "/";
        if g.held {
            return held_file(g.space, rest, g.headers, g.routes);
        }
        return static_file(
            os.path.join(os.path.dirname(sys.executable), "pages", g.space),
            rest,
            g.headers,
            g.routes,
        );
    }
    return Response(status=404, ctype="text/plain", body=b"not found");
}

impl refuse_unserved {
    if transport().serves_paths() {
        return;
    }
    p = plan();
    wants = [f"`{r.module}.{r.name}` at {r.path}" for r in routes()] + [
        f"the page space `{g.space}` at {g.base}"
        for g in p.pages
        if not g.held
    ];
    if len(wants) == 0 {
        return;
    }
    raise CannotStart(
        why=f"{p.app} can't start with the transport it was given: it serves {', '.join(wants)}, and that transport carries calls and serves no paths. Bind one that serves them in jac.toml's [transport], or pick it where the program runs with JAC_TRANSPORT.",
    );
}

impl ThreadTurns.take(work: Callable[[], None]) {
    with self.ready {
        work();
    }
}

impl ThreadTurns.rest {
    self.ready.wait();
}

impl ThreadTurns.wake {
    self.ready.notify_all();
}

impl ThreadTurns.waits -> bool {
    return threading.get_ident() != self.loop;
}

impl start {
    p = plan();
    if p.carried {
        open_data(False);
        store_in_turn(ThreadTurns());
        return;
    }
    if opened("jobs", lambda -> bool { return ran_job(); }) {
        sys.exit(0);
    }
    if p.has_entry {
        ready();
        return;
    }
    win = p.window;
    if win is not None {
        w: Window = win;
        window_host().run_asked(w.title, w.width, w.height, w.min_width, w.min_height);
    }
    refuse_unserved();
    claim = claim_address(win is not None);
    work = ready();
    ticks: list[Tick] = [];
    if win is not None {
        wh = window_host();
        ticks.append(
            Tick(
                name="window",
                every=0.5,
                run=lambda {
                    wh.watch();
                    if len(_relaunch) > 0 {
                        wh.relaunch();
                    }
                },
            ),
        );
    }
    if win is None or len(p.spaces) > 0 {
        open_data(True);
    }
    store_in_turn(ThreadTurns());
    opened(
        "scheduled functions",
        lambda -> bool {
            start_schedule(work, on_loop);
            return True;
        },
    );
    stopped_as_asked();
    if win is not None {
        transport().listen(claim, handle, ticks, window_host().open);
    } else {
        transport().listen(claim, handle, ticks, None);
    }
}

impl stopped_as_asked {
    if os.getpid() != 1 {
        return;
    }
    for asked in [signal.SIGTERM, signal.SIGINT] {
        signal.signal(asked, lambda (number: int, frame: any) { os._exit(128 + number); });
    }
}

impl ready -> list[Scheduled] {
    p = plan();
    set_aside(data_dir());
    work = scheduled() if len(p.spaces) > 0 else [];
    for h in p.hosted {
        work = work + space_host(h.host).start(h.space, space_code(h.space), p.spaces, in_process);
    }
    return work;
}
