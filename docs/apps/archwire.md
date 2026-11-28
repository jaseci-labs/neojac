---
description: The graph spaces block of archwire.jac, which declares a project's spaces, their hosts and modules, its apps, its packages and its profiles.
keywords: graph spaces, spaces, space, app, package, ship, wheel, profile, run, serve, module pattern
grammar: graph_spaces, space_decl, app_decl, package_decl, module_pattern, name_list
---
# The archwire's spaces

`graph spaces { ... }` in a project's `archwire.jac` says where the project's code runs: which
modules form each space, the host each space runs on, and which spaces each app runs or serves.
Nothing in a module's own source says any of it.

`archwire.jac` sits at the project's root, beside `jac.toml`. Its other sections are
`graph layers`, which groups the project's modules into the layers every archwire declares
([Layers](../language/modules-layers.md)), and `graph import`, which declares which modules import
which and what each wire carries: see [Wiring modules](../language/modules-wiring.md)
(`neojac docs language/modules-wiring`). A `graph spaces` block anywhere else is E2088.

## Syntax

```ebnf
graph_spaces ::= "graph" "spaces" NAME? "{" (space_decl | app_decl | package_decl)* "}"

space_decl ::= "space" NAME ":" (KEYWORD | NAME) "{" (("entry" wire_module_path | STRING | module_pattern ("|" module_pattern)*) ";")* "}"

package_decl ::= "package" NAME "{" ("ship" name_list)* "}"

app_decl ::= "app" NAME "{" (NAME "has" NAME ("." NAME)* ("," NAME ("." NAME)*)* ";" | ("run" | "serve") name_list)* "}"

module_pattern ::= "*" | wire_module_path ("." "*")?
```

`spaces`, `space`, `app`, `package`, `run`, `serve` and `ship` are keywords in an `archwire.jac`, and
names in every other file: a program may still name a function `app` or a variable `space`, and a
wire carries such a name as it is written (`cli ++> main { run }`). A space, an app or a package is
not named with one (E0013); a module is listed by its name whatever the word.
In a space, `entry` is the entry clause only when a module path follows it: `entry;`
and `entry | ui;` list a module named `entry`, as any other name is listed.

A complete block, below the `graph layers` block its archwire declares:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space site: browser { entry web; pages.* | ui.*; }
    space api: native { core.orders | core.stock; }
    space reports: cpython { reports.*; }
    space cli: native { entry cli; }

    app web { run api, reports; serve site; }
    app cli { run cli; }
}
```

`neojac fmt archwire.jac` lays a space or an app that fits on one line out on one line.

## Spaces

`space <name>: <host> { ... }` declares a space. Its body holds:

| Line | Meaning |
|---|---|
| `entry <module>;` | The module the space's program starts at. At most one (E1270). |
| `<pattern> \| <pattern> ...;` | Modules the space holds |

A space's name appears in URLs (`/__jac/call/<space>/...`), in environment variables
(`JAC_REMOTE_<SPACE>`) and in `jac.toml` (`[spaces.<space>]`), so keep it a plain lowercase word.

### Hosts

The host is one of six words. Any other is E1226.

| Host | The space's code becomes | Runs in |
|---|---|---|
| `native` | Machine code, through LLVM | The app's own process |
| `browser` | ES modules, bundled | A browser tab, or a desktop app's window |
| `wasm` | A WebAssembly module | A page of a browser space |
| `node` | ES modules | Node: its own process, or embedded in a native app's |
| `hermes` | A Hermes bundle | A phone app, on React Native's engine |
| `cpython` | CPython code objects | CPython: its own process, or embedded in a native app's |

[Hosts](hosts.md) says what each one reaches and refuses (`neojac docs host`).

### Patterns: which modules a space holds

A pattern is a module's dotted name from the archwire's directory (`core.orders` is
`core/orders.jac`) or a package's name followed by `.*`:

| Pattern | Holds |
|---|---|
| `core.orders` | That module |
| `core.*` | Every module below `core/`, at any depth |

A module is in at most one space. When several patterns match it, the most specific wins:

1. The space that names it as its `entry`, or by its exact name.
2. Otherwise the space with the longest `.*` pattern: `core.site.*` over `core.*`.

Two spaces writing the same pattern is E1275.

A module two spaces both hold, the `entry` of each (`space py: cpython { entry main; }` beside
`space js: node { entry main; }`), is, in each one's program, that space's own: compiled for its
host and emitted with the space's other modules. Elsewhere, in a third space's program, it is the
module of the space the rules above pick.

The production also allows a bare `*`. That form is for a layer in `graph layers`; in a space it
names no module.

### Modules no space holds

A module that matches no space's pattern is **unplaced**. It is compiled into every program that
imports it, and a call to it is an ordinary call, never a crossing. This is where shared types and
pure logic go: the `obj` a server function returns and a page reads is declared in an unplaced
module that both wire in.

Because an unplaced module has no space to be served from, a `:pub` or `:prot` function or
walker in one is E1211.

A JavaScript or TypeScript file of the project that no space holds is loaded the same way: into
the space whose module imports it, and run there. What it takes of that space's Jac modules is an
ordinary call, never a crossing, so it makes no endpoint: in a node space whose `main` imports
`kit/echo.js`, which imports `scaled` from the space's `maker.jac`, `neojac run` runs `main` and
exits, and serves nothing.

### A space of a tree

A space may hold a tree of the repository that another tool packs, by its directory, quoted, as
`jac.toml` names it: a Python project (`[pypi."<directory>"]`), held by a `cpython` space, or an
npm tree (`[npm."<directory>"]`), held by a `node` or a `browser` space. A quoted item that is no
tree of `jac.toml` is the module at that path, spelled as a wire spells a module whose file stem
holds a dot (`"frontend/vite.config"`); one that is neither is E2236, a quoted module whose parts
are all identifiers E2310 (write it dotted), and a tree in a space of another host E2237. In a `|`
chain a quoted item is always a module.
[`neojac absorb`](../toolchain/packages.md) writes these spaces, each named for its tree's
package: a node or browser space for an npm tree whenever it writes, and a Python project's
space when `absorb --record` records the project's build:

<!-- example: not checked: an archwire is one file of a project, and this one's project holds a pyproject.toml and two package.json -->
```jac
graph spaces {
    space probe: cpython { "."; }
    space probe_dev: cpython { _buildinfo | scripts.* | tests.*; }
    space store: node { "store"; }
    space frontend: browser { "frontend"; }
}
```

- **A Python project's space holds what its wheel ships**: the files `jac.toml`'s
  `[wheel."<directory>"]` lists, its Jac modules among them, and its extension modules. Its Jac
  modules are the package's: the wheel holds each as Python's own module
  ([Building and testing a Python project](../toolchain/packages.md#building-and-testing-a-python-project)),
  and the `_dev` space imports them as it imports the package's Python modules, in its own
  process, not as calls across spaces.
- **A node space holds what npm ships of its tree**: the package's `files`, its `main` and every
  `exports` target, or the whole tree where it names no `files`. absorb declares one for an npm
  tree that names a `main` or `exports`.
- **A browser space holds the directories of the module scripts its `index.html` loads**, the
  entries its bundler builds. absorb declares one for a tree a bundler builds, with
  `[spaces.<space>.ui] plugin` the `ui` plugin its dependencies name.
- **The rest of a tree is the space's clients**: its tests, its scripts, its configuration. They
  import the space's modules as the space builds them, and hold none of them back. Once a
  Python tree has its space, absorb declares the tree's clients a second `cpython` space,
  `<space>_dev`, by the fewest patterns that hold them, and a later absorb adds to it what came
  since; it imports the first space's modules. A browser tree's files that run in Node and import
  the space's modules (Playwright's tests importing the generated client) are its clients too, the
  `node` space `<space>_dev`, which absorb declares by the fewest patterns that hold them:
  `space frontend_dev: node { frontend.tests.utils.privateApi; }`. A node tree's own tests stay
  the tree's.
- **A Python tree's own files are its tool's to build**: only its Jac modules are the space's
  roots. **A node or browser space of an npm tree takes the tree's JavaScript as its program**:
  each file is emitted as it is, beside its Jac modules, and a module `neojac port` made Jac gets
  a forwarder where its JavaScript stood (`lib/twice.js` requiring `lib/twice.mjs`), so the
  tree's own files and its tests import it as they did
  ([A project's own suites](../toolchain/test.md#a-projects-own-suites)).
- **An npm tree's space is where its imports resolve**: a space that holds one tree needs no
  `[spaces.<space>] npm` row, though the project has several (E1288), and so is its client
  space's: the `_dev` space of a tree takes the tree's npm packages.
- **A space that holds no Jac module is its tree's tools' alone**: a project's `neojac check`
  leaves it out, since its files are another language's (a Python tree's tests before any is
  ported, a TypeScript tree's tests), and checks it once a port makes one of them Jac.

### What a space's program starts from

Every space's program starts from its `entry`, when it has one, and from each module its patterns
name exactly. By host, it also starts from:

| Host | Also a root |
|---|---|
| `native` | Every module its patterns hold, at any depth: each is checked and built, and its module code runs where it is first imported |
| `cpython` | Every module its patterns name, at any depth: Python finds a module by its name as it runs (a test runner's collection, a module imported by a string), so each is emitted, and starts where Python first imports it |
| `node`, `browser` | Every module its patterns hold, at any depth, whether or not anything imports it: a JavaScript tool finds a module by its path (a bundler, a test runner, a page of the project's, [Pages](pages.md)), so each is checked in the space and emitted |
| `wasm` | Nothing more: its module is the first one its patterns name |

Everything those modules import comes with them. So on every host but wasm a module under a
pattern is the space's and is checked there for that host though nothing imports it: a file of
the tree that is no module of the program (an example a site shows as text) belongs under
`[project] exclude` in `jac.toml`. On every host a module that only another target's [`comptime if`
branch](../language/compile-time.md#among-declarations-and-members) imports is not loaded for this
target, though a pattern names it.

A cpython space's directories are its package as Python sees them: each is a path entry of the
space's own finder, which finds the space's modules there and the Python files and extension
modules beside them (a `_native.cpython-*.so` beside the Jac modules of its package), so
`pkgutil.iter_modules` of a package lists both, and a plugin package found by its name is found. A
directory that holds modules and no module of its own name is a namespace package, as Python makes
one.

An `entry` decides what the program does when it starts:

- **A native, node or cpython space with an `entry`** makes its app a program that runs: the
  entry module's `with entry` block is its main code, and the program ends when that code does.
- **An app whose spaces have no `entry`** serves: its program listens for calls of its spaces'
  functions and walkers ([Serving a space](server.md)).
- **A hermes space's `entry`** is the module whose `app` function is the phone app's root
  component.
- **A browser space's `entry`** is optional. It is where the space's style sheets are imported, and
  its `app` function, when it has one, wraps every page ([Pages](pages.md)).

### A space whose entry is in a subdirectory

`entry` takes a dotted name as a pattern does: `entry tool.show;` is `tool/show.jac`. The same
names and `pkg.*` patterns say which modules a layer of `graph layers` holds, and which module a
wire of `graph import` joins. A to-do project with its server in `todos.jac`, its pages under
`pages/`, a command-line client in `tool/show.jac`, and the type `Item` in `model.jac`, which no
space holds:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer shared { model; }
    layer service { todos; }
    layer pages { pages.*; }
    layer tool { tool.*; }
}

graph spaces {
    space api: native { todos; }
    space site: browser { pages.*; }
    space cli: native { entry tool.show; }

    app api { run api; serve site; }
    app cli { run cli; }
}

graph import {
    edge Shared: shared --> service | pages | tool;
    edge Calls: service --> pages | tool;

    model ++> todos | pages.index | tool.show { Item }
    todos ++> pages.index { add_item, list_items, mark_done }
    todos ++> tool.show { list_items }
}
```

The layer `tool` holds every module below `tool/`, and a rule that names it admits wires to any of
them; each wire names the module it feeds, `tool.show`. `neojac build` makes
`dist/cli-<platform>`, which runs `tool/show.jac`'s `with entry` and calls `list_items` on the
server at the URL `[apps.cli.remote]` gives.

### Variants of a module by host

A module may have a file for one host or one `ui` plugin beside its plain file, as it may for an
operating system: `font.hermes.jac` beside `font.jac`, `screen.solid.jac` beside `screen.jac`. A
space's program loads the variant for its `ui` plugin if there is one, else the one for its host,
else the plain file.

## Apps

`app <name> { ... }` declares a program to build. Its body holds:

| Line | Meaning |
|---|---|
| `run <space>, ...;` | The spaces whose code runs in the app's process |
| `serve <space>, ...;` | The `browser` and `wasm` spaces the app hands to browsers |

What an app is follows from the hosts of the spaces it runs:

| The app runs | It builds to |
|---|---|
| Native spaces, with or without served pages | One native program, `dist/<app>-<platform>`, or a directory of that name when it carries pages, CPython or Node |
| Native spaces and one `cpython` and/or one `node` space | The same, with CPython or Node embedded and those spaces run in its process |
| One `node` or one `cpython` space alone | `dist/<app>/`: a launcher, and in `@app/` the space's modules and the interpreter |
| A `browser` space | A desktop app: the space in a window of its own ([Hosts](hosts.md)) |
| One `hermes` space | `dist/<app>/`: the phone app's Hermes bundles |

Rules an app must keep:

| Rule | Code |
|---|---|
| Every space it names is declared | E1273 |
| It serves only `browser` and `wasm` spaces, and runs the others | E1272 |
| An app's name is declared once in its block, and a space's once | E0077 |
| A space that calls another space is only in an app when the space it calls is in one too | E1276 |
| Every space the app reaches and does not run has a URL in `jac.toml` | E1212 |

The last two are about **reach**. An app reaches a space when a module of one of its own spaces is
wired to a module of that space. It need not run every space it reaches: a command-line app calls a
server it does not contain. [Crossings](crossings.md) says how such a call travels and where the
URL is given.

Combinations the build does not make yet are refused with E5090: two `cpython` spaces, or two
`node` spaces, in one native app's process, a `wasm` or `hermes` space in `run` beside native
spaces (a web app lists its `wasm` space under `serve`), and a node space whose npm tree is a
member of a workspace: an artifact does not carry a member's packages yet. So is an app that runs no space: what it
serves needs a program to serve it, so `app web { serve site; }` is refused as
`an app 'web' that serves site and runs no space`.

## Packages

`package <name> { ship <space>; }` declares a library to build: what a space holds, packed as
its host's own kind of package. `neojac build <name>`, or `neojac build` with the apps, writes
it into `dist/`.

A space holds a Python project of the repository by its directory, quoted, as `jac.toml` names
it (`[pypi."<directory>"]`):

<!-- example: not checked: an archwire is one file of a project, and this one's project holds a pyproject.toml -->
```jac
graph spaces {
    space lib: cpython { "."; }

    package spamlib { ship lib; }
}
```

```text
$ neojac build spamlib
dist/spamlib-0.14.0-cp315-cp315-macosx_14_0_arm64.whl
```

- **The space holds what the project's own packaging ships**: the files `jac.toml`'s
  `[wheel."<directory>"]` lists and its extension modules
  ([Building and testing a Python project](../toolchain/packages.md#building-and-testing-a-python-project)).
- **The package is that project's wheel**, named as the project's own build names it: its name
  and version from its metadata, its tags from the interpreter and the system it was built on.
  Its files are written in one order with one date, so the same sources pack the same wheel.
- **`neojac absorb --record` writes both declarations** for a Python project it records, named
  for the project ([Packages](../toolchain/packages.md#recording-a-build)).
- **A package ships one space, of one Python project, today.** A space of Jac modules, a second
  space, and an npm package from a `node` space are refused as not built yet (E5090).
- **A package is in no profile**, and a space it ships is held: `neojac check` does not take it
  for a space no app runs.

| Code | Cause |
|---|---|
| E0168 | Something other than `ship` in a package |
| E2235 | A package ships a space that is not declared |
| E2236 | A space's quoted item is neither a tree of `jac.toml` (`[pypi."<directory>"]`, `[npm."<directory>"]`) nor a module |
| E2237 | A Python project in a space whose host is not `cpython`, or an npm tree in one that is neither `node` nor `browser` |
| E2238 | A package that ships nothing |

## A package's browser spaces

A library's own `archwire.jac` may declare browser spaces: pages the library holds, which every
app whose program loads one of the library's modules builds and serves, with no word of the
app's. stdjac's sign-in pages are such a space, and a library of any project's is written the same
way.

<!-- example: not checked: an archwire is one file of a library, beside its jac.toml -->
```jac
graph layers {
    layer tools { greet; }
    layer pages { look_main | pages.*; }
}

graph spaces {
    space look: browser { entry look_main; pages.*; }
}
```

The library's `jac.toml` says where each is served, with the same keys a project writes
([jac.toml](../reference/jac-toml.md#spacesspace)):

```toml
[project]
name = "pagelib"
kind = "library"

[spaces.look]
base = "/lib/"

[spaces.look.ui]
plugin = "dom"

[spaces.look.headers]
Content-Security-Policy = "default-src 'none'; script-src 'self'; style-src 'self'"
```

- **An app gets the spaces of every library its program loads.** A project whose `api` space
  imports `pagelib.greet` serves `pagelib`'s `look` at `/lib/`, its document answering each of its
  page routes, with the headers the library gave it, as a project's own space is served
  ([Pages](pages.md)). An app with no browser space of its own serves them too.
- **They are built into the depending project, and travel inside its program.** The space is
  compiled to JavaScript under the project's `.jac/build/<app>/@held/<library>.<space>/`, never
  in the library's directory (stdjac is in a read-only install), and its files are compiled into
  the program that loads the library: an app that was one file stays one file
  ([Building an app](building.md#what-the-artifact-holds)).
- **The library names its space's `ui` plugin**, one neojac ships, by `[spaces.<space>.ui]
  plugin`; any other binding in a library's `jac.toml` is still E2221. A library's space has no
  bundler and imports no npm package (E5272): what it imports is its own modules and the runtime.
- **The library's other modules are no space's.** They are loaded by the program that imports
  them, and `:pub` on one of them is E1211 as in any project with spaces.
- **A library declares no app**, and every space it declares is a browser space with a `base`.

| Code | Cause |
|---|---|
| E2340 | A library's archwire declares an app |
| E2341 | A library's space with no `base` in its `jac.toml` |
| E2342 | A library's space served at the base of another served space, or with one under it |
| E2343 | A library's space on a host other than `browser` |
| E2344 | A module of a library's space loaded by another program |

## Profiles

A second `graph spaces` block with a name is a **profile**: another way to group the same spaces
into apps.

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space orders: native { core.orders; }
    space stock: native { core.stock; }

    app shop { run orders, stock; }
}

graph spaces split {
    app front { run orders; }
    app back { run stock; }
}
```

- The unnamed block holds every space and the default apps.
- A profile holds only apps. A space, or anything else, in one is E1271.
- Under a profile, the apps are the default block's with the profile's added, and a profile's app
  replaces the default one of the same name.

```sh
neojac build                      # shop
neojac build --profile split      # shop, front and back
neojac build front --profile split
neojac run back --profile split
```

Under `split`, `orders` and `stock` are in different programs, so the call from one to the other
is a request between them, and `front` needs `stock`'s URL:

```toml
[apps.front.remote]
stock = "http://127.0.0.1:8001"
```

A profile the archwire does not declare is E1274, which lists the ones it has.

One artifact may hold an app as several profiles arrange it, and be whichever its user chooses
where it runs: `profiles` in `jac.toml`'s `[apps.<app>]` lists them, `default` naming the unnamed
block ([Building apps](building.md#several-arrangements-in-one-artifact)).

## What is not in the archwire

What carries a space's work out is not architecture, and no line of the archwire says it: where a
space keeps its graph, what says who a caller is, what carries a call between two spaces. Each is
a [plugin](plugins.md) the project binds in `jac.toml` (`neojac docs plugins`), and changing one
changes no module and no line here.

## A line reserved for what is not built yet

| Line | Would choose | Code |
|---|---|---|
| `<space> has fs.read, net;` in an app | What an embedded wasm space may use | E1263 |

## What goes wrong

| Code | Cause |
|---|---|
| E0115 | Something other than a space, an app or a package in the block |
| E0116 | Something other than `entry`, patterns or a quoted item in a space |
| E0117 | Something other than `run`, `serve` or `<space> has` in an app |
| E2093 | The archwire has a syntax error; reported with the error itself |
| E1226 | A host that is not one of the six |
| E1270 | A second `entry` in a space |
| E1271 | A space or a package in a profile |
| E1272 | An app serving a space that is not `browser` or `wasm` |
| E1273 | An app naming a space that is not declared |
| E1274 | `--profile` naming a profile that is not declared |
| E1275 | The same pattern in two spaces |
| E2098 | A space's pattern or its `entry` naming no module of the project |
| E1276 | A space in an app calls a space that no app of that grouping runs or serves |
| E0077 | A space, an app or a package declared twice |

`neojac docs E1276` prints any of them with its message.
