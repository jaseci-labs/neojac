---
description: Which UI library a browser or hermes space's components become, and what bundles the space - the ui and bundler abstractions, the react, preact, solid, dom, react_native and none plugins, the vite and expo plugins, naming a space's plugins in jac.toml, and a project's own ui plugin or bundler.
keywords: ui plugin, UI plugin, dom, bundler plugin, spaces.ui, spaces.base, spaces.bundler, bundler, @jac/vite, vite, expo, react, preact, solid, react_native, rerender, fine-grained
---
# UI plugins and bundlers

The compiler knows what a component means ([Components and JSX](components.md)) and no UI
library. Two of the language's abstractions say the rest for a JavaScript space, and each is
carried out by a [plugin](plugins.md):

- **`ui`** is what the space's components are written against. A `ui` plugin is data that says
  which library's functions the language's state, derived values and effects become.
- **`bundler`** is the program that turns the space's compiled JavaScript into what the app serves
  or ships.

Both are picked as the space is built, in `jac.toml`: a space is built with one plugin of each,
and nothing where the program runs chooses another.

## The `ui` plugins neojac ships

| Plugin | Library | Model | JSX | Hosts | Packages it owns | Its bundler |
|---|---|---|---|---|---|---|
| `react` | React, React Router | rerender | calls of `react/jsx-runtime` | browser, node | `react`, `react-dom`, `react-router-dom` | `vite` |
| `preact` | Preact | rerender | calls of `preact/jsx-runtime` | browser | `preact` | `vite` |
| `solid` | Solid | fine-grained | JSX text, for Solid's compiler | browser | `solid-js` | `vite` |
| `react_native` | React Native | rerender | calls of `react/jsx-runtime` | hermes | `react`, `react-native` | `expo` |
| `dom` | none: neojac's own runtime | fine-grained | the DOM's own calls, against its runtime | browser | | none |
| `none` | none | none | refused (E5178) | browser, hermes, node | | |

The standard plugin, which a space has when `jac.toml` names none, is its host's:

| Host | Standard `ui` plugin |
|---|---|
| `browser` | `react` |
| `hermes` | `react_native` |
| `node` | `none` |

`native`, `wasm` and `cpython` spaces have no `ui` plugin and hold no components.

### What each model does with a component

| Language | `rerender` (React, Preact, React Native) | `fine-grained` (Solid, `dom`) |
|---|---|---|
| A component's body | Runs each time the component is shown again | Runs once; what reads state updates itself |
| `has x: T = v;` | The library's state function (`useState`) | Its signal (`createSignal`) |
| `has r: Ref[T] = Ref(v);` | Its ref function (`useRef`) | A plain value |
| State read in a function made in the component | The state as last shown, kept in a ref (`useRef`) that each run fills | The signal, read where it is used |
| A derived local | Computed again each time | A memo (`createMemo`) |
| `can with [a] entry` | Its effect function, with `[a]` as its dependencies | An effect that reads exactly `a` (`createEffect` and `untrack`) |
| `can with exit` | The effect's cleanup | `onCleanup` |
| A list comprehension of elements | An array | A keyed list (`<For each=...>`) |
| An element's `key` | Given to the library, which keeps each row by it | Left out: the keyed list keeps each row by its item, and the element gets no `key` attribute |
| An element written as a statement in a `{ ... }` block, outside its loops | Keyed by its place among the block's elements (`key="$0"`, `"$1"`, ...), so the element of an `if` is the same element whenever it is there; a `key` the program wrote is kept, and an element a loop makes takes its key from the program | An item of the block's list, with no key |

Under `dom` the functions in the right-hand column are its runtime's own: `signal`, `computed`,
`effect`, `cleanup`, `untrack` and `each`.

What the language refuses so that both models give the same result is on
[Components and JSX](components.md#rules-a-ui-plugin-adds).

### File routes: React and dom

The routes of `pages/` ([Pages](pages.md)) need a `ui` plugin that knows how to start a routed
app, which `react` and `dom` do. A space under Preact or Solid has no pages, and one that holds a
module below `pages/` is refused (E1279, at the space's declaration); its `entry` module renders
into the page itself, with the library's own function:

<!-- example: not checked: an entry is a module of a browser space, with JSX and an npm import -->
```jac
import from "solid-js/web" { render }

def Counter(step: int = 1) -> JsxElement {
    has count: int = 0;

    doubled = count * 2;

    return <button onClick={lambda { count = count + step; }}>{count} {doubled}</button>;
}

with entry {
    render(lambda -> any { return <Counter step={2} />; }, document.getElementById("root"));
}
```

Under Preact the last line is `render(<Counter step={2} />, document.getElementById("root"));`, with
`render` imported from `"preact"`. Under `dom` a space with no pages starts the same way, with
`mount` from `"@jac/runtime"`: `mount(lambda -> any { return <Counter step={2} />; },
document.getElementById("root"));`.

### dom

`dom` is a `ui` plugin with no library: the compiler makes each element with the DOM's own calls,
against neojac's runtime (`abstractions/ui/dom/runtime.js`). Its state is fine-grained, as Solid's
is: a component runs once, and only what reads state follows it. It needs no npm package and no
bundler, so a `dom` space is served as the compiler writes it
([Pages](pages.md#a-space-with-no-bundler)), and its pages run under a Content-Security-Policy of
`script-src 'self'; style-src 'self'`: it evaluates no string and writes no `style` attribute.

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Counter(step: int = 1) -> JsxElement {
    has count: int = 0;

    doubled = count * 2;

    return <p class={"odd" if count % 2 else "even"}>
        <button onClick={lambda { count = count + step; }}>add</button>
        {count} doubled {doubled}
        <input spellcheck="false" disabled={count > 9} />
    </p>;
}
```

- **Static JSX is plain DOM.** An element is made once, with `document.createElement` (and in its
  namespace for SVG and MathML: `<svg>` and what is inside it, and a tag only SVG has, such as
  `<circle>`). A child, an attribute, a spread or a component's prop is kept current only when its
  own code reads state, a derived value, a hook's result or a prop: `{count}` and `class={...}`
  above, not the button's `onClick`, whose value is a function.
- **Attribute names are HTML's**: `class`, `for`, `aria-label`, `data-id`, `spellcheck`. React's
  `className` and `htmlFor` on an element, and its `onDoubleClick`, are refused (E5273): the first
  two would set attributes no browser reads, and the third would listen for an event no browser
  sends. HTML's are `class`, `for` and `onDblClick`.
- **`True` writes the attribute bare, and `False` and `None` remove it.** An enumerated attribute
  whose value is the word `false` is written as a string: `spellcheck="false"`,
  `contenteditable="false"`, not `spellcheck={False}`, which removes it.
- **`value`, `checked` and `selected` are set as properties**, so a field shows what the program
  says; a `<select>`'s `value` is set after its options.
- **`on` and a capital letter is a listener** for the rest in lower case: `onClick` is `click`,
  `onKeyDown` `keydown`. It is removed with the element's part of the page.
- **`style`** is a string, the element's whole declaration, or a dict of CSS properties by their
  CSS names (`{"font-size": "12px"}`); either is set through the CSSOM, never as an attribute.
- **`ref={r}`** sets `r.current` to the element as it is made.
- **A list comprehension of elements** (`[<li>{x}</li> for x in items]`) is a keyed list: each row
  is kept with its item, moved where the item moves, and disposed when it leaves. A `key` is not
  needed and not given to the element.
- **A component** runs once; a prop that reads state is read where the component reads it, and
  `children` is made where it is shown. A `**rest` parameter follows its props.
- **`@jac/runtime`** has, beside the session functions every plugin's has, `Link`, `navigate`,
  `Navigate`, `Outlet` and `unsafe_html` ([Pages](pages.md#jacruntime)), and `mount(fn, element)`,
  which shows what `fn` makes in `element` in place of what it held and gives a function that
  removes it.

### none

`none` means no UI and no JSX. Under `none`, `has` and effects in a function are E1218, JSX is
E5178, and a library's functions are ordinary imports. A JSX library that no shipped `ui` plugin owns is used through a plugin of
the project's own ([below](#a-projects-own-ui-plugin)) whose `[ui.jsx]` says `form = "calls"` and
the package whose `jsx-runtime` makes its elements, or `form = "text"` to leave the JSX to the
library's own compiler, with no change to the compiler.

## Choosing a space's plugins

A space's plugins are named in `jac.toml`, each in a table of its abstraction under the space's
own:

```toml
[spaces.demo_solid]
base = "/demos/solid/"

[spaces.demo_solid.ui]
plugin = "solid"

[spaces.demo_solid.bundler.vite]
config = "demos/solid.vite.config.ts"
```

| Key | Default | Meaning |
|---|---|---|
| `[spaces.<space>.ui]` `plugin` | The host's standard `ui` plugin | The `ui` plugin the space's components are compiled for: one neojac ships, or one `[packages]` declares |
| `[spaces.<space>.bundler]` `plugin` | The bundler the space's `ui` plugin names | The `bundler` plugin that bundles the space: one neojac ships (`vite`, `expo`), or one `[packages]` declares |
| `[spaces.<space>.bundler.<plugin>]` | none | The settings of the space's bundler, under its name. `vite` has one, `config`: its configuration file, from the project's root, which Vite takes as `--config` |
| `[spaces.<space>]` `base` | `/` | The URL path the app serves the space's bundle at; also the base the bundler writes its URLs for, and the path its pages' routes are under ([Pages](pages.md#routes)) |

- **`[ui]` and `[bundler]`, with no space named, are every JavaScript space's** that has no table
  of its own: `[ui]` `plugin = "preact"` for a project whose browser spaces are all Preact's.
- **A space is built with one plugin of each.** A table of another plugin there
  (`[spaces.site.ui.solid]` in a space built with `preact`) is E5158. Nothing where the program
  runs picks another: there is no `JAC_UI`, as there is a `JAC_STORE`
  ([Plugins](plugins.md#picking-a-plugin-where-the-program-runs)).
- **A project with several browser spaces** gives each its own `base` and its own bundler
  configuration, so that each has its own bundle, at its own path: jaclang.org serves its React
  site at `/` and a Preact and a Solid space at `/demos/preact/` and `/demos/solid/`.

### What is checked

| Mistake | Code |
|---|---|
| `plugin` names a plugin that neojac does not ship and `[packages]` does not declare | E2214, at its line of `jac.toml` |
| `plugin` names a plugin that fills another abstraction (`vite` under `ui`) | E2215 |
| The `ui` plugin does not run on the space's host (`react_native` for a browser space) | E1214 |
| A table of a plugin the space is not built with, or a setting its bundler does not have | E5158 |
| A module imports a package another `ui` plugin owns (`solid-js` in a React space) | E1219 |
| The space holds a page, and its `ui` plugin has no file routes (`pages.*` in a Solid space) | E1279 |
| A space with no bundler imports an npm package | E5272 |

A package owned by a `ui` plugin is that plugin's alone, under `none` too: `react` in a `none`
space is E1219.

**The forms `jac.toml` had before are refused, never ignored.** `ui` and `bundler` written as
strings under `[spaces.<space>]`, and `bundler_config`, are each E5158 at their line:

```text
jac.toml:5:1: error[E5158]: jac.toml's [spaces.site] ui is not a value: `[spaces.site.ui]` is a table that names a plugin for `ui`, `plugin = "<name>"`
jac.toml:5:1: error[E5158]: jac.toml's [spaces.site] bundler_config is not a key of a space: a bundler's configuration is a setting of its plugin, `[spaces.site.bundler.<plugin>] config`
```

## A project's own `ui` plugin

A `ui` plugin is a package ([Plugins](plugins.md#writing-a-plugin)): a directory with a `jac.toml`
that says it fills `ui`, and a `[ui]` table saying how. It has no class, since nothing of it runs
with the program. The project declares it by its path and names it for a space:

```toml
[packages]
mylib = { path = "ui/mylib" }

[spaces.site.ui]
plugin = "mylib"
```

`ui/mylib/jac.toml` has the keys the shipped plugins' have (neojac's
`abstractions/ui/solid/jac.toml` is this one, under the name `solid`). The table is `ui`'s
contract, which `abstractions/ui/jac.toml` states:

```toml
[project]
name = "mylib"                 # the plugin's name, which E1219 compares
kind = "plugin"

[plugin]
fills = "ui"
interface_ver = 1              # the version of `ui`'s interface this plugin was written for

[ui]
model = "fine-grained"         # rerender, fine-grained or none
hosts = ["browser"]
owns = ["solid-js"]            # packages only this plugin's spaces may import
bundler = "vite"               # the bundler of a space that names none

[ui.jsx]
form = "text"                  # what the compiler makes of JSX: calls, dom or text
lowercase_tags = true          # whether <div> exists (E1221 when not)
no_text_in = []                # tags that show no bare text (E1220)
keys = false                   # whether the library reads an element's `key`; default: true

[ui.state]                     # has
from = "solid-js"
name = "createSignal"
shape = "pair"                 # pair: it returns the value and its setter; object: one object

[ui.computed]                  # a derived value, fine-grained only
from = "solid-js"
name = "createMemo"

[ui.effect]                    # can with ... entry
from = "solid-js"
name = "createEffect"

[ui.cleanup]                   # can with ... exit, fine-grained only
from = "solid-js"
name = "onCleanup"

[ui.untrack]                   # what an effect reads without depending on it
from = "solid-js"
name = "untrack"

[ui.each]                      # a keyed list, fine-grained only
from = "solid-js"
tag = "For"
prop = "each"
```

`[ui.jsx]` `form` says what the compiler makes of JSX. A plugin with no `[ui.jsx]` table refuses
JSX on every host (E5178):

| `form` | The compiler makes | Shipped plugins |
|---|---|---|
| `calls` | Calls of `jsx`, `jsxs` and `Fragment` of `<source>/jsx-runtime`, the automatic runtime React and Preact share; `source` names the package (`source = "react"`) | `react`, `preact`, `react_native` |
| `dom` | The DOM's own calls, against the plugin's `runtime` | `dom` |
| `text` | JSX, written to a `.jsx` file for the library's own JSX compiler, which the space's bundler runs | `solid` |

A `form` other than these, `calls` with no `source`, and `dom` with no `[ui] runtime` are each
E5158, at the plugin's `form`. `[ui.each]` names a component (`tag`, `prop`) under `form =
"text"`, and a function (`name`) under `form = "dom"`.

The compiler writes the calls itself, on every host, so a node space needs no bundler for its JSX.
`react` runs on a node space so: a node space whose `[spaces.<space>.ui] plugin` is `react` makes
React's elements, which `react-dom/server` renders as React does, its components and hooks React's
own.

A rerender plugin names `[ui.ref]` (`useRef`) where a fine-grained one names `[ui.computed]`,
`[ui.cleanup]`, `[ui.untrack]` and `[ui.each]`. Two more keys of `[ui]` are for a plugin that
brings its own half of `@jac/runtime`, as `react` does for its routes and `react_native` for the
form a caller signs in by:

| Key | Meaning |
|---|---|
| `runtime` | A JavaScript file in the plugin's directory (`runtime.js`), which is what `@jac/runtime` is in its spaces. Where a program runs it is laid beside stdjac's own files, so it imports them as its neighbors (`export * from "./session.js";`). Without it, `@jac/runtime` is stdjac's `session.js` |
| `boot` | The module whose `startApp` starts a routed app (`"@jac/runtime"`): what gives a space file routes |

A plugin whose host has no page to draw on shows the sign-in form itself: its runtime calls
`__showSignIn(show)` of `session.js`, and `show(asks, answer, forgot)` is then given what the
app's auth asks for (its fields, its ways of signing in, and `forgot`, the field a password's link
is asked for by), `answer(action, given)`, which tries one way and gives `{ok: true}` or
`{ok: false, detail}`, and `forgot(name)`, which asks for a link that sets a new password and gives
`{ok, detail}`, what to tell the caller. It gives a promise of whether the caller signed in, or
`null` to leave the form to the page. `abstractions/ui/react_native/runtime.js` is one.

A plugin's `jac.toml` with no `[ui]` table, or one that is not at the path `[packages]` gives, is
E2216.

## Bundlers

A bundler runs on neojac's own Node, given a job file that says what to bundle and where to write
it. The ones neojac ships are the `bundler` plugins `vite` and `expo`:

| Plugin | For | Does |
|---|---|---|
| `vite` | Browser spaces | Runs the project's own Vite (its npm tree's `node_modules/vite`), with the project's config, in the tree's directory |
| `expo` | Hermes spaces | Runs the project's Expo to export the app's bundles for Android and iOS |

The bundlers' packages are the project's, those of the space's npm tree in `jac.toml`, installed
with `neojac install`, and they are what the space is checked against. neojac pins none of them.

### Vite

`vite.config.ts` is the project's, in the tree's directory (`eco/web/vite.config.ts`), and adds
`@jac/vite` before the library's own Vite plugin. A configuration elsewhere, or one for each of
several spaces, is the `vite` plugin's `config` setting
([above](#choosing-a-spaces-plugins)).

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import jac from "@jac/vite";

export default defineConfig({
    plugins: [jac(), react()],
});
```

The library's Vite plugin is `@vitejs/plugin-react` for React, `@preact/preset-vite` for Preact and
`vite-plugin-solid` for Solid, each among the tree's `devDependencies`.

`@jac/vite` is neojac's half. The build writes it into the tree's `node_modules/@jac/vite`
each time it bundles, so it is never among the tree's packages. It:

- gives Vite the space's compiled modules, and answers the shell's `/@jac/entry` with the space's
  entry ([Pages](pages.md#the-html-shell));
- sets Vite's `base` from the space's `base`, and its output directory to the build's own;
- makes the job's public directory Vite's, so the wasm module of a space the pages call is served
  as `static/<space>.wasm`;
- takes one option, `jac({ assets: "public/img" })`, a directory of the project that the bundle
  serves as `static/assets/`;
- records what Vite read, so a build with nothing changed does not bundle again
  ([Building apps](building.md));
- resolves a project file's import of one of the space's Jac modules: a `.ts` or `.js` file of
  the project that writes `import { tone } from "../tone.js";`, where `tone.jac` is a module of
  the space, is given the module's forwarder in the compiled space, which `@jac/bundle.json`'s
  `jac_modules` names (`{"tone.js": "tone.js"}`: the place in the project, the forwarder in the
  space), with or without its `.js` ([A project's own JavaScript](../interop/npm.md#a-projects-own-javascript)).

A Vite configuration may set its own `root` when the space's `index.html` is not at the top of
the tree's directory: `defineConfig({ root: "demos", plugins: [jac(), preact()] })`, for
`eco/web/demos/index.html`. A file of the project outside the tree is imported by its path from
the module that imports it (`import "./core/site.css";` in a Jac module), or by `$src/`, the
project's root.

### Expo

A hermes space's packages are its npm tree's (`[spaces.<space>] npm` in `jac.toml`), with `expo`,
`react` and `react-native` among them, installed with `neojac install`. The build stops with a
message when the space has no tree or its packages are not installed.

The entry module's `app` function is the phone app's root component. The bundler writes the
Expo project around it in the space's work directory (`<the tree's directory>/.jac/build/<app>/<space>/`) and runs
`expo export` for Android and iOS into `dist/<app>/`. The URLs of the spaces the app calls are
written into the bundle from `[apps.<app>.remote]`. See [Hosts](hosts.md).

**The app an Android phone installs** is built too, where the Android SDK is at hand:
`dist/<app>/<app>.apk`, the native project Expo writes for the app (`expo prebuild`, in the work
directory's `android/`) built by Gradle with the bundle inside, so it needs no development
server, and signed with the project's development key.

- **The SDK** is the one `ANDROID_HOME` names, or the one neojac fetched: `neojac install`
  fetches it into neojac's cache once `jac.toml` accepts its licenses, and the build fetches the
  platform, build tools and NDK the app asks for. It is built with a JDK: the one `JAVA_HOME`
  names, or the one `neojac install` fetches with the SDK (Eclipse Temurin 21). Both are pinned
  releases, checked against their digests. With no SDK the build makes the bundles alone, and
  says how to get the rest. Google publishes the SDK for Linux on x86_64 and for macOS.

  ```toml
  [android]
  licenses = "accepted"   # https://developer.android.com/studio/terms
  emulator = true         # also fetch an emulator, for `neojac run`

  [apps.mobile]
  name = "diffwalker"                    # under its icon
  identifier = "dev.diffwalker.mobile"   # what Android installs it as
  ```

- **`neojac run <app>`** installs the app on the Android phone or emulator that is connected
  (starting the emulator neojac fetched when none is), and starts it. A space the app reaches at
  `http://127.0.0.1:<port>` is this machine's port from the phone too (`adb reverse`), so the app
  and a server run with `neojac run` on the same machine find each other.
- **Plain HTTP is allowed to an app whose remotes use it** (`http://...`): Android refuses
  cleartext to an installed app otherwise. A deployed app's remotes are `https://`, and it is not.
- **The first build takes minutes**: Gradle fetches itself, the NDK and React Native's Android
  libraries, and compiles the native side. Later builds reuse them, and a build with nothing
  changed runs nothing. Gradle is run without its daemon, so no build leaves a process behind.
- **An `.ipa`** needs macOS and Xcode: run `expo run:ios` in the work directory.

### A project's own bundler

A project's own bundler is a `bundler` plugin in its tree: a directory with a `jac.toml` and the
script it names.

```toml
# tools/bundle/jac.toml
[project]
name = "bundle"
kind = "plugin"

[plugin]
fills = "bundler"
interface_ver = 1

[bundler]
build = "bundle.mjs"           # the script that bundles a space
serve = "bundle.serve.mjs"     # the one that serves it under `neojac dev`; may be left out
settings = ["minify"]          # the settings a project may give it
```

```toml
# the project's jac.toml
[packages]
bundle = { path = "tools/bundle" }

[spaces.site.bundler]
plugin = "bundle"

[spaces.site.bundler.bundle]
minify = true
```

The build runs `build` as `neojac node tools/bundle/bundle.mjs <job>`. The job is a JSON file:

| Field | Is |
|---|---|
| `name` | The space's name, or the app's when the app serves nothing |
| `top` | The project's root |
| `tree` | The directory of the space's npm tree (`eco/web`), where its packages are installed and a bundler runs; `""` when the project has none |
| `work` | The space's work directory |
| `src` | The space's compiled modules, with `@jac/bundle.json` (its entry, the aliases of its imports, the spaces it reaches, and `jac_modules`, the forwarder of each Jac module a project file imports, by the place it stands at) |
| `dist` | Where to write the bundle |
| `public` | Files to serve beside it (the space's wasm modules) |
| `base` | The space's `base` |
| `bundler` | The plugin's name |
| `settings` | The settings `jac.toml` gives the plugin for this space, as written: `{ "minify": true }` |
| `config` | The setting `config`, as a full path from the project's root, or `""` |
| `entry` | The entry module's path from the project's root, without `.jac` |
| `remotes` | Where each space it calls is, from `[apps.<app>.remote]` |

A bundler that exits with a status other than 0 fails the build. One that writes
`bundle-read.json` in `work` is run again only when what it read changes; one that does not is
run on every build ([Building apps](building.md)).

A setting that is not among the plugin's `settings` is E5158, at its line of `jac.toml`.

A bundler can also serve its space while the app is worked on
([`neojac dev`](building.md#working-on-an-app)), with the script its `serve` names.
`neojac dev` starts it once, as `neojac node tools/bundle/bundle.serve.mjs <job>`, and stops it
with SIGTERM. Its job is the bundler's,
with three more fields:

| Field | Is |
|---|---|
| `mode` | `"serve"` |
| `listen` | The address to serve the page at |
| `app` | The URL of the app's program, to pass on what is not the page's; `""` when the app has no program |

It serves the compiled modules in `src`, which neojac writes again as their sources change. A
bundler with no `serve` bundles under `neojac dev` as it does in a build.

## What is rejected

| Code | Cause |
|---|---|
| E2214 | No plugin of that name, shipped or declared in `[packages]` |
| E2215 | A plugin named for an abstraction it does not fill |
| E2216 | A plugin's package that is not where `[packages]` says, or says nothing of how it fills `ui` or `bundler` |
| E5158 | `ui`, `bundler` or `bundler_config` in a form `jac.toml` no longer has; a table of a plugin the space is not built with; a setting its bundler does not have |
| E1214 | A `ui` plugin that does not support the space's host |
| E1218 | `has` or an effect under `none` |
| E1219 | A package another `ui` plugin owns |
| E1220, E1221 | Text or a lowercase tag that React Native does not show |
| E1222, E1223, E1224 | Code whose meaning would depend on the model, under a fine-grained `ui` plugin |
| E1279 | A page in a space whose `ui` plugin has no file routes |
| E5273 | React's `className`, `htmlFor` or `onDoubleClick` on an element under `dom` |
