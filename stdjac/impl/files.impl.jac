impl FileError.__str__ -> str {
    return self.detail;
}

impl kept -> dyn Files {
    if len(_files) == 0 {
        p = plan();
        if p.app == "" or p.has_entry {
            raise RuntimeError(
                "a File's bytes are kept by an app that serves: this program is none, so it makes and reads no File",
            );
        }
        f: dyn Files = bound("files");
        f.open(FilesHost());
        _files.append(f);
    }
    return _files[0];
}

impl FilesHost.data_dir -> str {
    return app_data(plan());
}

impl holds_files -> bool {
    if len(_wanted) == 0 {
        _wanted.append(True);
    }
    return True;
}

impl open_files -> str {
    if len(_wanted) == 0 {
        return "";
    }
    return kept().kept_as();
}

impl ctype_of(t: str) -> str {
    said = t.strip().lower();
    if said == "" {
        return OCTETS;
    }
    if re.fullmatch(CTYPE_FORM, said) is None {
        raise FileError(
            detail=f"'{t}' is no content type: one is two names with a '/' between, as image/png is"
        );
    }
    return said;
}

impl begins_as(ctype: str, head: bytes) {
    if ctype not in BEGINS {
        return;
    }
    fits = head.startswith(BEGINS[ctype]);
    if ctype == "image/webp" {
        fits = fits and head[8:12] == b"WEBP";
    }
    if not fits {
        raise FileError(detail=f"its bytes are not {ctype}'s");
    }
}

impl File.init(data: bytes | Iterator[bytes] = b"", ctype: str = OCTETS) {
    k = keep(data, ctype_of(ctype));
    self.id = k.id;
    self.size = k.size;
    self.ctype = k.ctype;
}

impl File.read -> bytes {
    return b"".join(list(self.chunks()));
}

impl File.chunks(most: int = READ) -> Iterator[bytes] {
    if most <= 0 {
        raise ValueError("a piece has at least one byte");
    }
    files = kept();
    k = files.stat(self.id) if re.fullmatch(ID_FORM, self.id) is not None else None;
    if k is None or not k.whole {
        raise LookupError(f"no file {self.id}");
    }
    start = 0;
    while start < k.size {
        piece = files.read(self.id, start, most);
        if len(piece) == 0 {
            break;
        }
        start += len(piece);
        yield piece;
    }
}

impl File.url -> str {
    return "/__jac/files/" + self.id;
}

impl keep(data: bytes | Iterator[bytes], ctype: str) -> Kept {
    files = kept();
    step = files.piece();
    id = secrets.token_hex(32);
    files.begin(id, ctype);
    try {
        size = 0;
        head = b"";
        if isinstance(data, bytes) {
            whole: bytes = data;
            head = whole[0:16];
            begins_as(ctype, head);
            while size < len(whole) {
                size = files.append(id, size, whole[size:size + step]);
            }
        } else {
            pieces: Iterator[bytes] = data;
            checked = False;
            waiting = bytearray();
            for piece in pieces {
                if len(head) < 16 {
                    head = (head + piece)[0:16];
                }
                if not checked and len(head) == 16 {
                    begins_as(ctype, head);
                    checked = True;
                }
                waiting.extend(piece);
                at = 0;
                while len(waiting) - at >= step {
                    size = files.append(id, size, bytes(waiting[at:at + step]));
                    at += step;
                }
                if at > 0 {
                    waiting = waiting[at:];
                }
            }
            if not checked {
                begins_as(ctype, head);
            }
            if len(waiting) > 0 {
                size = files.append(id, size, bytes(waiting));
            }
        }
        return files.finish(id);
    } except Exception as e {
        files.drop([id]);
        raise e;
    }
}

impl accepts(f: Callable, most: int, kinds: list[str] = []) {
    comptime assert most > 0, "@accepts takes the most bytes a File may have, at least one";
    note(f, "accepts", (most, kinds));
}

impl takes_files(module: str, name: str) -> bool {
    _takes[module + "." + name] = True;
    return holds_files();
}

impl accepted(module: str, name: str) -> Accepted | None {
    if len(_accepted_read) == 0 {
        _accepted_read.append(True);
        comptime for n in noted("accepts") {
            _accepted[n.module + "." + n.name] = Accepted(most=n.value[0], kinds=n.value[1]);
        }
    }
    key = module + "." + name;
    if key not in _takes {
        return None;
    }
    return _accepted.get(key, Accepted());
}

impl fits(a: Accepted, size: int, ctype: str) {
    if size > a.most {
        raise FileError(detail=f"a file of {size} bytes is more than the {a.most} it takes");
    }
    if len(a.kinds) > 0 and ctype not in a.kinds {
        raise FileError(
            detail=f"a file of the type {ctype} is none it takes: {', '.join(a.kinds)}"
        );
    }
}

impl files_in[T](v: T) -> list[str] {
    out: list[str] = [];
    each_held[T, File](v, lambda (f: File) { out.append(f.id) });
    return out;
}

impl arrive[T](v: T, module: str, name: str) {
    comptime if holds(T, File) {
        a = accepted(module, name);
        took = a if a is not None else Accepted();
        each_held[T, File](
            v,
            lambda (f: File) {
                k = kept().stat(f.id) if re.fullmatch(ID_FORM, f.id) is not None else None;
                if k is None or not k.whole {
                    raise CodecError(detail="a File that names no kept file");
                }
                f.size = k.size;
                f.ctype = k.ctype;
                try {
                    fits(took, k.size, k.ctype);
                } except FileError as e {
                    raise CodecError(detail=e.detail);
                }
            },
        );
    }
}

impl also_held(whose: str, ask: Callable[[], list[str] | None]) {
    _others[whose] = ask;
}

impl sweep_files(held: dict[str, bool]) -> int {
    if len(_wanted) == 0 and len(_files) == 0 {
        return 0;
    }
    for ask in _others.values() {
        theirs = ask();
        if theirs is None {
            return 0;
        }
        for id in theirs {
            held[id] = True;
        }
    }
    files = kept();
    now = time.time();
    gone: list[str] = [];
    for k in files.every() {
        if k.id in held {
            continue;
        }
        if now - k.made >= (UNHELD_SECONDS if k.whole else UNFINISHED_SECONDS) {
            gone.append(k.id);
        }
    }
    if len(gone) > 0 {
        files.drop(gone);
    }
    return len(gone);
}

impl asked(query: str, name: str) -> str {
    for part in query.split("&") {
        (k, _eq, v) = part.partition("=");
        if k == name {
            return v;
        }
    }
    return "";
}

impl ranged(said: str, size: int) -> tuple[int, int] | None {
    m = re.fullmatch("bytes=([0-9]*)-([0-9]*)", said.strip());
    if m is None or (m.group(1) == "" and m.group(2) == "") {
        return None;
    }
    if m.group(1) == "" {
        n = min(int(m.group(2)), size);
        return (size - n, n) if n > 0 else None;
    }
    start = int(m.group(1));
    if start >= size {
        return None;
    }
    end = min(int(m.group(2)), size - 1) if m.group(2) != "" else size - 1;
    return (start, end - start + 1) if end >= start else None;
}

impl sent_headers(k: Kept) -> dict[str, str] {
    return {
        "Accept-Ranges": "bytes",
        "Cache-Control": "private, max-age=31536000, immutable",
        "Content-Disposition": "inline" if k.ctype in SHOWN else "attachment",
        "Content-Security-Policy": "default-src 'none'; sandbox",
        "ETag": '"' + k.id + '"',
        "X-Content-Type-Options": "nosniff",
    };
}

impl send_file(r: Request, k: Kept) -> Response {
    headers = sent_headers(k);
    if r.headers.get("if-none-match", "") == headers["ETag"] {
        return Response(status=304, ctype=k.ctype, headers=headers);
    }
    start = 0;
    count = k.size;
    status = 200;
    said = r.headers.get("range", "");
    if said != "" {
        part = ranged(said, k.size);
        if part is None {
            headers["Content-Range"] = f"bytes */{k.size}";
            return Response(status=416, ctype="text/plain", body=b"no such range", headers=headers);
        }
        (start, count) = part;
        headers["Content-Range"] = f"bytes {start}-{start + count - 1}/{k.size}";
        status = 206;
    }
    if r.method == "HEAD" {
        return Response(status=status, ctype=k.ctype, headers=headers, length=count);
    }
    return Response(
        status=status,
        ctype=k.ctype,
        headers=headers,
        length=count,
        pieces=pieces_of(k.id, start, count),
    );
}

impl pieces_of(id: str, start: int, count: int) -> Iterator[bytes] {
    files = kept();
    left = count;
    offset = start;
    while left > 0 {
        piece = files.read(id, offset, min(left, READ));
        if len(piece) == 0 {
            break;
        }
        offset += len(piece);
        left -= len(piece);
        yield piece;
    }
}

impl files_route(
    r: Request, admits: Callable[[str, str], Response | None], often: Callable[[str, str], int]
) -> Response {
    rest = r.path.removeprefix("/__jac/files").strip("/");
    parts = rest.split("/") if rest != "" else [];
    if len(parts) > 0 and re.fullmatch(ID_FORM, parts[0]) is None {
        return json_fail(404, "failed", "no such file");
    }
    try {
        if r.method in ["GET", "HEAD"] {
            k = kept().stat(parts[0]) if len(parts) == 1 else None;
            if k is None or not k.whole {
                return json_fail(404, "failed", "no such file");
            }
            return send_file(r, k);
        }
        if r.method != "POST" or len(parts) > 2 or (len(parts) == 2 and parts[1] != "done") {
            return json_fail(404, "failed", "no such endpoint");
        }
        target = urllib.parse.unquote(asked(r.query, "for")).split("/");
        module = target[1] if len(target) == 3 else "";
        name = target[2] if len(target) == 3 else "";
        a = accepted(module, name);
        if a is None {
            return json_fail(
                400,
                "rejected",
                "a file is sent for an endpoint that takes one: `for=<space>/<module>/<name>`",
            );
        }
        refused = admits(module, name);
        if refused is not None {
            return refused;
        }
        if len(parts) == 0 {
            return begin_file(r, a, often(module, name));
        }
        k = kept().stat(parts[0]);
        if k is None {
            return json_fail(404, "failed", "no such file");
        }
        if len(parts) == 2 {
            return finish_file(k, a);
        }
        return take_piece(r, k, a);
    } except FileError as e {
        return json_fail(400, "rejected", e.detail);
    }
}

impl begin_file(r: Request, a: Accepted, seconds: int) -> Response {
    if seconds > 0 {
        failed = json_fail(429, "rejected", f"sent too often: try again in {seconds} seconds");
        failed.headers = {"Retry-After": str(seconds)};
        return failed;
    }
    said: any = None;
    try {
        said = json.loads(r.body.decode("utf-8"));
    } except ValueError {
        said = None;
    }
    if not isinstance(said, dict) {
        return json_fail(400, "rejected", "the request is not a JSON object");
    }
    given: dict[str, any] = said;
    size: any = given.get("size", None);
    if not isinstance(size, int) or isinstance(size, bool) or size < 0 {
        return json_fail(400, "rejected", "`size` is how many bytes the file has");
    }
    ctype = ctype_of(str(given.get("ctype", "")));
    fits(a, size, ctype);
    id = secrets.token_hex(32);
    kept().begin(id, ctype);
    return json_ok({"id": id, "piece": kept().piece()});
}

impl take_piece(r: Request, k: Kept, a: Accepted) -> Response {
    if k.whole {
        return json_fail(400, "rejected", "the file is whole, and is written no more");
    }
    at = asked(r.query, "at");
    if not at.isdigit() {
        return json_fail(400, "rejected", "`at` is where in the file the piece goes");
    }
    offset = int(at);
    step = kept().piece();
    if len(r.body) > step {
        return json_fail(413, "rejected", f"a piece has at most {step} bytes");
    }
    if offset % step != 0 {
        return json_fail(
            400,
            "rejected",
            f"a piece goes at a multiple of {step} bytes: one with fewer is the file's last",
        );
    }
    if len(r.body) == 0 {
        return json_ok({"size": k.size});
    }
    if offset == k.size {
        fits(a, k.size + len(r.body), k.ctype);
    }
    return json_ok({"size": kept().append(k.id, offset, r.body)});
}

impl finish_file(k: Kept, a: Accepted) -> Response {
    files = kept();
    if not k.whole {
        try {
            fits(a, k.size, k.ctype);
            done = files.finish(k.id);
            begins_as(done.ctype, files.read(done.id, 0, 16));
            k = done;
        } except FileError as e {
            files.drop([k.id]);
            raise e;
        }
    }
    return json_ok({"id": k.id, "size": k.size, "ctype": k.ctype});
}
