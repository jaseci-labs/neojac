impl sent[T](v: T) -> any {
    out = encode[T](v);
    comptime if holds(T, File) {
        each_sent[T, File](
            v, out, lambda (f: File, was: dict[str, any]) { _leaving.append((f, was)) }
        );
    }
    return out;
}

impl carries(v: any, was: dict[str, any]) -> bool {
    if v is was {
        return True;
    }
    if isinstance(v, dict) {
        held: dict[str, any] = v;
        for x in held.values() {
            if carries(x, was) {
                return True;
            }
        }
    } elif isinstance(v, list) {
        items: list[any] = v;
        for x in items {
            if carries(x, was) {
                return True;
            }
        }
    }
    return False;
}

impl leave(space: str, module: str, name: str, args: dict[str, any]) {
    if len(_leaving) == 0 {
        return;
    }
    going: list[tuple[File, dict[str, any]]] = [];
    rest: list[tuple[File, dict[str, any]]] = [];
    for pair in _leaving {
        if carries(args, pair[1]) {
            going.append(pair);
        } else {
            rest.append(pair);
        }
    }
    _leaving.clear();
    _leaving.extend(rest);
    for (f, was) in going {
        if f.id == "" {
            await file_send(f, space, name, f"{space}/{module}/{name}");
        }
        was["id"] = f.id;
        was["size"] = f.size;
        was["ctype"] = f.ctype;
    }
}

impl take[R](space: str, endpoint: str, data: any) -> R {
    try {
        out = decode[R](data);
        comptime if holds(R, File) {
            each_held[R, File](out, lambda (f: File) { file_from(f, space) });
        }
        return out;
    } except CodecError as e {
        decode_failed(space, endpoint, str(e));
        raise e;
    }
}

impl call_async_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R {
    await leave(space, module, name, args);
    data: any = await post(space, name, f"/__jac/call/{space}/{module}/{name}", {"args": args});
    return take[R](space, module + "." + name, data);
}

impl call_async_proc(space: str, module: str, name: str, args: dict[str, any]) {
    await leave(space, module, name, args);
    await post(space, name, f"/__jac/call/{space}/{module}/{name}", {"args": args});
}

impl call_async_stream[T](
    space: str, module: str, name: str, args: dict[str, any]
) -> AsyncIterator[T] {
    await leave(space, module, name, args);
    events: any = post_stream(space, name, f"/__jac/call/{space}/{module}/{name}", {"args": args});
    async for data in events {
        yield take[T](space, module + "." + name, data);
    }
}

impl spawn_walker[W](space: str, module: str, name: str, args: dict[str, any]) -> W {
    endpoint = module + "." + name;
    await leave(space, module, name, args);
    data: any = await post(space, name, f"/__jac/spawn/{space}/{module}/{name}", {"fields": args});
    if not isinstance(data, dict) {
        decode_failed(space, endpoint, "a spawn's reply is no walker");
    }
    got: dict[str, any] = data;
    w = take[W](space, endpoint, got.get("fields", None));
    if declares_reports[W]() {
        return w;
    }
    reports: any = got.get("reports", []);
    if not isinstance(reports, list) {
        decode_failed(space, endpoint, "a spawn's reports are no list");
    }
    items: list[any] = reports;
    for r in items {
        w.reports.append(r);
    }
    return w;
}
