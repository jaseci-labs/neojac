impl restspec(
    f: Callable,
    method: HTTPMethod,
    path: str,
    produces: str | None = None,
    envelope: bool | None = None,
    headers: dict[str, str] | None = None,
) {
    comptime assert len(params(f))
        == 0, "a function served at a path of its own takes no parameters";
    comptime assert len(path) > 0 and path[0] == "/", "@restspec's path starts with '/'";
    markup = returns(f) == Markup;
    note(
        f,
        "restspec",
        (
            method,
            path,
            produces
                if produces is not None
                else ("text/html; charset=utf-8" if markup else "text/plain"),
            envelope if envelope is not None else not markup,
            headers,
            markup,
        ),
    );
}

impl routes -> list[RestRoute] {
    if len(_routes_read) == 0 {
        _routes_read.append(True);
        comptime for n in noted("restspec") {
            sent_with: dict[str, str] | None = n.value[4];
            _routes.append(
                RestRoute(
                    method=n.value[0],
                    path=n.value[1],
                    produces=n.value[2],
                    envelope=n.value[3],
                    headers=sent_with,
                    markup=n.value[5],
                    module=n.module,
                    name=n.name,
                    run=lambda -> any {
                        a = restore(args_type(n.decl));
                        return apply(n.decl, a);
                    },
                ),
            );
        }
    }
    return _routes;
}

impl route_of(method: str, path: str) -> RestRoute | None {
    for r in routes() {
        if r.path == path and r.method.value == method {
            return r;
        }
    }
    return None;
}

impl route_answer(
    r: RestRoute, caller: str, trusted: bool
) -> tuple[int, str, bytes, dict[str, str]] {
    e = endpoint_named(r.module, r.name);
    status = 200;
    reply = b"";
    if e is not None {
        (status, reply) = answer(e.path(), b"", caller, trusted);
    } elif not trusted {
        (status, reply) = reply_fail(403, "rejected", "an internal endpoint");
    } else {
        try {
            out: any = kept_call(caller, lambda -> any { return r.run(); });
            if r.markup {
                made: Markup = out;
                out = encode(made);
            }
            reply = json.dumps({"ok": True, "data": json_values(out)}).encode("utf-8");
        } except Exception as x {
            print(f"route {r.path} failed: {type(x).__name__}: {x}{raised_at(x)}");
            (status, reply) = reply_fail(500, "failed", r.path + " failed");
        }
    }
    if r.envelope or status != 200 {
        return (status, "application/json", reply, {});
    }
    data: any = json.loads(reply.decode("utf-8"))["data"];
    if r.markup {
        data = decode[Markup](data).text;
    }
    if not isinstance(data, str) {
        print(
            f"route {r.path} failed: its function gives a {type(data).__name__}, not the str its "
                f"body is",
        );
        (status, reply) = reply_fail(500, "failed", r.path + " failed");
        return (status, "application/json", reply, {});
    }
    text: str = data;
    return (200, r.produces, text.encode("utf-8"), r.headers or {});
}
