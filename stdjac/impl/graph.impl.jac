impl UnknownType.__str__ -> str {
    return f"an unknown type: {self.name}";
}

impl keep_node[N](name: str) -> bool {
    kept = NodeType(
        name=name,
        shape=shape_of[N](),
        holds=lambda (n: Node) -> bool { return type(n) is N; },
        data=lambda (n: Node) -> dict[str, any] {
            d: dict[str, any] = encode_object[N](n as N);
            return d;
        },
        make=lambda (d: dict[str, any]) -> Node { return decode_object[N](d); },
        fill=lambda (n: Node, d: dict[str, any]) { fill_object[N](n as N, d) },
    );
    comptime if holds(N, File) {
        holds_files();
        kept.files = lambda (d: dict[str, any]) -> list[str] {
            return files_in[N](decode_object[N](d));
        };
    }
    _node_types.append(kept);
    return True;
}

impl keep_edge[E](name: str) -> bool {
    kept = EdgeType(
        name=name,
        shape=shape_of[E](),
        holds=lambda (e: any) -> bool { return type(e) is E; },
        data=lambda (e: any) -> dict[str, any] {
            d: dict[str, any] = encode_object[E](e as E);
            return d;
        },
        connect=lambda (a: Node, b: Node, d: dict[str, any]) -> any {
            made = decode_object[E](d);
            a +>:made:+> b;
            return made;
        },
        fill=lambda (e: any, d: dict[str, any]) { fill_object[E](e as E, d) },
        fits=lambda (d: dict[str, any]) { checked = decode_object[E](d); },
    );
    comptime if holds(E, File) {
        holds_files();
        kept.files = lambda (d: dict[str, any]) -> list[str] {
            return files_in[E](decode_object[E](d));
        };
    }
    _edge_types.append(kept);
    return True;
}

impl StoreCodec.node_type(n: Node) -> str {
    if isinstance(n, Root) {
        return "Root";
    }
    for t in _node_types {
        if t.holds(n) {
            return t.name;
        }
    }
    return "Node";
}

impl StoreCodec.node_data(n: Node) -> dict[str, any] {
    for t in _node_types {
        if t.holds(n) {
            return t.data(n);
        }
    }
    return {};
}

impl StoreCodec.make_node(type_name: str, data: dict[str, any]) -> Node {
    if type_name == "Root" {
        return Root();
    }
    for t in _node_types {
        if t.name == type_name {
            return t.make(data);
        }
    }
    raise UnknownType(name=type_name);
}

impl StoreCodec.fill_node(n: Node, data: dict[str, any]) {
    for t in _node_types {
        if t.holds(n) {
            t.fill(n, data);
            return;
        }
    }
}

impl StoreCodec.fill_edge(e: any, data: dict[str, any]) {
    for u in _edge_types {
        if u.holds(e) {
            u.fill(e, data);
            return;
        }
    }
}

impl StoreCodec.fits(type_name: str, data: dict[str, any]) {
    for t in _node_types {
        if t.name == type_name {
            t.make(data);
            return;
        }
    }
    for u in _edge_types {
        if u.name == type_name {
            u.fits(data);
            return;
        }
    }
}

impl StoreCodec.shape(type_name: str) -> str {
    for t in _node_types {
        if t.name == type_name {
            return t.shape;
        }
    }
    for u in _edge_types {
        if u.name == type_name {
            return u.shape;
        }
    }
    return "";
}

impl StoreCodec.keeps(type_name: str) -> bool {
    if type_name in ["Root", "Node", ""] {
        return True;
    }
    for t in _node_types {
        if t.name == type_name {
            return True;
        }
    }
    for u in _edge_types {
        if u.name == type_name {
            return True;
        }
    }
    return False;
}

impl StoreCodec.edge_type(e: any) -> str {
    for t in _edge_types {
        if t.holds(e) {
            return t.name;
        }
    }
    return "";
}

impl StoreCodec.edge_data(e: any) -> dict[str, any] {
    for t in _edge_types {
        if t.holds(e) {
            return t.data(e);
        }
    }
    return {};
}

impl StoreCodec.connect(type_name: str, a: Node, b: Node, data: dict[str, any]) -> any {
    if type_name == "" {
        made = GenericEdge();
        a +>:made:+> b;
        return made;
    }
    for t in _edge_types {
        if t.name == type_name {
            return t.connect(a, b, data);
        }
    }
    raise UnknownType(name=type_name);
}

impl grant(n: Node, level: AccessLevel = AccessLevel.READ) {
    _grants[jid(n)] = level.value;
}

impl keeper -> tuple[dyn Store, dyn Codec] {
    s = _store;
    c = _codec;
    if s is None or c is None {
        raise RuntimeError("this program keeps no graph");
    }
    return (s, c);
}

impl unmade(r: Row, why: str) -> DataError {
    (s, _c) = keeper();
    what = "node" if r.kind == "n" else "edge";
    return DataError(path=s.kept_as(), problem=f"holds a {r.type_name} {what}, {r.id}, {why}");
}

impl take_node(r: Row) -> Node {
    (_s, c) = keeper();
    data: dict[str, any] = json.loads(r.data);
    n: Node | None = None;
    try {
        n = c.make_node(r.type_name, data);
    } except UnknownType {
        raise unmade(r, "whose type this program no longer has");
    } except CodecError as e {
        raise unmade(r, f"which no longer fits its type ({e})");
    }
    if not rt_jid_restore(n, r.id) {
        raise unmade(r, "which no jid names");
    }
    _nodes[r.id] = n;
    _kept[r.id] = r.data;
    _versions[r.id] = r.version;
    if "__grant" in data {
        _grants[r.id] = int(data["__grant"]);
    }
    rt_await_edges(n);
    return n;
}

impl bring_nodes(ids: list[str]) {
    (s, _c) = keeper();
    need: dict[str, bool] = {};
    for i in ids {
        if i not in _nodes {
            need[i] = True;
        }
    }
    if len(need) == 0 {
        return;
    }
    for r in s.rows(list(need.keys())) {
        if r.kind == "n" and r.id not in _nodes {
            take_node(r);
        }
    }
}

impl take_edge(r: Row) -> any {
    (_s, c) = keeper();
    a = _nodes[r.src];
    b = _nodes[r.dst];
    made: any = None;
    try {
        made = c.connect(r.type_name, a, b, json.loads(r.data));
    } except UnknownType {
        raise unmade(r, "whose type this program no longer has");
    } except CodecError as e {
        raise unmade(r, f"which no longer fits its type ({e})");
    }
    rt_jid_restore(made, r.id);
    _edges[r.id] = made;
    _kept[r.id] = r.data;
    _versions[r.id] = r.version;
    _ends[r.id] = (r.src, r.dst);
    return made;
}

impl forget(id: str) {
    if id in _kept {
        del _kept[id];
    }
    if id in _versions {
        del _versions[id];
    }
    if id in _grants {
        del _grants[id];
    }
    if id in _ends {
        for end in _ends[id] {
            if end in _edges_at and id in _edges_at[end] {
                del _edges_at[end][id];
            }
        }
        del _ends[id];
    }
    if id in _edges {
        del _edges[id];
    }
    if id in _edges_at {
        del _edges_at[id];
    }
    if id in _nodes {
        rt_edges_here(_nodes[id]);
        del _nodes[id];
    }
    if id in _roots {
        del _roots[id];
    }
}

impl edges_here(n: Node) -> dict[str, bool] {
    out: dict[str, bool] = {};
    for into in [False, True] {
        for e in rt_edges_held(n, into) {
            out[jid(e)] = True;
        }
    }
    return out;
}

impl bring_edges(n: Node) {
    nid = jid(n);
    if not rt_awaits_edges(n) or nid in _bringing {
        return;
    }
    (s, _c) = keeper();
    _bringing[nid] = True;
    try {
        rows = s.edges(nid);
        ends: list[str] = [];
        for r in rows {
            ends.append(r.src);
            ends.append(r.dst);
        }
        bring_nodes(ends);
        listed: dict[str, bool] = {};
        for r in rows {
            if r.src not in _nodes or r.dst not in _nodes {
                continue;
            }
            listed[r.id] = True;
            if r.id not in _edges {
                take_edge(r);
            }
        }
        for eid in edges_here(n) {
            if eid in _edges and eid not in listed {
                rt_drop_held_edge(_edges[eid]);
                forget(eid);
            }
        }
        for into in [False, True] {
            held = rt_edges_held(n, into);
            by_id: dict[str, any] = {};
            for e in held {
                by_id[jid(e)] = e;
            }
            ordered: list[any] = [];
            for r in rows {
                if r.id in by_id and (r.dst if into else r.src) == nid {
                    ordered.append(by_id[r.id]);
                }
            }
            for e in held {
                if jid(e) not in listed {
                    ordered.append(e);
                }
            }
            rt_edges_order(n, into, ordered);
        }
        _edges_at[nid] = listed;
        rt_edges_here(n);
    } finally {
        del _bringing[nid];
    }
}

impl reach(n: Node) {
    in_turn(lambda { bring_edges(n) });
}

impl node_kept(id: str) -> Node | None {
    if id == "" {
        return None;
    }
    if id not in _nodes {
        bring_nodes([id]);
    }
    return _nodes.get(id, None);
}

impl jobj(name: str) -> any {
    if name in _removed {
        return None;
    }
    if name in _nodes {
        return _nodes[name];
    }
    if name in _edges {
        return _edges[name];
    }
    found: list[any] = [];
    in_turn(lambda { found.append(find_kept(name)) });
    if found[0] is not None {
        return found[0];
    }
    seen: dict[str, bool] = {};
    todo: list[Node] = [root.shared, _home];
    for held in _nodes.values() {
        todo.append(held);
    }
    for r in _roots.values() {
        todo.append(r);
    }
    i = 0;
    while i < len(todo) {
        n = todo[i];
        i += 1;
        nid = jid(n);
        if nid in seen {
            continue;
        }
        seen[nid] = True;
        if nid == name {
            return n;
        }
        for e in rt_edges_held(n, False) {
            if jid(e) == name {
                return e;
            }
            todo.append(rt_edge_dst(e));
        }
    }
    return None;
}

impl find_kept(name: str) -> any {
    s = _store;
    if s is None {
        return None;
    }
    for r in s.rows([name]) {
        if r.kind == "n" {
            return _nodes[r.id] if r.id in _nodes else take_node(r);
        }
        bring_nodes([r.src, r.dst]);
        if r.src in _nodes and r.dst in _nodes {
            return _edges[r.id] if r.id in _edges else take_edge(r);
        }
    }
    return None;
}

impl remove(n: Node) {
    for e in [edge n -->] + [edge n <--] {
        _removed[jid(e)] = True;
    }
    _removed[jid(n)] = True;
    rt_detach_node(id(n));
}

impl allroots -> list[Root] {
    in_turn(bring_roots);
    return list(_roots.values());
}

impl bring_roots {
    s = _store;
    if s is None {
        return;
    }
    ids = s.roots();
    bring_nodes(ids);
    for i in ids {
        if i in _nodes and i not in _roots {
            _roots[i] = _nodes[i] as Root;
        }
    }
}

impl counted(counts: dict[str, int]) -> str {
    parts = [f"{n} {name}" for (name, n) in counts.items()];
    return parts[0] if len(parts) == 1 else ", ".join(parts[:-1]) + " and " + parts[-1];
}

impl graph_open(store: dyn Store, codec: dyn Codec, host: dyn Host) {
    store.open(host);
    _store = store;
    _codec = codec;
    gone: dict[str, int] = {};
    unfit: dict[str, int] = {};
    why: dict[str, str] = {};
    was = store.shapes();
    for (name, count) in store.types().items() {
        if not codec.keeps(name) {
            gone[name] = count;
            continue;
        }
        shape = codec.shape(name);
        if shape == "" {
            continue;
        }
        _shapes[name] = was.get(name, "");
        if _shapes[name] == shape {
            continue;
        }
        for r in store.of_type(name) {
            try {
                codec.fits(name, json.loads(r.data));
            } except CodecError as e {
                unfit[name] = unfit.get(name, 0) + 1;
                if name not in why {
                    why[name] = str(e);
                }
            }
        }
        if name not in unfit {
            _new_shapes[name] = shape;
        }
    }
    if len(gone) > 0 or len(unfit) > 0 {
        said: list[str] = [];
        if len(gone) > 0 {
            whose = "whose type" if len(gone) == 1 else "whose types";
            said.append(f"holds {counted(gone)} {whose} this program no longer has");
        }
        for (name, count) in unfit.items() {
            said.append(f"holds {count} {name} that no longer fit the type ({why[name]})");
        }
        raise DataError(path="", problem="; and ".join(said));
    }
    _mark[0] = store.mark();
    shared = node_kept(store.shared_root());
    if shared is not None {
        rt_set_shared_root(shared as Root);
    } else {
        _new_shared.append(jid(root.shared));
    }
    rt_reach_with(reach);
}

impl root_for(user: str) -> Root {
    if _store is None {
        return _home;
    }
    if user not in _user_roots {
        in_turn(lambda { find_root(user) });
    }
    return _user_roots[user];
}

impl find_root(user: str) {
    s = _store;
    if s is None or user in _user_roots {
        return;
    }
    kept = node_kept(s.root_of(user));
    if kept is not None {
        _roots[jid(kept)] = kept as Root;
        _user_roots[user] = kept as Root;
        return;
    }
    r = Root();
    _new_roots[user] = jid(r);
    _roots[jid(r)] = r;
    _user_roots[user] = r;
}

impl enter_caller(user: str, call: int) {
    if _store is not None {
        in_turn(take_in);
    }
    if user == "" {
        rt_caller_enter(root.shared, True, "", call);
    } else {
        rt_caller_enter(root_for(user), False, user, call);
    }
}

impl current_caller -> str {
    return rt_caller_name();
}

impl Alone.take(work: Callable[[], None]) {
    work();
}

impl Alone.rest {
    raise RuntimeError("a call waits for others where no other runs");
}

impl Alone.wake {}

impl Alone.waits -> bool {
    return True;
}

impl store_in_turn(turns: dyn Turns) {
    _turns = turns;
}

impl in_turn(work: Callable[[], None]) {
    _turns.take(work);
}

impl refusal -> StoreConflict {
    return StoreConflict(ids=list(_refused));
}

impl begun(user: str) -> Flight {
    f = Flight();
    in_turn(lambda { pass_gate(f) });
    if not f.within {
        enter_caller(user, f.call);
    }
    return f;
}

impl pass_gate(f: Flight) {
    outer = rt_caller_call();
    if outer in _running {
        f.call = outer;
        f.within = True;
        return;
    }
    if _settling and not _turns.waits() {
        raise refusal();
    }
    while _settling {
        _turns.rest();
    }
    _numbered += 1;
    f.call = _numbered;
    f.epoch = _epoch;
    _running[f.call] = 1;
}

impl leave(f: Flight) {
    left = _running[f.call] - 1;
    if left > 0 {
        _running[f.call] = left;
    } else {
        del _running[f.call];
    }
    settle();
}

impl refuse(e: StoreConflict) {
    _settling = True;
    _epoch += 1;
    _refused = list(e.ids);
}

impl settle {
    if not _settling or len(_running) > 0 {
        return;
    }
    try {
        put_back();
    } finally {
        _settling = False;
        _turns.wake();
    }
}

impl keep(f: Flight, lost: list[StoreConflict]) {
    try {
        if _epoch == f.epoch {
            try {
                write_changes();
            } except StoreConflict as e {
                refuse(e);
            }
        }
        if _epoch != f.epoch {
            lost.append(refusal());
        }
    } finally {
        leave(f);
    }
}

impl rejoin(f: Flight) {
    while _settling {
        _turns.rest();
    }
    f.epoch = _epoch;
    _running[f.call] = _running.get(f.call, 0) + 1;
}

impl kept_call(user: str, work: Callable[[], any]) -> any {
    if _store is None {
        enter_caller(user, 0);
        return work();
    }
    f = begun(user);
    if f.within {
        return work();
    }
    tried = 0;
    forever {
        out: any = None;
        ran = False;
        try {
            out = work();
            ran = True;
        } finally {
            if not ran {
                in_turn(lambda { leave(f) });
            }
        }
        lost: list[StoreConflict] = [];
        in_turn(lambda { keep(f, lost) });
        if len(lost) == 0 {
            return out;
        }
        tried += 1;
        if tried >= TRIES or not _turns.waits() {
            raise lost[0];
        }
        in_turn(lambda { rejoin(f) });
        enter_caller(user, f.call);
    }
}

impl stream_begun(user: str) -> Flight {
    if _store is None {
        enter_caller(user, 0);
        return Flight(within=True);
    }
    return begun(user);
}

impl stream_paused(f: Flight) {
    if not f.within {
        in_turn(lambda { leave(f) });
    }
}

impl stream_resumed(f: Flight) -> StoreConflict | None {
    if f.within {
        return None;
    }
    lost: list[StoreConflict] = [];
    in_turn(lambda { resume(f, lost) });
    return lost[0] if len(lost) > 0 else None;
}

impl resume(f: Flight, lost: list[StoreConflict]) {
    _running[f.call] = _running.get(f.call, 0) + 1;
    if _epoch != f.epoch {
        lost.append(refusal());
    }
}

impl stream_kept(f: Flight) {
    if not f.within {
        commit();
    }
}

impl commit {
    if _store is None or _codec is None {
        return;
    }
    lost: list[StoreConflict] = [];
    in_turn(lambda { commit_now(lost) });
    if len(lost) > 0 {
        raise lost[0];
    }
}

impl commit_now(lost: list[StoreConflict]) {
    if _settling {
        lost.append(refusal());
        return;
    }
    try {
        write_changes();
    } except StoreConflict as e {
        refuse(e);
        lost.append(e);
        settle();
    }
}

impl sweep -> int {
    if _store is None or _codec is None {
        return 0;
    }
    commit();
    went: list[int] = [];
    in_turn(lambda { went.append(sweep_kept() + sweep_files(files_held())) });
    return went[0];
}

impl held_files -> list[str] {
    if _store is None or _codec is None {
        return [];
    }
    found: list[list[str]] = [];
    in_turn(lambda { found.append(list(files_held().keys())) });
    return found[0];
}

impl files_held -> dict[str, bool] {
    (s, _c) = keeper();
    held: dict[str, bool] = {};
    readers: dict[str, Callable[[dict[str, any]], list[str]]] = {};
    for t in _node_types {
        read = t.files;
        if read is not None {
            readers[t.name] = read;
        }
    }
    for u in _edge_types {
        read = u.files;
        if read is not None {
            readers[u.name] = read;
        }
    }
    for (name, read) in readers.items() {
        for r in s.of_type(name) {
            data: dict[str, any] = json.loads(r.data);
            data.pop("__grant", None);
            for id in read(data) {
                held[id] = True;
            }
        }
    }
    return held;
}

impl sweep_kept -> int {
    (s, _c) = keeper();
    nodes: dict[str, int] = {};
    edges: dict[str, int] = {};
    ends: dict[str, tuple[str, str]] = {};
    leads: dict[str, list[str]] = {};
    for r in s.every() {
        if r.kind == "n" {
            nodes[r.id] = r.version;
            continue;
        }
        edges[r.id] = r.version;
        ends[r.id] = (r.src, r.dst);
        if r.src not in leads {
            leads[r.src] = [];
        }
        leads[r.src].append(r.id);
    }
    reached: dict[str, bool] = {};
    todo: list[str] = [s.shared_root()] + s.roots();
    while len(todo) > 0 {
        nid = todo.pop();
        if nid in reached or nid not in nodes {
            continue;
        }
        reached[nid] = True;
        for eid in leads.get(nid, []) {
            if ends[eid][1] in nodes {
                reached[eid] = True;
                todo.append(ends[eid][1]);
            }
        }
    }
    w = Writing();
    for (eid, version) in edges.items() {
        if eid not in reached {
            (from_id, to_id) = ends[eid];
            w.gone.append(
                Row(
                    id=eid, kind="e", type_name="", data="", src=from_id, dst=to_id, version=version
                ),
            );
        }
    }
    for (nid, version) in nodes.items() {
        if nid not in reached {
            w.gone.append(Row(id=nid, kind="n", type_name="", data="", version=version));
        }
    }
    if len(w.gone) == 0 {
        return 0;
    }
    mark = s.write(w);
    for r in w.gone {
        if r.kind == "e" and r.id in _edges {
            rt_drop_held_edge(_edges[r.id]);
            forget(r.id);
        }
    }
    for r in w.gone {
        if r.kind == "n" and r.id in _nodes {
            n = _nodes[r.id];
            for into in [False, True] {
                for e in rt_edges_held(n, into) {
                    rt_drop_held_edge(e);
                }
            }
            forget(r.id);
        }
    }
    if mark == _mark[0] + 1 {
        _mark[0] = mark;
    }
    return len(w.gone);
}

impl node_text(n: Node, nid: str) -> str {
    (_s, c) = keeper();
    data = c.node_data(n);
    if nid in _grants {
        data["__grant"] = _grants[nid];
    }
    return json.dumps(data);
}

impl root_ids -> dict[str, bool] {
    out: dict[str, bool] = {jid(root.shared): True};
    for i in _roots {
        out[i] = True;
    }
    return out;
}

impl write_changes {
    (s, c) = keeper();
    w = Writing();
    roots = root_ids();
    gone: dict[str, bool] = {};
    asked: list[str] = [i for i in _removed if i in _nodes];
    for (nid, were) in _edges_at.items() {
        now = edges_here(_nodes[nid]);
        for eid in were {
            if eid not in now and eid not in gone {
                gone[eid] = True;
                asked.append(_ends[eid][1]);
            }
        }
    }
    doomed: dict[str, bool] = {};
    i = 0;
    while i < len(asked) {
        nid = asked[i];
        i += 1;
        if nid in doomed or nid in roots or nid not in _nodes {
            continue;
        }
        n = _nodes[nid];
        bring_edges(n);
        if len(rt_edges_held(n, True)) > 0 {
            continue;
        }
        doomed[nid] = True;
        for e in rt_edges_held(n, False) {
            eid = jid(e);
            if eid in _edges {
                gone[eid] = True;
            }
            asked.append(jid(rt_edge_dst(e)));
            rt_drop_held_edge(e);
        }
    }
    seen: dict[str, bool] = {};
    fresh_nodes: dict[str, Node] = {};
    fresh_edges: dict[str, any] = {};
    todo: list[Node] = [root.shared];
    for users in _roots.values() {
        todo.append(users);
    }
    for (nid, n) in _nodes.items() {
        if nid not in doomed {
            todo.append(n);
        }
    }
    i = 0;
    while i < len(todo) {
        n = todo[i];
        i += 1;
        nid = jid(n);
        if nid in seen {
            continue;
        }
        seen[nid] = True;
        text = node_text(n, nid);
        if _kept.get(nid) != text {
            kind = c.node_type(n);
            w.rows.append(
                Row(id=nid, kind="n", type_name=kind, data=text, version=_versions.get(nid, 0))
            );
            fresh_nodes[nid] = n;
            note_shape(w, kind);
        }
        for e in rt_edges_held(n, False) {
            eid = jid(e);
            dst = rt_edge_dst(e);
            etext = json.dumps(c.edge_data(e));
            if _kept.get(eid) != etext {
                kind = c.edge_type(e);
                w.rows.append(
                    Row(
                        id=eid,
                        kind="e",
                        type_name=kind,
                        data=etext,
                        src=nid,
                        dst=jid(dst),
                        ord=-1,
                        version=_versions.get(eid, 0),
                    ),
                );
                fresh_edges[eid] = e;
                note_shape(w, kind);
            }
            todo.append(dst);
        }
    }
    for eid in gone {
        (from_id, to_id) = _ends[eid];
        w.gone.append(
            Row(
                id=eid,
                kind="e",
                type_name="",
                data="",
                src=from_id,
                dst=to_id,
                version=_versions[eid],
            ),
        );
    }
    for nid in doomed {
        w.gone.append(Row(id=nid, kind="n", type_name="", data="", version=_versions[nid]));
    }
    for (user, rid) in _new_roots.items() {
        w.roots[user] = rid;
    }
    if len(_new_shared) > 0 {
        w.shared = _new_shared[0];
    }
    for (name, shape) in _new_shapes.items() {
        w.shapes[name] = shape;
    }
    if len(w.rows) + len(w.gone) + len(w.roots) + len(w.shapes) == 0 and w.shared == "" {
        return;
    }
    mark = s.write(w);
    for r in w.rows {
        _kept[r.id] = r.data;
        _versions[r.id] = r.version + 1;
        if r.kind == "n" {
            _nodes[r.id] = fresh_nodes[r.id];
        }
    }
    for nid in fresh_nodes {
        if nid not in _edges_at and not rt_awaits_edges(_nodes[nid]) {
            _edges_at[nid] = {};
        }
    }
    for r in w.rows {
        if r.kind == "e" {
            _ends[r.id] = (r.src, r.dst);
            _edges[r.id] = fresh_edges[r.id];
            for end in [r.src, r.dst] {
                if end in _edges_at {
                    _edges_at[end][r.id] = True;
                }
            }
        }
    }
    for r in w.gone {
        forget(r.id);
    }
    for (name, shape) in w.shapes.items() {
        _shapes[name] = shape;
    }
    _new_shapes.clear();
    _new_roots.clear();
    _new_shared.clear();
    _removed.clear();
    if mark == _mark[0] + 1 {
        _mark[0] = mark;
    }
}

impl note_shape(w: Writing, kind: str) {
    (_s, c) = keeper();
    shape = c.shape(kind);
    if shape != "" and _shapes.get(kind, "") != shape {
        w.shapes[kind] = shape;
    }
}

impl fields_changed(nid: str) -> bool {
    return node_text(_nodes[nid], nid) != _kept[nid];
}

impl edge_changed(eid: str, seen_at: dict[str, dict[str, bool]]) -> bool {
    (_s, c) = keeper();
    if json.dumps(c.edge_data(_edges[eid])) != _kept[eid] {
        return True;
    }
    for end in _ends[eid] {
        if end in _edges_at and eid in _edges_at[end] and eid not in held_here(end, seen_at) {
            return True;
        }
    }
    return False;
}

impl held_here(nid: str, seen_at: dict[str, dict[str, bool]]) -> dict[str, bool] {
    if nid not in seen_at {
        seen_at[nid] = edges_here(_nodes[nid]);
    }
    return seen_at[nid];
}

impl edges_changed(nid: str) -> bool {
    now = edges_here(_nodes[nid]);
    for eid in now {
        if eid not in _edges {
            return True;
        }
    }
    if nid in _edges_at {
        for eid in _edges_at[nid] {
            if eid not in now {
                return True;
            }
        }
    }
    return False;
}

impl node_changed(nid: str) -> bool {
    (_s, c) = keeper();
    if fields_changed(nid) {
        return True;
    }
    for eid in edges_here(_nodes[nid]) {
        if eid not in _edges or json.dumps(c.edge_data(_edges[eid])) != _kept[eid] {
            return True;
        }
    }
    return False;
}

impl take_in {
    (s, c) = keeper();
    mark = s.mark();
    if mark == _mark[0] {
        return;
    }
    got = s.since(_mark[0]);
    since = Changed();
    held_back = False;
    if got is not None {
        since = got;
    } else {
        held = list(_nodes.keys()) + list(_edges.keys());
        rows = s.rows(held);
        still = {r.id: True for r in rows};
        since = Changed(rows=rows, gone=[i for i in held if i not in still]);
        for (nid, n) in _nodes.items() {
            if nid in _edges_at {
                if edges_changed(nid) {
                    held_back = True;
                    continue;
                }
                del _edges_at[nid];
                rt_await_edges(n);
            }
        }
    }
    seen_at: dict[str, dict[str, bool]] = {};
    for i in since.gone {
        if i in _edges {
            if edge_changed(i, seen_at) {
                held_back = True;
                continue;
            }
            rt_drop_held_edge(_edges[i]);
            forget(i);
        }
    }
    for i in since.gone {
        if i in _nodes {
            if node_changed(i) {
                held_back = True;
                continue;
            }
            n = _nodes[i];
            for into in [False, True] {
                for e in rt_edges_held(n, into) {
                    eid = jid(e);
                    rt_drop_held_edge(e);
                    forget(eid);
                }
            }
            forget(i);
        }
    }
    for r in since.rows {
        if r.kind == "n" {
            if r.id in _nodes and r.version != _versions[r.id] {
                if fields_changed(r.id) {
                    held_back = True;
                    continue;
                }
                if r.data != _kept[r.id] {
                    data: dict[str, any] = json.loads(r.data);
                    c.fill_node(_nodes[r.id], data);
                    if "__grant" in data {
                        _grants[r.id] = int(data["__grant"]);
                    } elif r.id in _grants {
                        del _grants[r.id];
                    }
                    _kept[r.id] = r.data;
                }
                _versions[r.id] = r.version;
            }
            continue;
        }
        if r.id in _edges {
            if r.version != _versions[r.id] {
                if edge_changed(r.id, seen_at) {
                    held_back = True;
                    continue;
                }
                if r.data != _kept[r.id] {
                    c.fill_edge(_edges[r.id], json.loads(r.data));
                    _kept[r.id] = r.data;
                }
                _versions[r.id] = r.version;
            }
            continue;
        }
        if r.src in _edges_at or r.dst in _edges_at {
            bring_nodes([r.src, r.dst]);
            if r.src in _nodes and r.dst in _nodes {
                take_edge(r);
                for end in [r.src, r.dst] {
                    if end in _edges_at {
                        _edges_at[end][r.id] = True;
                    }
                }
            }
        }
    }
    if not held_back {
        _mark[0] = mark;
    }
    adopt_shared();
}

impl adopt_shared {
    s = _store;
    if s is None or len(_new_shared) == 0 {
        return;
    }
    kept = node_kept(s.shared_root());
    if kept is not None {
        _new_shared.clear();
        rt_set_shared_root(kept as Root);
    }
}

impl put_back {
    (s, c) = keeper();
    fresh: list[Node] = [root.shared] if len(_new_shared) > 0 else [];
    for rid in _new_roots.values() {
        fresh.append(_roots[rid]);
    }
    for r in fresh {
        for into in [False, True] {
            for link in rt_edges_held(r, into) {
                rt_drop_held_edge(link);
            }
        }
    }
    for (nid, n) in _nodes.items() {
        if node_text(n, nid) != _kept[nid] {
            data: dict[str, any] = json.loads(_kept[nid]);
            c.fill_node(n, data);
            if "__grant" in data {
                _grants[nid] = int(data["__grant"]);
            } elif nid in _grants {
                del _grants[nid];
            }
        }
    }
    for (eid, link) in _edges.items() {
        if json.dumps(c.edge_data(link)) != _kept[eid] {
            c.fill_edge(link, json.loads(_kept[eid]));
        }
    }
    for (nid, n) in list(_nodes.items()) {
        for into in [False, True] {
            for link in rt_edges_held(n, into) {
                if jid(link) not in _edges {
                    rt_drop_held_edge(link);
                }
            }
        }
        if nid in _edges_at {
            now = edges_here(n);
            for eid in _edges_at[nid] {
                if eid not in now {
                    del _edges_at[nid];
                    rt_await_edges(n);
                    break;
                }
            }
        }
    }
    _removed.clear();
    for (user, rid) in list(_new_roots.items()) {
        if s.root_of(user) != "" {
            del _new_roots[user];
            del _user_roots[user];
            if rid in _roots {
                del _roots[rid];
            }
        }
    }
    adopt_shared();
}
