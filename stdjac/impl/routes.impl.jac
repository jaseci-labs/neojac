impl restspec(
    f: Callable,
    method: HTTPMethod,
    path: str,
    produces: str | None = None,
    envelope: bool | None = None,
    headers: dict[str, str] | None = None,
) {
    comptime assert len(path) > 0 and path[0] == "/", "@restspec's path starts with '/'";
    comptime for hole in path_holes(path) {
        comptime assert hole
            != "", "a { or } in @restspec's path is a whole segment {name}: /orders/{id}";
        comptime assert takes_param(
            f, hole
        ), "each {name} in @restspec's path is a parameter of the function";
    }
    comptime assert holes_distinct(
        path_holes(path)
    ), "each {name} in @restspec's path is named once";
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
            takes: list[str] = [];
            texts: list[str] = [];
            comptime for p in params(n.decl) {
                takes.append(p.name);
                comptime if kind(p.type) == Kind.STR {
                    texts.append(p.name);
                }
            }
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
                    parts=n.value[1].split("/"),
                    takes=takes,
                    texts=texts,
                    run=lambda (given: dict[str, any]) -> any {
                        refuse_unknown[args_type(n.decl)](given);
                        a = decode[args_type(n.decl)](given);
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
    for r in routes() {
        if r.method.value == method and "{" in r.path and path_args(r, path) is not None {
            return r;
        }
    }
    return None;
}

impl route_answer(
    r: RestRoute, path: str, query: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, str, bytes, dict[str, str]] {
    e = endpoint_named(r.module, r.name);
    no = refused(r.module, r.name, caller, trusted) if e is not None else None;
    status = 200;
    reply = b"";
    if no is not None {
        (status, reply) = no;
    } elif e is None and not trusted {
        (status, reply) = reply_fail(403, "rejected", "an internal endpoint");
    } elif len(r.takes) == 0 {
        (status, reply) = route_run(r, e, {}, caller, trusted);
    } else {
        (given, problem) = route_args(r, query, body);
        for (name, text) in (path_args(r, path) or {}).items() {
            given[name] = given_value(r, name, text);
        }
        if problem != "" {
            (status, reply) = reply_fail(400, "rejected", problem);
        } else {
            (status, reply) = route_run(r, e, given, caller, trusted);
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
            f"route {r.path} failed: its function gives a {type(data).__name__}, not the str its body is",
        );
        (status, reply) = reply_fail(500, "failed", r.path + " failed");
        return (status, "application/json", reply, {});
    }
    text: str = data;
    return (200, r.produces, text.encode("utf-8"), r.headers or {});
}

impl route_args(r: RestRoute, query: str, body: bytes) -> tuple[dict[str, any], str] {
    given: dict[str, any] = {};
    for (name, text) in urllib.parse.parse_qsl(query, keep_blank_values=True) {
        if name not in r.takes {
            continue;
        }
        given[name] = given_value(r, name, text);
    }
    if len(body) == 0 {
        return (given, "");
    }
    got: any = None;
    try {
        got = json.loads(body.decode("utf-8"));
    } except (ValueError, RecursionError) {
        return (given, "the request is not JSON");
    }
    if not isinstance(got, dict) {
        return (given, "the request is not a JSON object");
    }
    held: dict[str, any] = got;
    for (name, value) in held.items() {
        given[name] = value;
    }
    return (given, "");
}

impl route_run(
    r: RestRoute, e: Endpoint | None, given: dict[str, any], caller: str, trusted: bool
) -> tuple[int, bytes] {
    if e is not None {
        return answer(e.path(), json.dumps({"args": given}).encode("utf-8"), caller, trusted);
    }
    try {
        out: any = kept_call(caller, lambda -> any { return r.run(given); });
        if r.markup {
            made: Markup = out;
            out = encode(made);
        }
        return (200, json.dumps({"ok": True, "data": json_values(out)}).encode("utf-8"));
    } except CodecError as c {
        return reply_fail(400, "rejected", f"{r.name}: {c}");
    } except Exception as x {
        print(f"route {r.path} failed: {type(x).__name__}: {x}{raised_at(x)}");
        return reply_fail(500, "failed", r.path + " failed");
    }
}

impl path_args(r: RestRoute, path: str) -> dict[str, str] | None {
    asked = path.split("/");
    if len(asked) != len(r.parts) {
        return None;
    }
    out: dict[str, str] = {};
    for (mine, theirs) in zip(r.parts, asked) {
        if len(mine) > 2 and mine[0] == "{" and mine[len(mine) - 1] == "}" {
            if theirs == "" {
                return None;
            }
            out[mine[1:len(mine) - 1]] = urllib.parse.unquote(theirs);
        } elif mine != theirs {
            return None;
        }
    }
    return out;
}

impl given_value(r: RestRoute, name: str, text: str) -> any {
    if name in r.texts {
        return text;
    }
    try {
        return json.loads(text);
    } except (ValueError, RecursionError) {
        return text;
    }
}

impl path_holes(path: str) -> list[str] {
    holes: list[str] = [];
    seg = "";
    braces = 0;
    i = 0;
    while i <= len(path) {
        if i == len(path) or path[i] == "/" {
            if braces == 2 and len(seg) > 2 and seg[0] == "{" and seg[len(seg) - 1] == "}" {
                name = "";
                k = 1;
                while k < len(seg) - 1 {
                    name = name + seg[k];
                    k += 1;
                }
                holes = holes + [name];
            } elif braces > 0 {
                holes = holes + [""];
            }
            seg = "";
            braces = 0;
        } else {
            seg = seg + path[i];
            if path[i] == "{" or path[i] == "}" {
                braces += 1;
            }
        }
        i += 1;
    }
    return holes;
}

impl holes_distinct(holes: list[str]) -> bool {
    a = 0;
    while a < len(holes) {
        b = a + 1;
        while b < len(holes) {
            if holes[a] == holes[b] {
                return False;
            }
            b += 1;
        }
        a += 1;
    }
    return True;
}

impl takes_param(f: Callable, name: str) -> bool {
    comptime for p in params(f) {
        if p.name == name {
            return True;
        }
    }
    return False;
}
