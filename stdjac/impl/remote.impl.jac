impl RemoteError.__str__ -> str {
    return self.detail;
}

impl Endpoint.path -> str {
    return endpoint_path(self.space, self.module, self.name, self.is_walker);
}

impl endpoint_path(space: str, module: str, name: str, spawns: bool) -> str {
    return ("/__jac/spawn/" if spawns else "/__jac/call/") + space + "/" + module + "/" + name;
}

impl transport -> dyn Transport {
    if len(_transport) == 0 {
        t: dyn Transport = bound("transport");
        t.open(host());
        _transport.append(t);
    }
    return _transport[0];
}

impl on_loop(work: Callable[[], None]) {
    transport().on_loop(work);
}

impl loop_serving -> bool {
    return len(_transport) > 0 and _transport[0].serving();
}

impl serve_endpoint(e: Endpoint) {
    _endpoints[e.path()] = e;
}

impl call_endpoint(space: str, module: str, name: str, spawns: bool, args: dict[str, any]) -> any {
    path = endpoint_path(space, module, name, spawns);
    body = json.dumps({"fields": args} if spawns else {"args": args}).encode("utf-8");
    endpoint = module + "." + name;
    text = "";
    if space in _in_process {
        (_, raw) = _in_process[space](path, body, current_caller(), True);
        text = raw.decode("utf-8");
    } else {
        text = carried_reply(space, path, endpoint, body);
    }
    return reply_data(space, endpoint, text);
}

impl stream_endpoint(space: str, module: str, name: str, args: dict[str, any]) -> Iterator[any] {
    path = endpoint_path(space, module, name, False);
    body = json.dumps({"args": args}).encode("utf-8");
    if space in _in_process {
        return carried_items(space, module + "." + name, path, body);
    }
    return carried_stream(space, path, module + "." + name, body);
}

impl reply_data(space: str, endpoint: str, text: str) -> any {
    reply: dict[str, any] = {};
    try {
        reply = json.loads(text);
    } except ValueError as e {
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
    }
    if reply.get("ok", False) {
        return reply.get("data", None);
    }
    raise reply_error(space, endpoint, reply);
}

impl reply_error(space: str, endpoint: str, reply: dict[str, any]) -> RemoteError {
    detail = str(reply.get("detail", ""));
    kind = str(reply.get("kind", ""));
    if kind == "rejected" {
        return RemoteRejected(space=space, endpoint=endpoint, detail=detail);
    }
    if kind == "unavailable" {
        return RemoteUnavailable(space=space, endpoint=endpoint, detail=detail);
    }
    return RemoteFailed(space=space, endpoint=endpoint, detail=detail);
}

impl carry_in_process(space: str, port: Callable[[str, bytes, str, bool], tuple[int, bytes]]) {
    _in_process[space] = port;
    also_held(
        "the program" if plan().carried else space,
        lambda -> list[str] | None { return held_through(port); },
    );
}

impl held_through(port: Callable[[str, bytes, str, bool], tuple[int, bytes]]) -> list[str] | None {
    (status, raw) = port("/__jac/files/held", b"", "", True);
    if status == 404 {
        return [];
    }
    if status != 200 {
        return None;
    }
    said: any = None;
    try {
        said = json.loads(raw.decode("utf-8"));
    } except ValueError {
        return None;
    }
    if not isinstance(said, dict) {
        return None;
    }
    reply: dict[str, any] = said;
    ids: any = reply.get("data", None);
    if not reply.get("ok", False) or not isinstance(ids, list) {
        return None;
    }
    listed: list[any] = ids;
    return [str(id) for id in listed];
}

impl open_stream(events: Iterator[bytes]) -> tuple[int, bytes] {
    _opened[0] += 1;
    id = str(_opened[0]);
    _open_streams[id] = events;
    return (200, json.dumps({"ok": True, "stream": id}).encode("utf-8"));
}

impl pull_stream(rest: str) -> tuple[int, bytes] {
    closing = rest.endswith("/close");
    id = rest[0:len(rest) - 6] if closing else rest;
    if id not in _open_streams {
        return reply_fail(404, "rejected", "no such stream");
    }
    events = _open_streams[id];
    if closing {
        del _open_streams[id];
        events.close();
        return (200, b'{"ok": true}');
    }
    text = "";
    for frame in events {
        text = frame.decode("utf-8");
        break;
    }
    if text.startswith("data: ") {
        return (200, ('{"ok": true, "data": ' + text[6:len(text)].strip() + "}").encode("utf-8"));
    }
    del _open_streams[id];
    events.close();
    if text.startswith("event: error") {
        return (500, text[text.index("data: ") + 6:len(text)].strip().encode("utf-8"));
    }
    return (200, b'{"ok": true, "end": true}');
}

impl stream_opened(raw: bytes) -> str {
    if not raw.startswith(b'{"ok"') or b'"stream"' not in raw[0:40] {
        return "";
    }
    try {
        reply: dict[str, any] = json.loads(raw.decode("utf-8"));
        return str(reply.get("stream", "")) if "data" not in reply else "";
    } except ValueError {
        return "";
    }
}

impl carried_items(space: str, endpoint: str, path: str, body: bytes) -> Iterator[any] {
    port = _in_process[space];
    (_, raw) = port(path, body, current_caller(), True);
    id = stream_opened(raw);
    if id == "" {
        reply_data(space, endpoint, raw.decode("utf-8"));
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail="the reply is no stream");
    }
    ended = False;
    try {
        forever {
            (_, got) = port("/__jac/stream/" + id, b"", current_caller(), True);
            reply: dict[str, any] = {};
            try {
                reply = json.loads(got.decode("utf-8"));
            } except ValueError as e {
                raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
            }
            if not reply.get("ok", False) {
                ended = True;
                raise reply_error(space, endpoint, reply);
            }
            if reply.get("end", False) {
                ended = True;
                return;
            }
            yield reply.get("data", None);
        }
    } finally {
        if not ended {
            port("/__jac/stream/" + id + "/close", b"", current_caller(), True);
        }
    }
}

impl carry_stream(
    space: str, path: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, bytes, Iterator[bytes] | None] {
    (status, raw) = _in_process[space](path, body, caller, trusted);
    id = stream_opened(raw);
    if id == "" {
        return (status, raw, None);
    }
    return (200, b"", carried_events(space, id, caller, trusted));
}

impl carried_events(space: str, id: str, caller: str, trusted: bool) -> Iterator[bytes] {
    port = _in_process[space];
    ended = False;
    try {
        forever {
            (_, got) = port("/__jac/stream/" + id, b"", caller, trusted);
            reply: dict[str, any] = {};
            try {
                reply = json.loads(got.decode("utf-8"));
            } except ValueError {
                reply = {"ok": False, "kind": "failed", "detail": "the stream's reply is not JSON"};
            }
            if not reply.get("ok", False) {
                ended = True;
                yield error_event(str(reply.get("kind", "failed")), str(reply.get("detail", "")));
                return;
            }
            if reply.get("end", False) {
                ended = True;
                yield b"event: end\ndata: {}\n\n";
                return;
            }
            yield b"data: " + json.dumps(reply.get("data", None)).encode("utf-8") + b"\n\n";
        }
    } finally {
        if not ended {
            port("/__jac/stream/" + id + "/close", b"", caller, trusted);
        }
    }
}

impl carried(space: str) -> bool {
    return space in _in_process;
}

impl crossing_request(space: str, path: str, endpoint: str, body: bytes) -> tuple[str, Request] {
    url = remote_url(space);
    if url == "" {
        raise RemoteUnavailable(
            space=space,
            endpoint=endpoint,
            detail=f"no URL for space '{space}' (JAC_REMOTE_{space.upper()})",
        );
    }
    headers = {"content-type": "application/json"};
    token = os.environ.get("JAC_REMOTE_TOKEN", "");
    if token != "" {
        headers["authorization"] = "Bearer " + token;
    }
    key = os.environ.get("JAC_DEPLOY_KEY", "");
    if key != "" {
        headers["x-jac-key"] = key;
    }
    return (url, Request(method="POST", path=path, headers=headers, body=body));
}

impl carried_reply(space: str, path: str, endpoint: str, body: bytes) -> str {
    (url, req) = crossing_request(space, path, endpoint, body);
    try {
        return transport().send(url, req, CALL_SECONDS).body.decode("utf-8");
    } except TimeoutError as e {
        raise RemoteTimeout(space=space, endpoint=endpoint, detail=str(e));
    } except OSError as e {
        raise RemoteUnavailable(space=space, endpoint=endpoint, detail=str(e));
    }
}

impl carried_stream(space: str, path: str, endpoint: str, body: bytes) -> Iterator[any] {
    (url, req) = crossing_request(space, path, endpoint, body);
    reply = Response();
    try {
        reply = transport().send(url, req, STREAM_SECONDS);
    } except TimeoutError as e {
        raise RemoteTimeout(space=space, endpoint=endpoint, detail=str(e));
    } except OSError as e {
        raise RemoteUnavailable(space=space, endpoint=endpoint, detail=str(e));
    }
    events = reply.events;
    if events is None {
        reply_data(space, endpoint, reply.body.decode("utf-8"));
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail="the reply is no stream");
    }
    try {
        forever {
            frame = b"";
            got = False;
            try {
                for one in events {
                    frame = one;
                    got = True;
                    break;
                }
            } except TimeoutError as e {
                raise RemoteTimeout(space=space, endpoint=endpoint, detail=str(e));
            } except OSError as e {
                raise RemoteUnavailable(space=space, endpoint=endpoint, detail=str(e));
            }
            if not got {
                raise RemoteUnavailable(
                    space=space, endpoint=endpoint, detail="the stream ended before its end"
                );
            }
            event = "";
            said: str | None = None;
            for line in frame.decode("utf-8").split("\n") {
                text = line.rstrip("\r");
                if text.startswith("event: ") {
                    event = text[7:len(text)];
                } elif text.startswith("data: ") {
                    said = text[6:len(text)];
                }
            }
            if said is None {
                continue;
            }
            data: any = None;
            try {
                data = json.loads(said);
            } except ValueError as e {
                raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
            }
            if event == "end" {
                return;
            }
            if event == "error" {
                failed: dict[str, any] = data if isinstance(data, dict) else {};
                raise reply_error(space, endpoint, failed);
            }
            yield data;
        }
    } finally {
        events.close();
    }
}

impl forward_remote(
    url: str, path: str, body: bytes, authorization: str, method: str
) -> tuple[int, bytes, Iterator[bytes] | None] {
    headers = {"content-type": "application/json"};
    if authorization != "" {
        headers["authorization"] = authorization;
    }
    try {
        reply = transport().send(
            url,
            Request(
                method=method, path=path, headers=headers, body=(body if method == "POST" else b"")
            ),
            STREAM_SECONDS,
        );
        return (reply.status, reply.body, reply.events);
    } except OSError as e {
        failed = {"ok": False, "kind": "unavailable", "detail": str(e)};
        return (503, json.dumps(failed).encode("utf-8"), None);
    }
}

impl forward_file(url: str, r: Request) -> Response {
    headers = {"content-type": r.headers.get("content-type", "application/octet-stream")};
    if r.headers.get("authorization", "") != "" {
        headers["authorization"] = r.headers["authorization"];
    }
    try {
        return transport().send(
            url,
            Request(method=r.method, path=r.path, query=r.query, headers=headers, body=r.body),
            STREAM_SECONDS,
        );
    } except OSError as e {
        failed = {"ok": False, "kind": "unavailable", "detail": str(e)};
        return Response(status=503, body=json.dumps(failed).encode("utf-8"));
    }
}

impl sent[T](v: T) -> any {
    return encode[T](v);
}

impl refused(module: str, name: str, caller: str, trusted: bool) -> tuple[int, bytes] | None {
    for e in _endpoints.values() {
        if e.module == module and e.name == name {
            if e.access == Access.INTERNAL and not trusted {
                return reply_fail(403, "rejected", "an internal endpoint");
            }
            if e.access == Access.PROT and caller == "" {
                return reply_fail(401, "rejected", "This needs a signed-in caller.");
            }
            return None;
        }
    }
    return reply_fail(404, "failed", "no such endpoint");
}

impl refuse_unknown[T](given: dict[str, any]) {
    known: list[str] = [];
    comptime for f in fields(T) {
        known.append(f.name);
    }
    for k in given.keys() {
        if k not in known {
            raise CodecError(detail=f"no parameter '{k}'");
        }
    }
}

impl serve_def(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    comptime if holds(args_type(f), File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                arrive[args_type(f)](a, module, name);
                return encode(apply(f, a));
            },
        ),
    );
    return True;
}

impl serve_proc(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    comptime if holds(args_type(f), File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                arrive[args_type(f)](a, module, name);
                apply(f, a);
                return None;
            },
        ),
    );
    return True;
}

impl serve_async_def(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    comptime if holds(args_type(f), File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                arrive[args_type(f)](a, module, name);
                return encode(drive(apply(f, a)));
            },
        ),
    );
    return True;
}

impl serve_async_proc(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    comptime if holds(args_type(f), File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                arrive[args_type(f)](a, module, name);
                drive(apply(f, a));
                return None;
            },
        ),
    );
    return True;
}

impl serve_stream(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    comptime if holds(args_type(f), File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any { return not_one_reply(name); },
            items=lambda (given: dict[str, any]) -> Iterator[any] {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                arrive[args_type(f)](a, module, name);
                return sent_items(apply(f, a));
            },
        ),
    );
    return True;
}

impl serve_async_stream(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool {
    comptime if holds(args_type(f), File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any { return not_one_reply(name); },
            items=lambda (given: dict[str, any]) -> Iterator[any] {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                arrive[args_type(f)](a, module, name);
                return sent_async_items(apply(f, a));
            },
        ),
    );
    return True;
}

impl not_one_reply(name: str) -> any {
    raise CodecError(detail=f"{name} is a stream: its items are read as they come");
}

impl sent_items[T](items: Iterator[T]) -> Iterator[any] {
    for v in items {
        yield encode(v);
    }
}

impl sent_async_items[T](items: AsyncIterator[T]) -> Iterator[any] {
    forever {
        try {
            v = drive(items.__anext__());
        } except StopAsyncIteration {
            return;
        }
        yield encode(v);
    }
}

impl serve_walker[W](space: str, module: str, name: str, access: Access) -> bool {
    comptime if holds(W, File) {
        takes_files(module, name);
    }
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=True,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[W](given);
                w = decode[W](given);
                arrive[W](w, module, name);
                done = root spawn w;
                if declares_reports[W]() {
                    return {"fields": encode[W](done)};
                }
                return {"fields": encode[W](done), "reports": json_values(done.reports)};
            },
        ),
    );
    return True;
}

impl drive[R](c: Coroutine[any, any, R]) -> R {
    try {
        c.send(None);
    } except StopIteration as e {
        return e.value;
    }
    raise RuntimeError("an endpoint suspended, which this server can't resume");
}

impl settle(v: any) {
    if v is None {
        return;
    }
    c: Coroutine[any, any, any] = v;
    drive(c);
}

impl json_values(v: any) -> any {
    if v is None
        or isinstance(v, bool)
        or isinstance(v, int)
        or isinstance(v, float)
        or isinstance(v, str)
    {
        return v;
    }
    if isinstance(v, list) {
        items: list[any] = v;
        return [json_values(x) for x in items];
    }
    if isinstance(v, dict) {
        d: dict[any, any] = v;
        out: dict[str, any] = {};
        for (k, x) in d.items() {
            if not isinstance(k, str) {
                raise CodecError(detail=f"a report's dict key {k!r} isn't a str");
            }
            out[k] = json_values(x);
        }
        return out;
    }
    raise CodecError(
        detail=f"a report of a {type(v).__name__} has no JSON form: what a walker reports over a crossing is JSON's values",
    );
}

impl admit(path: str, body: bytes, caller: str, trusted: bool) -> tuple[Endpoint
    | None, dict[str, any], tuple[int, bytes]] {
    none: dict[str, any] = {};
    e = _endpoints.get(path, None);
    if e is None {
        return (None, none, reply_fail(404, "failed", "no such endpoint"));
    }
    if e.access == Access.INTERNAL and not trusted {
        return (None, none, reply_fail(403, "rejected", "an internal endpoint"));
    }
    if e.access == Access.PROT and caller == "" {
        return (None, none, reply_fail(401, "rejected", "This needs a signed-in caller."));
    }
    try {
        got: any = json.loads(body.decode("utf-8")) if len(body) > 0 else {};
        if not isinstance(got, dict) {
            return (None, none, reply_fail(400, "rejected", "the request is not a JSON object"));
        }
        held: dict[str, any] = got;
        args: any = held.get("fields" if e.is_walker else "args", {});
        if not isinstance(args, dict) {
            return (
                None,
                none,
                reply_fail(400, "rejected", "the arguments are not a JSON object of them by name"),
            );
        }
        given: dict[str, any] = args;
        return (e, given, (200, b""));
    } except ValueError {
        return (None, none, reply_fail(400, "rejected", "the request is not JSON"));
    }
}

impl answer(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
    (e, given, refusal) = admit(path, body, caller, trusted);
    if e is None {
        return refusal;
    }
    return run_endpoint(e, given, caller);
}

impl answer_stream(
    path: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, bytes, Iterator[bytes] | None] {
    (e, given, refusal) = admit(path, body, caller, trusted);
    if e is None {
        return (refusal[0], refusal[1], None);
    }
    make = e.items;
    if make is None {
        (status, reply) = run_endpoint(e, given, caller);
        return (status, reply, None);
    }
    f = Flight();
    try {
        f = stream_begun(caller);
    } except StoreConflict as lost {
        print(f"endpoint {e.path()} gave way to other calls: {lost}");
        (status, reply) = reply_fail(
            409, "conflict", f"{e.name}: what it changed, others changed first"
        );
        return (status, reply, None);
    }
    try {
        return (200, b"", events_of(e, make(given), f));
    } except CodecError as c {
        (status, reply) = reply_fail(400, "rejected", f"{e.name}: {c}");
        return (status, reply, None);
    } finally {
        stream_paused(f);
    }
}

impl events_of(e: Endpoint, items: Iterator[any], f: Flight) -> Iterator[bytes] {
    ended = False;
    try {
        forever {
            got: list[any] = [];
            undone = stream_resumed(f);
            try {
                if undone is not None {
                    items.close();
                } else {
                    for v in items {
                        got.append(v);
                        break;
                    }
                    if len(got) == 0 {
                        stream_kept(f);
                    }
                }
            } finally {
                stream_paused(f);
            }
            if undone is not None {
                raise undone;
            }
            if len(got) == 0 {
                break;
            }
            yield b"data: " + json.dumps(got[0]).encode("utf-8") + b"\n\n";
        }
        ended = True;
        yield b"event: end\ndata: {}\n\n";
    } except GeneratorExit {
        if not ended {
            left = stream_resumed(f);
            try {
                items.close();
                if left is None {
                    stream_kept(f);
                }
            } except StoreConflict as refused {
                left = refused;
            } finally {
                stream_paused(f);
            }
            if left is not None {
                print(f"endpoint {e.path()} kept nothing of what it made: {left}");
            }
        }
        raise;
    } except StoreConflict as lost {
        print(f"endpoint {e.path()} kept nothing of what it made: {lost}");
        yield error_event("conflict", f"{e.name}: what it changed, others changed first");
    } except CodecError as c {
        yield error_event("rejected", f"{e.name}: {c}");
    } except RemoteRejected as r {
        yield error_event("rejected", r.detail);
    } except Exception as x {
        print(f"endpoint {e.path()} failed: {type(x).__name__}: {x}{raised_at(x)}");
        yield error_event("failed", f"{e.name} failed");
    }
}

impl raised_at(x: BaseException) -> str {
    out = "";
    at = x.__traceback__;
    while at is not None {
        code = at.tb_frame.f_code;
        out += f"\n  {code.co_filename}:{at.tb_lineno}, in {code.co_name}";
        at = at.tb_next;
    }
    return out;
}

impl error_event(kind: str, detail: str) -> bytes {
    said = json.dumps({"ok": False, "kind": kind, "detail": detail});
    return b"event: error\ndata: " + said.encode("utf-8") + b"\n\n";
}

impl run_endpoint(e: Endpoint, given: dict[str, any], caller: str) -> tuple[int, bytes] {
    try {
        out = kept_call(caller, lambda -> any { return e.run(given); });
        return (200, json.dumps({"ok": True, "data": out}).encode("utf-8"));
    } except StoreConflict as lost {
        print(f"endpoint {e.path()} gave way to other calls each time it ran: {lost}");
        return reply_fail(409, "conflict", f"{e.name}: what it changed, others changed first");
    } except CodecError as c {
        return reply_fail(400, "rejected", f"{e.name}: {c}");
    } except RemoteRejected as r {
        return reply_fail(401, "rejected", r.detail);
    } except Exception as x {
        print(f"endpoint {e.path()} failed: {type(x).__name__}: {x}{raised_at(x)}");
        return reply_fail(500, "failed", f"{e.name} failed");
    }
}

impl endpoint_named(module: str, name: str) -> Endpoint | None {
    for e in _endpoints.values() {
        if e.module == module and e.name == name and not e.is_walker {
            return e;
        }
    }
    return None;
}

impl reply_fail(status: int, kind: str, detail: str) -> tuple[int, bytes] {
    return (status, json.dumps({"ok": False, "kind": kind, "detail": detail}).encode("utf-8"));
}

impl take[R](space: str, endpoint: str, data: any) -> R {
    try {
        return decode[R](data);
    } except CodecError as e {
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
    }
}

impl call_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R {
    return take[R](space, module + "." + name, call_endpoint(space, module, name, False, args));
}

impl call_proc(space: str, module: str, name: str, args: dict[str, any]) {
    call_endpoint(space, module, name, False, args);
}

impl call_async_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R {
    return take[R](space, module + "." + name, call_endpoint(space, module, name, False, args));
}

impl call_async_proc(space: str, module: str, name: str, args: dict[str, any]) {
    call_endpoint(space, module, name, False, args);
}

impl call_stream[T](space: str, module: str, name: str, args: dict[str, any]) -> Iterator[T] {
    for v in stream_endpoint(space, module, name, args) {
        yield take[T](space, module + "." + name, v);
    }
}

impl call_async_stream[T](
    space: str, module: str, name: str, args: dict[str, any]
) -> AsyncIterator[T] {
    for v in stream_endpoint(space, module, name, args) {
        yield take[T](space, module + "." + name, v);
    }
}

impl spawn_walker[W](space: str, module: str, name: str, args: dict[str, any]) -> W {
    endpoint = module + "." + name;
    data: any = call_endpoint(space, module, name, True, args);
    if not isinstance(data, dict) {
        raise RemoteDecodeError(
            space=space, endpoint=endpoint, detail="a spawn's reply is no walker"
        );
    }
    got: dict[str, any] = data;
    w = take[W](space, endpoint, got.get("fields", None));
    if declares_reports[W]() {
        return w;
    }
    reports: any = got.get("reports", []);
    if not isinstance(reports, list) {
        raise RemoteDecodeError(
            space=space, endpoint=endpoint, detail="a spawn's reports are no list"
        );
    }
    items: list[any] = reports;
    for r in items {
        w.reports.append(r);
    }
    return w;
}
