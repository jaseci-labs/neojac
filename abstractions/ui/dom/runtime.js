// `@jac/runtime` under the `dom` plugin: what a browser space's modules import,
// and how its app starts. The compiler makes each element itself, with the
// DOM's own calls; what it calls here is the state a component keeps, what
// follows it, and the places of a page that change. Nothing here looks at a
// value to find out whether it follows state: the compiler says which parts
// do, and only those are given to `track`, `insert`, `when` and `each`.
import { js_fn } from "./core.js";
export * from "./session.js";

// ---- state, and what follows it
//
// A scope owns what was made while it ran: the computations, the scopes of
// list rows, and the functions `cleanup` gave it. Disposing a scope disposes
// all of them. A computation is a scope that runs a function, records the
// state it read, and runs again when one of them changes: a render
// computation (`track`) at once, a user effect (`effect`) once the update
// that made it is shown, a memo (`computed`) when it is read.
const CLEAN = 0, CHECK = 1, DIRTY = 2;
const RENDER = 0, USER = 1, MEMO = 2;

let Owner = null;
let Listener = null;
let depth = 0;
const renders = [];
const users = [];
let fail = (e) => console.error("jac: a component failed", e);

class Scope {
    constructor(owner) {
        this.owner = owner;
        this.owned = null;
        this.cleanups = null;
        this.gone = false;
        if (owner !== null) (owner.owned || (owner.owned = new Set())).add(this);
    }
}

class Computation extends Scope {
    constructor(fn, kind) {
        super(Owner);
        this.fn = fn;
        this.kind = kind;
        this.value = undefined;
        this.state = DIRTY;
        this.sources = [];
        this.observers = kind === MEMO ? new Set() : null;
    }
}

function read(node) {
    if (node.kind === MEMO && node.state !== CLEAN) update(node);
    const l = Listener;
    if (l !== null && !l.gone && !node.observers.has(l)) {
        node.observers.add(l);
        l.sources.push(node);
    }
    return node.value;
}

function write(node, v) {
    if (Object.is(node.value, v)) return;
    node.value = v;
    if (node.observers.size === 0) return;
    batch(() => {
        for (const o of node.observers) mark(o, DIRTY);
    });
}

function mark(c, state) {
    if (c.state >= state) return;
    const was = c.state;
    c.state = state;
    if (was !== CLEAN) return;
    if (c.kind === RENDER) renders.push(c);
    else if (c.kind === USER) users.push(c);
    else for (const o of c.observers) mark(o, CHECK);
}

// Whether `c` must run again: a memo it read that changed says so.
function stale(c) {
    if (c.state === CHECK) {
        for (const s of c.sources) {
            if (s.kind === MEMO) {
                update(s);
                if (c.state === DIRTY) break;
            }
        }
    }
    if (c.state === DIRTY) return true;
    c.state = CLEAN;
    return false;
}

function update(c) {
    if (!c.gone && stale(c)) run(c);
}

function run(c) {
    clean(c);
    c.state = CLEAN;
    const o = Owner, l = Listener;
    Owner = Listener = c;
    let v = c.value;
    try {
        v = c.fn(c.value);
    } catch (e) {
        fail(e);
    } finally {
        Owner = o;
        Listener = l;
    }
    if (c.kind !== MEMO) {
        c.value = v;
    } else if (!Object.is(c.value, v)) {
        c.value = v;
        for (const ob of c.observers) if (ob.state === CHECK) ob.state = DIRTY;
    }
}

function clean(s) {
    if (s.owned !== null) {
        const owned = Array.from(s.owned);
        s.owned = null;
        for (let i = owned.length - 1; i >= 0; i--) dispose(owned[i]);
    }
    if (s.cleanups !== null) {
        const cs = s.cleanups;
        s.cleanups = null;
        for (let i = cs.length - 1; i >= 0; i--) {
            try {
                cs[i]();
            } catch (e) {
                fail(e);
            }
        }
    }
    if (s.sources !== undefined) {
        for (const src of s.sources) src.observers.delete(s);
        s.sources.length = 0;
    }
}

function dispose(s) {
    if (s.gone) return;
    clean(s);
    s.gone = true;
    if (s.owner !== null && s.owner.owned !== null) s.owner.owned.delete(s);
}

// A computation whose owner is running again, or is to, runs after it: its
// owner may dispose it first.
function top(c) {
    if (c.gone || c.state === CLEAN) return;
    const chain = [c];
    for (let o = c.owner; o !== null; o = o.owner) {
        if (o.gone) return;
        if (o.state !== undefined && o.state !== CLEAN && o.kind !== MEMO) chain.push(o);
    }
    for (let i = chain.length - 1; i >= 0; i--) if (!chain[i].gone) update(chain[i]);
}

// Runs `fn`, then brings the page up to date: every render computation
// first, then the user effects, whose cleanups (an exit's body) all run
// before any of them runs again, as they do between two showings under a
// rerender library.
function batch(fn) {
    if (depth > 0) return fn();
    depth++;
    try {
        const v = fn();
        let ran = 0;
        while (renders.length > 0 || users.length > 0) {
            if (++ran > 1000000) throw new Error("jac: state kept changing as the page was updated");
            if (renders.length > 0) {
                top(renders.shift());
                continue;
            }
            const due = [];
            for (const u of users.splice(0)) {
                if (!u.gone && stale(u)) {
                    clean(u);
                    due.push(u);
                }
            }
            for (const u of due) if (!u.gone) run(u);
        }
        return v;
    } finally {
        depth--;
    }
}

function runIn(owner, fn) {
    const o = Owner, l = Listener;
    Owner = owner;
    Listener = null;
    try {
        return fn();
    } finally {
        Owner = o;
        Listener = l;
    }
}

// `has x: T = v;` (`[ui.state]`, shape "pair"): its reader and its setter.
export function signal(value) {
    const s = { value, observers: new Set() };
    return [() => read(s), (v) => write(s, v)];
}

// A derived value (`[ui.computed]`): its reader. It is worked out again when
// what it read changes, and what reads it follows it only when its value is
// another.
export function computed(fn) {
    const c = new Computation(fn, MEMO);
    update(c);
    return () => read(c);
}

// `can with ... entry` (`[ui.effect]`): runs once what is being shown is in
// the page, and again after each change of what it read.
export function effect(fn) {
    const c = new Computation(fn, USER);
    if (depth > 0) users.push(c);
    else batch(() => update(c));
}

// Runs `fn(last)` now, and again whenever what it read changes, given what it
// gave the last time: how the compiler keeps an attribute, a style, a
// listener or a ref that reads state current.
export function track(fn) {
    const c = new Computation(fn, RENDER);
    batch(() => update(c));
}

// `can with ... exit` (`[ui.cleanup]`): runs when the scope it is called in
// runs again or is disposed.
export function cleanup(fn) {
    if (Owner !== null) (Owner.cleanups || (Owner.cleanups = [])).push(fn);
}

// What an effect reads without following it (`[ui.untrack]`).
export function untrack(fn) {
    const l = Listener;
    Listener = null;
    try {
        return fn();
    } finally {
        Listener = l;
    }
}

// ---- the parts of a page
//
// A child's value as nodes: None, True and False are none, a string or a
// number its text, a node itself (a fragment its nodes), a list each item's,
// anything else its text as Jac writes it.
function nodes(v, out) {
    if (v === undefined || v === null || v === true || v === false) return out;
    if (typeof v === "string") out.push(document.createTextNode(v));
    else if (typeof v === "number" || typeof v === "bigint") out.push(document.createTextNode(String(v)));
    else if (v instanceof Node) {
        if (v.nodeType === 11) out.push(...v.childNodes);
        else out.push(v);
    } else if (Array.isArray(v)) {
        for (const x of v) nodes(x, out);
    } else out.push(document.createTextNode(String(v)));
    return out;
}

const textual = (v) => typeof v === "string" || typeof v === "number" || typeof v === "bigint";

// A place in the page that changes: every node of the element it is in
// (`sole`, when the compiler says it is that element's only child), or the
// nodes between two empty comments. Its nodes are worked out from the page
// each time, so what a place inside it changed is its own too.
class Region {
    constructor(parent, sole) {
        this.sole = sole;
        this.parent = parent;
        this.start = null;
        this.end = null;
        if (!sole) {
            this.start = document.createComment("");
            this.end = document.createComment("");
            parent.append(this.start, this.end);
        }
    }
    host() {
        return this.sole ? this.parent : this.end.parentNode;
    }
    first() {
        return this.sole ? this.parent.firstChild : this.start.nextSibling;
    }
    clear() {
        if (this.sole) {
            this.parent.textContent = "";
            return;
        }
        const p = this.end.parentNode;
        for (let n = this.start.nextSibling; n !== this.end; ) {
            const next = n.nextSibling;
            p.removeChild(n);
            n = next;
        }
    }
    set(v) {
        if (textual(v)) {
            const n = this.first();
            if (n !== null && n.nodeType === 3 && n.nextSibling === this.end) {
                const t = String(v);
                if (n.data !== t) n.data = t;
                return;
            }
        }
        this.clear();
        const p = this.host();
        for (const n of nodes(v, [])) p.insertBefore(n, this.end);
    }
}

// A child that reads no state: its value's nodes, added to `parent`.
export function append(parent, value) {
    for (const n of nodes(value, [])) parent.appendChild(n);
}

// A child that reads state: `fn()`'s nodes, made again when what it read
// changes. What was made in the last run is disposed first.
export function insert(parent, fn, sole) {
    const r = new Region(parent, sole === true);
    track(() => r.set(fn()));
}

// `{a if c else b}` that reads state: the branch `cond()` picks, made again
// only when `cond()` changes from true to false or back (and when what the
// branch itself reads changes). The branch it leaves is disposed.
export function when(parent, cond, yes, no, sole) {
    const r = new Region(parent, sole === true);
    const c = computed(() => !!cond());
    track(() => {
        const pick = c() ? yes : no;
        track(() => r.set(pick()));
    });
}

// `[<E/> for x in xs]` that reads state: a row made by `row(item)` for each
// item of `items()`, kept with its item while the item is in the list
// (items are matched by identity, a repeated item row by row in order), moved
// where the item moves, and disposed with its nodes when the item leaves.
export function each(parent, items, row, sole) {
    const r = new Region(parent, sole === true);
    const home = new Scope(Owner);
    let rows = [];
    const make = (item) => {
        const scope = new Scope(home);
        const made = nodes(runIn(scope, () => row(item)), []);
        if (made.length !== 1 || made[0].nodeType !== 1) made.push(document.createComment(""));
        return { item, scope, nodes: made, last: made[made.length - 1] };
    };
    track(() => {
        const list = items();
        untrack(() => {
            let n = r.first();
            for (const row of rows) {
                row.nodes = [];
                for (;;) {
                    row.nodes.push(n);
                    if (n === row.last) break;
                    n = n.nextSibling;
                }
                n = n.nextSibling;
            }
            const pool = new Map();
            for (const row of rows) {
                const q = pool.get(row.item);
                if (q === undefined) pool.set(row.item, [row]);
                else q.push(row);
            }
            const next = new Array(list.length);
            for (let i = 0; i < list.length; i++) {
                const q = pool.get(list[i]);
                next[i] = q !== undefined && q.length > 0 ? q.shift() : null;
            }
            for (const q of pool.values()) {
                for (const row of q) {
                    dispose(row.scope);
                    for (const x of row.nodes) x.remove();
                }
            }
            for (let i = 0; i < list.length; i++) if (next[i] === null) next[i] = make(list[i]);
            const p = r.host();
            let at = r.first();
            for (const row of next) {
                if (row.nodes[0] === at) {
                    at = row.last.nextSibling;
                    continue;
                }
                for (const x of row.nodes) p.insertBefore(x, r.sole ? at : at || r.end);
            }
            rows = next;
        });
    });
}

// ---- attributes
const NS = { xlink: "http://www.w3.org/1999/xlink", xml: "http://www.w3.org/XML/1998/namespace" };

// An attribute by HTML's name: True writes it bare, False and None remove it,
// anything else is written as its text.
export function attr(el, name, v) {
    const colon = name.indexOf(":");
    const ns = colon > 0 ? NS[name.slice(0, colon)] : undefined;
    if (v === undefined || v === null || v === false) {
        if (ns !== undefined) el.removeAttributeNS(ns, name.slice(colon + 1));
        else el.removeAttribute(name);
        return;
    }
    const text = v === true ? "" : String(v);
    if (ns !== undefined) el.setAttributeNS(ns, name, text);
    else el.setAttribute(name, text);
}

const entries = (v) => (v instanceof Map ? Array.from(v.entries()) : Object.entries(v));

// `style`: a string is the element's whole declaration, a dict each CSS
// property by its CSS name; None and False clear it. Set through the CSSOM,
// never as a `style` attribute, so `style-src 'self'` holds. Gives what it
// set, which the next call is given as `prev`.
export function style(el, v, prev) {
    const s = el.style;
    if (v === undefined || v === null || v === false) {
        s.cssText = "";
        return undefined;
    }
    if (typeof v === "string") {
        s.cssText = v;
        return v;
    }
    const now = new Map(entries(v));
    if (typeof prev === "string") s.cssText = "";
    else if (prev !== undefined && prev !== null && prev !== false) {
        for (const [k] of entries(prev)) if (!now.has(k)) s.removeProperty(k);
    }
    for (const [k, x] of now) {
        if (x === undefined || x === null || x === false) s.removeProperty(k);
        else s.setProperty(k, String(x));
    }
    return v;
}

// `on<Event>`: `h` listens for the event until the scope it was added in is
// disposed. None adds nothing.
export function listen(el, type, h) {
    if (h === undefined || h === null) return;
    const f = js_fn(h);
    el.addEventListener(type, f);
    if (Owner !== null) (Owner.cleanups || (Owner.cleanups = [])).push(() => el.removeEventListener(type, f));
}

const PROPS = { value: true, checked: true, selected: true };
const isEvent = (k) => k.length > 2 && k[0] === "o" && k[1] === "n" && k[2] >= "A" && k[2] <= "Z";

// `{...d}` on an element: each entry as the attribute of its name would be.
// `children` and `key` are not attributes. Gives what it set, which the next
// call is given as `prev`, so that an entry no longer there is removed.
export function spread(el, d, prev) {
    const now = new Map();
    if (d instanceof Map) {
        for (const [k, v] of d) if (k !== "children" && k !== "key") now.set(k, v);
    } else if (d !== undefined && d !== null) {
        for (const k of Object.keys(d)) if (k !== "children" && k !== "key") now.set(k, d[k]);
    }
    if (prev !== undefined) {
        for (const [k, v] of prev) {
            if (now.has(k) || isEvent(k) || k === "ref") continue;
            if (k === "style") style(el, undefined, v);
            else if (PROPS[k]) el[k] = k === "value" ? "" : false;
            else attr(el, k, undefined);
        }
    }
    for (const [k, v] of now) {
        if (isEvent(k)) listen(el, k.slice(2).toLowerCase(), v);
        else if (k === "ref") {
            if (v !== undefined && v !== null) v.current = el;
        } else if (k === "style") style(el, v, prev !== undefined ? prev.get("style") : undefined);
        else if (PROPS[k]) el[k] = v;
        else attr(el, k, v);
    }
    return now;
}

// ---- components
//
// A component's props are one object: a prop that reads state is a getter,
// so the component's own reads of it follow it, and `children` is a getter
// that makes the children where they are read.

// A component, called once, its reads untracked: what it makes is owned by
// the scope it was called in.
export function component(fn, props) {
    return untrack(() => fn(props));
}

// `<@{t} ...>`: an element whose tag is `t`, a string, or a component.
export function tag(t, props) {
    if (t === undefined || t === null) return null;
    if (typeof t !== "string") return component(t, props);
    const el = document.createElement(t);
    track((prev) => spread(el, props, prev));
    if ("children" in props) insert(el, () => props.children, true);
    return el;
}

// A component's props with a spread among them: each part is an object of
// props written by name, or a function giving a spread's entries, read each
// time a prop is; a later part's prop stands over an earlier one's.
export function merge(...parts) {
    const at = (p) => (typeof p === "function" ? p() : p);
    const find = (k) => {
        for (let i = parts.length - 1; i >= 0; i--) {
            const o = at(parts[i]);
            if (o !== undefined && o !== null && k in o) return o;
        }
        return undefined;
    };
    return new Proxy(
        {},
        {
            get: (_, k) => {
                const o = find(k);
                return o === undefined ? undefined : o[k];
            },
            has: (_, k) => find(k) !== undefined,
            ownKeys: () => {
                const keys = new Set();
                for (const p of parts) {
                    const o = at(p);
                    if (o !== undefined && o !== null) for (const k of Object.keys(o)) keys.add(k);
                }
                return Array.from(keys);
            },
            getOwnPropertyDescriptor: (_, k) => {
                if (find(k) === undefined) return undefined;
                return {
                    enumerable: true,
                    configurable: true,
                    get: () => {
                        const o = find(k);
                        return o === undefined ? undefined : o[k];
                    },
                };
            },
        },
    );
}

// HTML made elsewhere, shown as it is: a fragment of its nodes. Use only on
// HTML the project controls. A script in it does not run.
export function unsafe_html(html) {
    const t = document.createElement("template");
    t.innerHTML = String(html);
    return t.content;
}

// What `fn()` makes, shown in `el` in place of what it held, until the
// returned function disposes it: a space with no routes starts so.
export function mount(fn, el) {
    const scope = new Scope(null);
    runIn(scope, () => {
        try {
            batch(() => {
                const v = untrack(fn);
                if (broken === el) return;
                el.textContent = "";
                append(el, v);
            });
        } catch (e) {
            fail(e);
        }
    });
    return () => dispose(scope);
}

// ---- routes
//
// Where the app is served, with no slash at its end: its space's `base`, which
// every route is under.
let served = "";
let table = [];
let where = null;
let moveTo = null;
let matched = () => null;

const here = () => {
    const p = window.location.pathname;
    if (served === "") return p;
    if (p === served) return "/";
    return p.startsWith(served + "/") ? p.slice(served.length) : null;
};

const decode = (s) => {
    try {
        return decodeURIComponent(s);
    } catch (_) {
        return s;
    }
};

// Routes are tried most specific first, as React Router ranks them: a fixed
// segment before a parameter, and a `*` last.
function rank(routes) {
    return routes
        .map((r, i) => {
            const segs = r.path.split("/").filter(Boolean);
            let score = segs.length + 1;
            for (const s of segs) score += s === "*" ? -2 : s[0] === ":" ? 3 : 10;
            return { r, i, segs, score };
        })
        .sort((a, b) => b.score - a.score || a.i - b.i);
}

function match(path) {
    if (path === null) return null;
    const got = path.split("/").filter(Boolean).map(decode);
    for (const { r, segs } of table) {
        const params = {};
        let rest = null;
        let ok = true;
        let i = 0;
        for (; i < segs.length; i++) {
            const s = segs[i];
            if (s === "*") {
                rest = got.slice(i);
                break;
            }
            if (i >= got.length) {
                ok = false;
                break;
            }
            if (s[0] === ":") params[s.slice(1)] = got[i];
            else if (s.toLowerCase() !== got[i].toLowerCase()) {
                ok = false;
                break;
            }
        }
        if (ok && (rest !== null || i === got.length)) return { route: r, params, rest: rest || [] };
    }
    return null;
}

export function navigate(path) {
    window.history.pushState({}, "", served + path);
    window.dispatchEvent(new PopStateEvent("popstate"));
}

// A page's props: its route's parameters, each by name, and the rest of the
// path (a `*` parameter) as its segments, following the address.
function pageProps(r) {
    const props = {};
    const now = () => {
        const m = matched();
        return m !== null && m.route === r ? m : null;
    };
    for (const n of r.params || []) {
        Object.defineProperty(props, n, { enumerable: true, get: () => (now() || { params: {} }).params[n] });
    }
    if (r.rest) Object.defineProperty(props, r.rest, { enumerable: true, get: () => (now() || { rest: [] }).rest });
    return props;
}

// Where a layout puts the page: the page whose route matches the address,
// loaded when it is first shown. Another address of the same route gives the
// same page new parameters; another route disposes it.
export function Outlet() {
    const f = document.createDocumentFragment();
    const r = new Region(f, false);
    const route = computed(() => {
        const m = matched();
        return m === null ? null : m.route;
    });
    track(() => {
        const rt = route();
        untrack(() => r.set(null));
        if (rt === null) return;
        const owner = Owner;
        const show = (m) => {
            try {
                runIn(owner, () => batch(() => r.set(component(m.page, pageProps(rt)))));
            } catch (e) {
                fail(e);
            }
        };
        if (rt.$module !== undefined) {
            show(rt.$module);
            return;
        }
        let alive = true;
        cleanup(() => {
            alive = false;
        });
        rt.load().then((m) => {
            rt.$module = m;
            if (alive && !owner.gone) show(m);
        }, fail);
    });
    return f;
}

// A link to a route, `<Link to="/user/amy">amy</Link>`: an `<a>` whose click
// changes the page without loading it again. A click with a modifier key, or
// on a link with another `target`, is the browser's.
export function Link(props) {
    const a = document.createElement("a");
    track(() => attr(a, "href", served + props.to));
    track((prev) => {
        const given = {};
        for (const k of Object.keys(props)) if (k !== "to" && k !== "children" && k !== "onClick") given[k] = props[k];
        return spread(a, given, prev);
    });
    a.addEventListener("click", (ev) => {
        const own = untrack(() => props.onClick);
        if (own !== undefined && own !== null) js_fn(own)(ev);
        if (ev.defaultPrevented || ev.button !== 0 || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey) return;
        const target = a.getAttribute("target");
        if (target !== null && target !== "" && target !== "_self") return;
        ev.preventDefault();
        navigate(untrack(() => props.to));
    });
    insert(a, () => props.children, true);
    return a;
}

// An element that goes to its `to` once shown.
export function Navigate(props) {
    effect(() => {
        const to = props.to;
        untrack(() => navigate(to));
    });
    return null;
}

// A failure as the page shows it, in place of the page, which is not shown
// again.
let broken = null;
function shown(el, e) {
    broken = el;
    const pre = document.createElement("pre");
    pre.style.padding = "2rem";
    pre.style.whiteSpace = "pre-wrap";
    pre.textContent = String((e && e.stack) || e);
    el.textContent = "";
    el.appendChild(pre);
}

// The app: its routes, each `{path, load, params, rest}`; its layout, which
// wraps every page; its entry, whose `app` wraps everything; and the `base`
// it is served at. It is shown in `#root`. An address no route matches shows
// neither layout nor page.
export function startApp({ routes, layout, entry, base }) {
    served = (base || "/").replace(/\/+$/, "");
    table = rank(routes);
    const [at, setAt] = signal(here());
    where = at;
    moveTo = setAt;
    matched = computed(() => match(where()));
    window.addEventListener("popstate", () => moveTo(here()));
    const el = document.getElementById("root");
    fail = (e) => {
        console.error("jac: a component failed", e);
        shown(el, e);
    };
    const pages = () => {
        const f = document.createDocumentFragment();
        when(
            f,
            () => matched() !== null,
            () => component(layout || Outlet, {}),
            () => {
                console.warn("jac: no page's route matches " + window.location.pathname);
                return null;
            },
            false,
        );
        return f;
    };
    const app = entry && entry.app;
    mount(() => (app ? component(app, { get children() { return pages(); } }) : pages()), el);
}
