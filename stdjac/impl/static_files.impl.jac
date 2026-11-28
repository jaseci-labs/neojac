impl static_file(
    top: str, path: str, headers: dict[str, str] = {}, routes: list[str] = []
) -> Response {
    if top == "" {
        raise ValueError("static_file needs the directory it serves");
    }
    served = os.path.realpath(top);
    full = os.path.realpath(os.path.join(served, path.lstrip("/")));
    under = False;
    try {
        under = os.path.commonpath([served, full]) == served;
    } except ValueError {
        under = False;
    }
    if not under {
        return page_answer("", None, None, path, headers, []);
    }
    rel: str = os.path.relpath(full, served);
    found: bytes | None = None;
    document: bytes | None = None;
    if rel != "." and os.path.isfile(full) {
        with open(full, "rb") as f {
            found = f.read();
        }
    } elif os.path.isfile(os.path.join(served, "index.html")) {
        with open(os.path.join(served, "index.html"), "rb") as f {
            document = f.read();
        }
    }
    return page_answer(rel.replace(os.sep, "/"), found, document, path, headers, routes);
}

impl held_file(
    space: str, path: str, headers: dict[str, str] = {}, routes: list[str] = []
) -> Response {
    kept: list[str] = [];
    for part in path.split("/") {
        if part == ".." {
            if len(kept) == 0 {
                return page_answer("", None, None, path, headers, []);
            }
            kept.pop();
        } elif part != "" and part != "." {
            kept.append(part);
        }
    }
    rel = "/".join(kept) if len(kept) > 0 else ".";
    found = HELD_PAGES.get(space + "/" + rel, None) if rel != "." else None;
    document = HELD_PAGES.get(space + "/index.html", None) if found is None else None;
    return page_answer(rel, found, document, path, headers, routes);
}

impl page_answer(
    rel: str,
    found: bytes | None,
    document: bytes | None,
    path: str,
    headers: dict[str, str],
    routes: list[str],
) -> Response {
    sent: dict[str, str] = {"X-Content-Type-Options": "nosniff"};
    cached = "";
    for (name, value) in headers.items() {
        if name.lower() == "cache-control" {
            cached = value;
        } else {
            sent[name] = value;
        }
    }
    if rel == "" {
        return Response(status=403, ctype="text/plain", body=b"forbidden", headers=sent);
    }
    status = 200;
    data = found;
    if data is None {
        ext = os.path.splitext(rel)[1].lower();
        if ext in CONTENT_TYPES and ext != ".html" or document is None {
            return Response(status=404, ctype="text/plain", body=b"not found", headers=sent);
        }
        if len(routes) > 0 and not routed(path, routes) {
            status = 404;
        }
        data = document;
        rel = "index.html";
    }
    ext = os.path.splitext(rel)[1].lower();
    if rel.split("/")[0] == "assets" {
        sent["Cache-Control"] = "public, max-age=31536000, immutable";
    } elif cached != "" {
        sent["Cache-Control"] = cached;
    } elif ext == ".html" {
        sent["Cache-Control"] = "no-cache";
    }
    return Response(
        status=status,
        ctype=CONTENT_TYPES.get(ext, "application/octet-stream"),
        body=data,
        headers=sent,
    );
}

impl routed(path: str, routes: list[str]) -> bool {
    got = [urllib.parse.unquote(x) for x in path.split("/") if x != ""];
    for r in routes {
        segs = [x for x in r.split("/") if x != ""];
        ok = True;
        rest = False;
        i = 0;
        while i < len(segs) and ok {
            if segs[i] == "*" {
                rest = True;
                break;
            }
            if i >= len(got) {
                ok = False;
            } elif not segs[i].startswith(":") and segs[i].lower() != got[i].lower() {
                ok = False;
            }
            i += 1;
        }
        if ok and (rest or i == len(got)) {
            return True;
        }
    }
    return False;
}
