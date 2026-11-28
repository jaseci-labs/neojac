impl consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int {
    if len(_limits) == 0 {
        l: dyn Limits = bound("limits");
        l.open(host());
        _limits.append(l);
    }
    return _limits[0].consume(scope, actor, limit, seconds);
}

impl limit(f: Callable, uses: int, per: float) {
    comptime assert uses > 0, "@limit takes how many uses, at least one";
    comptime assert per > 0.0, "@limit takes the seconds they are counted in";
    note(f, "limit", (uses, per));
}

impl limited(module: str, name: str, caller: str, client: str) -> int {
    return counted("endpoint", module, name, caller, client);
}

impl counted(what: str, module: str, name: str, caller: str, client: str) -> int {
    if len(_limits_read) == 0 {
        _limits_read.append(True);
        comptime for n in noted("limit") {
            _limited[n.module + "." + n.name] = (n.value[0], int(n.value[1]));
        }
    }
    key = module + "." + name;
    if key not in _limited {
        return 0;
    }
    (uses, seconds) = _limited[key];
    actor = "caller " + caller if caller != "" else "client " + client;
    return consume_limit(what + " " + key, actor, uses, seconds);
}

impl limited_files(module: str, name: str, caller: str, client: str) -> int {
    return counted("files", module, name, caller, client);
}
