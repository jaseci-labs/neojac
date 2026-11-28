---
name: pages-and-components
description: Use when adding web pages, a UI or a front end to a neojac app - a browser space with pages/ routes, components in JSX, state and effects, calling the server from a page, npm packages for the page, choosing React, Preact, Solid or dom (no npm package, no bundler), and building and looking at the result.
---
# Pages and components

## When to use this

Use it to give an app a browser front end: a `browser` space, its `pages/`, components, state
(`has`), effects (`can with entry`), and a page's calls of server functions.

- Load `writing-jac` first. The server the pages call is `building-an-app`: do that first if
  the project has no `graph spaces` yet.
- npm packages beyond the UI library: `using-npm-packages`.
- A chat pane whose answers a language model streams: `language-models-and-agents`.

## Before you start

```sh
neojac docs apps/pages          # routes, layout, entry, the HTML shell, @jac/runtime, signing in
neojac docs component           # JSX, props, state, effects, refs, hooks
neojac docs form                # forms, event handlers, onSubmit and preventDefault
neojac docs apps/ui-bindings    # React (default), Preact, Solid, dom, none
```

File routes need the `react` plugin, the standard `ui` plugin of a browser space, or `dom`. Under
`preact` or `solid` a space has no `pages/` (E1279): render from the entry instead, as
`neojac docs apps/ui-bindings` shows. A space's `ui` plugin is named in `jac.toml`:
`[spaces.<space>.ui]` `plugin = "dom"`.

`dom` needs no npm package and no bundler: skip step 2 below, and the build writes the page's
document itself, with what `[spaces.<space>.document]` says (`title`, `lang`, `noscript`). Its
pages run under `[spaces.<space>.headers]` `Content-Security-Policy` of `script-src 'self';
style-src 'self'`. Write attributes by HTML's names (`class`, `for`, `onDblClick`): React's
`className`, `htmlFor` and `onDoubleClick` are refused (E5273). `False` removes an attribute, so
an enumerated one is a string (`spellcheck="false"`). Import style sheets from the entry
(`import "./site.css";`). `neojac docs apps/ui-bindings` (section "dom") has the rest.

Pages a library ships with it (a sign-in or settings page every app that uses the library gets)
are a browser space of the library's own `archwire.jac`, served at the `base` its `jac.toml`
gives it, with a `ui` plugin neojac ships. An app that loads the library serves them without
naming them, and its program carries them: `neojac docs apps/archwire` (section "A package's
browser spaces").

## Steps

1. **Add the browser space and serve it** in `archwire.jac`. Put its modules in layers, and wire
   each server function a page calls into that page, with one edge rule for each pair of layers a
   wire crosses:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer service { svc; }
    layer ui { ui.*; }
    layer pages { web | pages.*; }
}

graph spaces {
    space api: native { svc; }
    space site: browser { entry web; pages.* | ui.*; }

    app web { run api; serve site; }
}

graph import {
    edge Calls: service --> pages;
    edge Ui: ui --> pages;

    svc ++> pages.index { greet, AddItem }
    ui.counter ++> pages.index { Counter }
}
```

Every function or walker a page calls is `:pub` or `:prot` in `svc.jac` (E1210 otherwise).

2. **Add the page's packages and its bundler's two files.** Copy the `[npm."eco/web"]` tables into
   `jac.toml`, and `vite.config.ts` and `index.html` into `eco/web/`, exactly from
   `neojac docs apps/index` (section "The smallest project"): React, React Router, Vite, and the
   Vite plugin `@jac/vite`, which the build supplies. Write no `package.json`: neojac writes it. `index.html` has `<div id="root"></div>` and
   `<script type="module" src="/@jac/entry"></script>`. Then install, once:

```sh
neojac install
```

It warns that esbuild's install script was not run (`esbuild@... (postinstall: node install.js)`,
`not yet covered by allowScripts`). Leave it: the build does not need that script, and works
without it.

3. **Write the entry** `web.jac` (optional): global style sheets, and an `app` that wraps every
   page:

<!-- example: not checked: an entry is a module of a browser space, with JSX -->
```jac
import "./styles/site.css";

def:pub app(children: any) -> JsxElement {
    return <main className="app">{children}</main>;
}
```

4. **Write a component** `ui/counter.jac`. State is `has`, assigned (never changed in place);
   a derived local stays current; an effect lists every piece of state it reads:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def:pub Counter(step: int = 1, label: str = "count") -> JsxElement {
    has count: int = 0;

    doubled = count * 2;

    can with [count] entry {
        document.title = f"{label}: {count}";
    }

    return <button onClick={lambda { count = count + step; }}>{label}: {count} (doubled {doubled})</button>;
}
```

5. **Write the pages.** `pages/index.jac` is `/`; a page's `str` parameters are URL segments
   (`pages/item.jac` with `page(name: str)` is `/item/:name`). Every crossing is awaited, and a
   spawn needs its own parentheses. A form's field shows state (`value={draft}`) and its
   `onInput` handler assigns it; the `onSubmit` handler calls `e.preventDefault()` before its
   first `await`, or the browser reloads the page:

<!-- example: not checked: a page is a module of a browser space, with JSX and crossings -->
```jac
def:pub page -> JsxPage {
    has text: str = "...";
    has draft: str = "";
    has items: list[str] = [];

    async can with entry {
        text = await greet("jac");
    }

    async def add(e: any) {
        e.preventDefault();
        name = draft.strip();
        if name == "" {
            return;
        }
        draft = "";
        w = await (root spawn AddItem(name=name));
        items = w.reports[0];
    }

    return <section>
        <h1>{text}</h1>
        <Counter step={5} />
        <form onSubmit={add}>
            <input value={draft} onInput={lambda (e: any) { draft = e.target.value; }} />
            <button type="submit">add</button>
        </form>
        <ul>{[<li key={i}>{i}</li> for i in items]}</ul>
    </section>;
}
```

- An event handler's parameter is `e: any` (the library's event; `e.target.value`,
  `e.target.checked` are read as the program runs). A checkbox is `checked={b}` with
  `onChange={lambda (e: any) { b = e.target.checked; }}`.
- Use `onInput` for text: under Solid, `onChange` runs only when the field is left.
- An `async def` is given to `onSubmit` or `onClick` as it is; to pass an argument,
  `onClick={lambda { finish(it.id) }}`. A handler that calls an `async def` as a statement, as
  `lambda { finish(it.id); }` does, drops its coroutine: E1278.
- An exception in a handler goes to the browser's console, not the page: catch `RemoteError`
  (from `"@jac/runtime"` in a page) and show it with state.

`pages/layout.jac` wraps every page; `<Outlet />` is where the page goes:

<!-- example: not checked: a page is a module of a browser space, with JSX -->
```jac
import from "@jac/runtime" { Link, Outlet }

def:pub layout -> JsxLayout {
    return <div>
        <nav><Link to="/">home</Link> <Link to="/item/pear">pear</Link></nav>
        <Outlet />
    </div>;
}
```

6. **Check the space, build and run:**

```sh
neojac check --space site                    # prints nothing when right
JAC_WEB_LISTEN=127.0.0.1:8302 neojac run web
```

Avoid relying on an incremental rebuild to find a page file you just added, for now: a known
defect leaves it out of the routes. After adding a page, remove `.jac/build/<app>/` and build.

7. **Look at the result in a browser**, not with `curl`: the HTML shell is the same for every
   route, and the page renders in JavaScript. `neojac browse` drives one, which it fetches the
   first time, and prints what the page became:

```sh
neojac browse open 127.0.0.1:8302/
neojac browse snapshot              # the page as an outline, each control with a ref
neojac browse click @e3             # act on a ref, or on a CSS selector
neojac browse fill 'input' apple
neojac browse press Enter
neojac browse get html main         # the DOM itself
neojac browse errors                # what a component raised
neojac browse close
```

Errors a component raises are printed to the browser's console (`neojac browse console` and
`errors`), not to the server's output. `neojac docs browse` has every command.

## What a correct result looks like

- `neojac check --space site` and `neojac build web` succeed; `dist/web-<platform>/` holds
  the program and `pages/site/`.
- The DOM at `/` is `<main class="app"><div><nav>...</nav><section><h1>hello jac</h1><button>count: 0 (doubled 0)</button>...`;
  after one click the button reads `count: 5 (doubled 10)` and the title `count: 5`. After
  typing `apple` in the field and pressing Enter (or `add`), the list holds `apple`, the field
  is empty, and the page has not reloaded.
- `/item/pear` shows `<p>item pear</p>` inside the layout.

Close the browser session and stop the server before you finish.

## Mistakes to expect

| Code | Means | Fix |
|---|---|---|
| E1001 `expected str, found Coroutine[...]` | A crossing not awaited | `await` it, in an `async` effect or handler |
| E1278 | A crossing's result, or an `async def`'s coroutine, dropped | `await` it |
| E1021 `cannot iterate AsyncIterator[...]`, E1041 `AsyncIterator[...] is not awaitable` | A server function that gives an iterator is a stream | Read it with `async for item in f(...) { ... }` in an `async def` |
| The page reloads on submit | No `e.preventDefault()`, or one after an `await` | Call it first in the `onSubmit` handler |
| E1210 | A page calls an untagged server function | Tag it `:pub` or `:prot` |
| E1217 | State changed in place (`items.append(x)`) | Assign: `items = items + [x]` |
| E1215 | `has` inside an `if` or loop | Move it to the top of the body |
| E1216 | A plain statement (`print(...)`) in a component's body | Move it into an effect |
| E1225 | An effect reads state its list leaves out | Add it: `can with [count, other] entry` |
| E1227 | A file under `pages/` with no `page` function | Add `def:pub page -> JsxPage`, or move the file out of `pages/` |
| E1228 | A `page` parameter that is not `name: str` or `*rest: str` | Take `str` and convert inside |
| E1219 | A package another `ui` plugin owns (`solid-js` under React) | Use the packages of the space's own `ui` plugin |
| W1100 `cannot find module` | npm package not among the tree's | `neojac install --npm <pkg>` |
| E5160 | The tree is not installed as `jac.toml` says | `neojac install` |
| E2018 `unknown type 'JsxElement'` | A component in a native module, where JSX is `Markup`, HTML text | Put components in the browser space's modules |
| E1050, E1052, E1053 on a tag | Props checked as keyword arguments | Match the component's parameters |

## Where to look things up

- `neojac docs apps/pages`: routes, `*rest`, layout, `@jac/runtime`, `sign_in`, style sheets.
- `neojac docs component`: JSX forms, keys, refs (`Ref`), hooks, rules under Solid.
- `neojac docs form`: fields bound to state, events, handlers that await, `onChange` under Solid.
- `neojac docs apps/ui-bindings`: a space's `ui` and `bundler` plugins (`[spaces.<space>.ui]`, `[spaces.<space>.bundler.vite]` `config`) and its `base`.
- `neojac docs host`: wasm spaces a page calls, desktop apps, their arrangements and local users
  (`jacArrangement`, `sign_in`).
- `neojac docs crossings`: what a page may call, reading a stream with `async for`, and how a
  call fails (`RemoteError`).
