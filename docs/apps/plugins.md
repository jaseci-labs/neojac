---
description: Plugins, the mechanisms behind the language's abstractions - the abstractions that take one and where each declares itself, the place a program is built for and the plugins it provides, binding a plugin in jac.toml, the plugins neojac ships, listing several and picking one where the program runs, the two that are picked as a space is built, an abstraction's settings and a plugin's, and secrets, a project's own plugin by its path, writing one against its abstraction's contract, what a plugin imports and what its host gives it, and what is refused.
keywords: binding a plugin, standard plugin, kind = "place", [provides], --place, contract, store.contract, common.contract, Host, store, sqlite, Store, Secret, settle, an abstraction's settings, AuthSettings, give_settings, sqlfile, open_db, accountbook, AccountsAuth, Book, JAC_STORE, auth plugin, transport, http plugin, process_jobs, loop_schedule, memory_limits, files plugin, mail plugin, smtp
---
# Plugins

A plugin is what carries out one of the language's abstractions: where `root` is kept, who a
caller is, what answers `by llm()`, which library a component becomes. A program's modules name
the abstraction and never the plugin ([Principles](../language/principles.md)). Three files say
which plugin carries out each:

| Who | Writes | Says |
|---|---|---|
| An app's author | the project's `jac.toml` | what the app needs: the abstraction's settings, and a plugin only where the app must have that one |
| A plugin's author | the plugin's `jac.toml` | which abstraction it fills, and its own settings |
| Whoever runs a place | the place's `jac.toml` | which plugin provides each abstraction there |

A project that names no plugin runs on a developer's machine with nothing set up, where each
abstraction has its **standard plugin**, which neojac ships; and the same project, unchanged, is
built for another place, whose plugins are its own ([The place a program is built
for](#the-place-a-program-is-built-for)). For most abstractions, the machine a program runs on
may then pick among the plugins the program was built with.

## The abstractions

| Abstraction | What source says | Its interface | One for each | Picked | Standard plugin |
|---|---|---|---|---|---|
| `store` | `root`, `root.shared`, `++>` | `store.contract.Store` | Space | As the program starts | `sqlite` |
| `auth` | `:prot`, the caller's `root`, a page's `sign_in()` | `auth.contract.Auth` | Project | As the program starts | `accounts` |
| `transport` | A call from outside, and a call to another app | `transport.contract.Transport` | Project | As the program starts | `http` |
| `llm` | `by llm()` | `llm.contract.Model` | Project | As the program starts | `anthropic` |
| `jobs` | `@job`, `flow f(x)`, `wait j` | `jobs.contract.Jobs` | Project | As the program starts | `process_jobs` |
| `schedule` | `@schedule` | `schedule.contract.Scheduler` | Project | As the program starts | `loop_schedule` |
| `limits` | `@limit`, `consume_limit` | `limits.contract.Limits` | Project | As the program starts | `memory_limits` |
| `files` | `File`, `@accepts` | `files.contract.Files` | Project | As the program starts | `local_files` |
| `mail` | Nothing: the `auth` plugin mails its links through it | `mail.contract.Mailer` | Project | As the program starts | `smtp` |
| `ui` | A component: `has` in a function, `can with entry`, JSX | A `[ui]` table of the plugin's `jac.toml` | Space | As the space is built | Its host's: `react` in a browser, `react_native` on hermes, `none` on node |
| `bundler` | Nothing: a JavaScript space is bundled as it is built | A `[bundler]` table of the plugin's `jac.toml` | Space | As the space is built | The one the space's `ui` plugin names: `vite`, `expo` |

The abstractions are the language's: a project chooses a plugin for one, and does not declare
one (E2217).

**Each abstraction declares itself,** in a directory of its own in neojac's `abstractions/`, which a
release carries with `rt/`:

```text
abstractions/
  store/
    jac.toml        the abstraction: its interface, its settings, its version, its standard plugin
    contract.jac    the contract: `Store`, and the types that cross it
    sqlite/         the standard plugin
  auth/  transport/  llm/  jobs/  schedule/  limits/  files/  mail/     each the same
  ui/               jac.toml, and react/ preact/ solid/ react_native/ none/
  bundler/          jac.toml, and vite/ expo/
  common/           contract.jac: what every plugin may use, whatever it fills
```

```toml
[project]
name = "store"
kind = "abstraction"

[abstraction]
interface = "store.contract.Store"
interface_ver = 1
per = "space"
picked = "start"
standard = "sqlite"
```

- **`interface`** is the class a plugin implements, in the abstraction's own contract:
  `<abstraction>.contract.<Interface>`. `ui` and `bundler` have none: their contract is a table of
  the plugin's `jac.toml`, which their own `jac.toml` describes.
- **`settings`**, where an abstraction has settings of its own, is the class that holds them, in
  its contract too: `auth`'s is `auth.contract.AuthSettings` ([Settings](#settings)). The others
  have none.
- **`interface_ver`** is the interface's version (below).
- **`per`** is what has one plugin of it, `"project"` or `"space"`, and **`picked`** when that
  plugin is chosen, `"start"` or `"build"`.
- **`standard`** is the plugin a project has until it names another, in the abstraction's own
  directory. `ui` names one for each host (`[abstraction.standard]`), and `bundler` none: a
  space's is the one its `ui` plugin names.

**The contract is what a plugin and the program meet at.** `store.contract` holds `Store` and
every type that crosses it (`Row`, `Writing`, `StoreConflict`). A plugin imports it, the program
above the plugin imports it, and it imports nothing of either
([What a plugin imports](#what-a-plugin-imports)).

**Each interface has a version,** a number that goes up when the interface changes so that a
plugin written for it would not survive. Every interface is at 1 in this neojac but
`transport`'s, `files`' and `schedule`'s, which are at 2, and `auth`'s, which is at 4: since its
version 4 an `auth` plugin's class derives from `AuthSettings`, and since its version 2 a
`schedule` plugin runs a `Scheduled` whose `at` is not empty at the minutes it names. A plugin says
the version it was written for (`interface_ver`, [below](#writing-a-plugin)), and one written for
another is refused before anything is asked of it (E2230): the message is that the interface
moved on, and not that some method of the plugin's class is missing.

**Nine are picked as a program starts, and two as a space is built.** A plugin of the first nine
is a class that runs with the program, so a program may hold several and start with one. `ui` and
`bundler` decide what the compiler and the build make of a JavaScript space, so a space is built
with one of each, and they have a page of their own:
[UI plugins and bundlers](ui-bindings.md) (`neojac docs apps/ui-bindings`).

## The place a program is built for

A program is built for a place, which provides a plugin for each abstraction the project leaves
open. With no `--place`, the place is this machine: each abstraction's standard plugin, `sqlite`
for `store` and the rest ([The standard plugins](#the-standard-plugins)). Another place is a
directory whose `jac.toml` says that it is one:

```toml
[project]
name = "cloud"
kind = "place"

[packages]
cloud_store = { path = "../plugins/cloud_store" }
cloud_accounts = { path = "../plugins/cloud_accounts" }

[provides]
store = "cloud_store"
auth = "cloud_accounts"
transport = "http"
llm = "anthropic"
jobs = "process_jobs"
schedule = "loop_schedule"
limits = "memory_limits"
files = "local_files"
mail = "smtp"

[store.cloud_store]
schema = "apps"
```

```sh
neojac dev web                        # this machine: sqlite, accounts, local_files, ...
neojac build web --place ../cloud     # cloud_store, cloud_accounts, and neojac's for the rest
```

- **A place is named by its directory,** and `--place <directory>` is an option of every command
  that builds or loads a program: `build`, `run`, `dev`, `check`, `test`, and `emit-js` and
  `emit-py` with `--app`. A directory whose `jac.toml` does not say `kind = "place"`, or has no
  `[provides]`, is no place (E2239).
- **`[provides]` names the plugin of each abstraction there,** one picked as a program starts.
  `ui` and `bundler` are picked as a space is built, by the project, and a place names neither
  (E5158). A name that is no plugin is E2214, and a plugin of another abstraction E2215, at its
  line.
- **`[packages]` declares the place's plugins** as a project declares its own; a plugin neojac
  ships needs no line. A plugin the place declares and `[provides]` does not name is E2227.
- **A place gives the settings of the plugins it provides,** in `[<abstraction>.<plugin>]`
  (`schema` above). An abstraction's own settings are the project's, and where a service is (a
  database's address, a bucket) is the environment's, where the program runs. A place holds no
  other table of an abstraction (E5158).
- **The project's choice holds wherever it is built.** An abstraction the project names a plugin
  for (`[store] plugin = "sqlite"`) has that plugin for every place: a place provides only what a
  project leaves open. A plugin the project lists (`[store.jsonstore]`) is built in beside the
  place's, and the project's table of the place's own plugin gives settings over the place's.
- **The plugin the place provides is the one built in** for an abstraction the project leaves
  open: a program built for `cloud` holds no `sqlite`, and `JAC_STORE` picks only among the
  plugins it holds ([below](#picking-a-plugin-where-the-program-runs)).
- **An abstraction the program uses that its place does not provide,** and its project leaves
  open, is E2242, at the place's `[provides]`.
- **The build cache tells places apart:** what a program built for one place is made of is not
  taken for the same program built for another, and building for each in turn builds each.

Nothing in the project changes from one place to another: no module, no line of `archwire.jac`,
no line of `jac.toml`.

## Binding a plugin

A project names a plugin itself where the app must have that one, wherever it is built; and lists
the plugins a program holds to be picked among where it runs.

```toml
[packages]
jsonstore = { path = "../jsonstore" }

[store]
plugin = "sqlite"

[store.jsonstore]
file = "notes.json"
indent = 2

[auth]
registration = false
```

- **`[packages]` declares the plugins that are not neojac's own,** beside the project's
  libraries and as they are declared, each by its version (`postgres = "0.4"`, an
  [installed package](../toolchain/packages.md#installed-packages)) or by where its package is: a
  directory, or a repository at a revision (`{ git = "...", rev = "..." }`), which
  `neojac install` fetches and `jac.lock` pins
  ([Packages](../toolchain/packages.md#fetching-and-pinning)). The plugin's own `jac.toml`
  says that it is one. A standard plugin needs no line there.
- **A plugin the project declares is one it uses:** `plugin` names it or a table lists it, for
  the project or for a space. One that is declared and never used is E2227.
- **`[<abstraction>] plugin`** names the plugin a program uses, whatever place it is built for.
- **Each `[<abstraction>.<plugin>]` table lists a plugin.** Every listed plugin is compiled into
  the program, and the table holds its settings. The plugin `plugin` names needs a table only when
  it has settings.
- **Every other key of `[<abstraction>]` is a setting of the abstraction,** which whichever plugin
  the program runs with is given ([Settings](#settings)): `registration` above.
- **`[spaces.<space>.<abstraction>]`** binds one space's, for an abstraction a space has one of.
  The spaces one program runs share one `store`, so they are bound alike (E5090 otherwise).
- **`ui` and `bundler` have one plugin for a space,** the one `plugin` names, and only its table:
  `[spaces.site.ui]` `plugin = "preact"`, and `[spaces.site.bundler.vite]` for the bundler's
  settings. Listing another there is E5158
  ([UI plugins and bundlers](ui-bindings.md#choosing-a-spaces-plugins)).

Nothing else changes: no module, and no line of `archwire.jac`.

## Picking a plugin where the program runs

For an abstraction picked as a program starts (every one but `ui` and `bundler`), one program
holds every plugin its project lists, and the one its place provides, and runs with one:

```sh
dist/api-linux-x86_64                        # sqlite, as jac.toml's `plugin` says
JAC_STORE=jsonstore dist/api-linux-x86_64    # jsonstore
```

- `JAC_<ABSTRACTION>` picks among the plugins the program holds as the program starts. For a
  space's own binding it is `JAC_<SPACE>_<ABSTRACTION>`, which is read first.
- A name that is not listed ends the program with status 1:

  ```text
  JAC_STORE=postgres: this program was not built with a plugin 'postgres' for `store`, only with: sqlite, jsonstore
  ```

- Nothing is loaded as a program runs. A plugin that neither `jac.toml` lists nor the place
  provides is not in the program.

So one artifact serves development and production: list both plugins, and say which where it is
deployed.

`ui` and `bundler` are not picked this way. What a component compiles to and what bundles a space
are settled when the space is built, so there is no `JAC_UI` and no `JAC_BUNDLER`, and a bundler's
settings are read from `jac.toml` alone.

## Settings

A setting of a plugin picked as a program starts is a field of the plugin's class. `jac.toml`
gives its value, which is built into the program, and the place the program runs overrides it:

```sh
JAC_STORE=jsonstore JAC_STORE_FILE=/var/lib/api/notes.json JAC_STORE_INDENT=0 dist/api-linux-x86_64
```

- **`JAC_<ABSTRACTION>_<FIELD>`** overrides a setting of the plugin picked. A `str` is taken as it
  is written, and any other type is read as JSON (`2`, `true`, `["a", "b"]`).
- **A build holds a table to the fields.** A key that is no field is E1052, a value of another
  type E1053, and a field with no default that is given no value E1050, each at its line of
  `jac.toml`.
- **A value that is not of the setting's type where the program runs** ends it with status 1,
  naming the variable.

### An abstraction's settings

A setting that every plugin of an abstraction means the same by is the abstraction's, not one
plugin's: that an app makes no new accounts, how long a session lasts, where callers reach the app.
The project writes it under the abstraction, and it holds whichever plugin the program runs with:

```toml
[auth]
registration = false
origin = "https://example.org"

[auth.accounts]
path = "/var/lib/api/accounts.db"
```

- **They are the fields of a class the abstraction's contract declares,** which its `jac.toml`
  names as `settings`: `auth`'s are `auth.contract.AuthSettings`'s. `auth` is the one abstraction
  with settings of its own in this neojac
  ([Serving a space](server.md#the-accounts-plugin) has them).
- **Every plugin of the abstraction is given them:** its class derives from that class beside the
  interface (`obj Accounts(Auth, AuthSettings)`), so they are fields of every plugin, and the
  plugin reads them as it reads its own (`self.registration`). The program makes the plugin with
  its own settings, gives it the abstraction's, then the environment's.
- **`JAC_<ABSTRACTION>_<FIELD>` overrides them** as it does a plugin's own:
  `JAC_AUTH_REGISTRATION=true`.
- **A build holds `[<abstraction>]` to them** as it holds a plugin's table to its fields: a key that
  is no setting of the abstraction is E1052 (a plugin's own setting is written under the plugin),
  and a value of another type E1053. One written under a plugin's table, `[auth.accounts]
  registration`, is E5158: it is the abstraction's. An abstraction with no settings takes no key
  but `plugin` and plugins' tables (E5158).
- **A setting is the abstraction's when every plugin of it must mean the same by it,** and one
  plugin's when it is how that plugin keeps or does its work: a file's path, the rounds a password
  is hashed with, how often a clock looks for work that is due.

### Secrets

A setting of type `Secret` is never written in `jac.toml`, and is not in the program: it names a
variable of the environment, read where the program runs when the plugin asks its host for it
(`host.secret(self.key)`, [below](#what-a-plugin-imports)). A plugin's field says which variable
(`ANTHROPIC_API_KEY`), and `JAC_<ABSTRACTION>_<FIELD>`, when it is set, is read in its place.
Giving one a value in `jac.toml` is E1053.

## The standard plugins

| Plugin | Carries out | Its settings |
|---|---|---|
| `sqlite` | `store`: a space's graph, as rows in a SQLite file, which the programs of one machine may keep together | `path`, the file: `graph.db` in the app's data directory |
| `accounts` | `auth`: accounts of a username and a password, and their sessions, in a SQLite file; signing in through GitHub and through Google, where the program runs with an OAuth client's ID and secret; and addresses checked and passwords set again by mailed links, where the app sends mail | `path` and `rounds`, beside `auth`'s own ([Serving a space](server.md#the-accounts-plugin)) |
| `http` | `transport`: requests over HTTP, a call's reply as JSON and a stream's events as they are made, and the server that answers them | `client_header`, the header a gateway in front of it writes each request's client address into ([Serving a space](server.md#the-address-a-caller-calls-from)) |
| `anthropic` | `llm`: a model behind Anthropic's Messages API | `model`, `address`, `timeout`, `retries`, `rates`, and the secret `key` ([By and sem](../language/by-and-sem.md#the-model-plugins)) |
| `openai` | `llm`: a model behind an OpenAI-compatible Chat Completions API: OpenAI's, or another provider's or a local server's that speaks it | `model`, `address`, `timeout`, `retries`, `rates`, and the secret `key` ([By and sem](../language/by-and-sem.md#the-model-plugins)) |
| `process_jobs` | `jobs`: each job in a copy of the program | `dir`, where a job's input and what it says are kept while it runs: `jobs` in the app's data directory |
| `loop_schedule` | `schedule`: each scheduled function run by the thread that listens, when it is due | `tick`, how often its clock looks for one that is due, in seconds: `0.25` |
| `memory_limits` | `limits`: uses counted in the program's memory | `sweep_at`, how many actors' uses are kept before those whose window has passed are let go: `1024` |
| `local_files` | `files`: each file's bytes in a file of the app's data directory, and what is known of each in a SQLite file beside them, which the programs of one machine may keep together | `path`, the directory: `files` in the app's data directory ([Files](files.md#where-files-are-kept)) |
| `smtp` | `mail`: each letter handed to an SMTP server. With no server, or no sender, the app sends no mail | `host`, `port`, `sender`, `user`, `starttls`, and the secret `password` ([Serving a space](server.md#the-mail-an-app-sends)) |
| `react` | `ui`: React, with React Router's file routes. A browser space's standard | None |
| `preact` | `ui`: Preact | None |
| `solid` | `ui`: Solid, whose state is fine-grained | None |
| `react_native` | `ui`: React Native. A hermes space's standard | None |
| `none` | `ui`: no UI library. A node space's standard | None |
| `vite` | `bundler`: the project's own Vite, run in the space's npm tree. What `react`, `preact` and `solid` name | `config`, the project's Vite configuration, from its root |
| `expo` | `bundler`: the project's Expo, which makes a phone app of a hermes space. What `react_native` names | None |

The app's data directory is `JAC_<APP>_DATA` ([An app's data](data.md#where-it-is-kept)). What
each `ui` plugin does with a component, and what each bundler does, is on
[UI plugins and bundlers](ui-bindings.md).

An abstraction that every app has one of (`auth`, `transport`, `llm`, `jobs`, `schedule`,
`limits`, `files`, `mail`) is bound for the project, in `[<abstraction>]`. `store`, `ui` and `bundler` may also be
bound for one space.

## Writing a plugin

A plugin is a package: a directory with a `jac.toml` and its modules.

```toml
[project]
name = "jsonstore"
kind = "plugin"

[plugin]
fills = "store"
interface_ver = 1
class = "jsonstore.store.JsonStore"
```

- `fills` is the abstraction, and `class` the class that carries it out, named as
  `<plugin>.<module>.<Class>`: here `JsonStore` of `store.jac` in the package's directory.
- `interface_ver` is the version of the abstraction's interface the plugin was written for
  ([The abstractions](#the-abstractions)). It is required (E2216 without it), and a plugin whose
  `interface_ver` is not this neojac's is E2230. When an interface's version goes up, a plugin is
  written again for the new one and published as a new version of its own, which says so.
- The package is a project, so it has an `archwire.jac` that puts its modules in a layer
  ([Projects](../toolchain/projects.md#archwirejac)): for this one,
  `graph layers { layer store { store; } }`. A command run on the plugin holds the whole of it
  to its wiring; a program that takes the plugin does not judge it again.
- The class conforms to the abstraction's interface. One that does not is refused where it is
  bound (E1281).
- A plugin of `ui` or `bundler` has no class: nothing of it runs with the program. In place of
  `class`, its `jac.toml` has a table named for the abstraction, which says how it fills it
  ([below](#a-plugin-picked-as-a-space-is-built)).

<!-- example: not checked: a plugin is a package of its own, with a jac.toml that names this class -->
```jac
import json;
import os;
import from common.contract { Host }
import from store.contract { Row, Store }

obj JsonStore(Store) {
    has file: str = "graph.json",
        indent: int = 0;
    has rows: dict[str, list[any]] postinit;
    has data_dir: str postinit;

    def postinit {
        self.rows = {};
        self.data_dir = "";
    }

    def kept_as -> str {
        return os.path.join(self.data_dir, self.file);
    }

    def open(host: dyn Host) {
        self.data_dir = host.data_dir();
        if os.path.exists(self.kept_as()) {
            with open(self.kept_as()) as f {
                self.rows = json.load(f);
            }
        }
    }

    # ... the rest of `Store`: types, shapes, of_type, rows, edges, mark, since, write,
    # every, root_of, roots, shared_root.
}
```

- **Its fields are its settings.** `file` and `indent` are what `[store.jsonstore]` may give.
- **A plugin of an abstraction with settings of its own derives from their class too,** beside
  the interface: `obj TicketAuth(Auth, AuthSettings)`. They are then fields of the plugin, which
  `[auth]` gives and the plugin honours. A class that does not derive from it is refused where it
  is bound (E1053, `give_settings()`'s `plugin` expects `AuthSettings`).
- **What it keeps for itself is a `postinit` field,** which no constructor takes: `rows` is no
  setting, and `[store.jsonstore] rows = ...` is E1052.
- **`open(host)` is the first thing asked of it,** once, before anything else. The plugin is made
  with `jac.toml`'s settings, then given the environment's, and only then opened: `Store.open` is
  where a store reaches its file. Work done in `postinit` would be done with settings that may
  still change. A plugin with nothing to open writes `def open(host: dyn Host) {}`.
- **It does nothing more until its abstraction asks.** `Transport.claim` is where a transport
  takes its address, raising `CannotListen` with the reason where it can't.
- **Nothing imports it,** and it declares no plugin (E2221).

### What a plugin imports

A plugin's modules import four things, and nothing else of neojac's (E2233):

| Import | What it gives |
|---|---|
| `<abstraction>.contract` | The contract of the abstraction it fills: the interface its class implements, and every type and function that crosses it |
| `common.contract` | What every plugin may use: `Host`, `Secret` and `DataError` |
| The libraries its own `jac.toml` declares | Any library, in the plugin's own `[packages]` ([Packages](../toolchain/packages.md#jac-packages)) |
| The standard library | `os`, `json`, `sqlite3`, `urllib`, and a Python or C package of its own |

It imports nothing of stdjac, and no other abstraction's contract. A library a plugin declares is
held to the same rule: it imports `common.contract` and the contract of the abstraction that plugin
fills, so what two plugins of one abstraction share is written once, in a library both declare. A
library that plugins of two abstractions declare imports neither's contract. A plugin reaches stdjac
through nothing.

The built-in words of the abstractions (`@job`, `llm` and the rest) are stdjac's too, and a
plugin says none of them. `neojac check` in the plugin's own directory holds each of its modules
to all of this, with no app around it ([check](../toolchain/check.md#checking-a-package)).

**What a plugin needs of the program that runs it, the program gives it.** `open` is handed the
program as a host, an interface the contract declares and the program implements:

| Host | Whose `open` is given it | What a plugin asks it |
|---|---|---|
| `common.contract`'s `Host` | `Store`, `Transport`, `Model`, `Scheduler`, `Limits`, `Files`, `Mailer` | `data_dir()`, where the program keeps files beside itself, its app's data directory ([An app's data](data.md#where-it-is-kept)); `secret(s)`, what the place the program runs gives a `Secret`, or `""`; `upgraded(what)`, to have the program say as it starts what the plugin did to data it keeps |
| `auth.contract`'s `AuthHost` | `Auth` | A `Host`'s, and `windowed()`, whether the app shows itself in a window of its own; `consume_limit(scope, actor, limit, seconds)`, a use counted by the project's `limits`; `sends_mail()` and `send_mail(to, subject, text)`, a letter sent by the project's `mail` |
| `jobs.contract`'s `JobsHost` | `Jobs` | A `Host`'s, and `command()`, the command that runs the program again; `owner()`, the space whose jobs a copy's are; `run(name, input, note)` and `run_space(owner, name, input, note)`, which run a job where the plugin has it run |

A plugin that asks its host later keeps it in a `postinit` field
(`has host: dyn JobsHost | None postinit;`), or keeps what it asked (`data_dir`, above).

**A contract declares, and reaches nothing:** no file, and no variable of the environment. What
needs nothing of the program is in the contract itself, a function or a class a plugin imports:

| Name | In | What it is |
|---|---|---|
| `Secret` | `common.contract` | A setting that is never written down: the name of its variable, whose value the host gives ([Secrets](#secrets)) |
| `DataError` | `common.contract` | What `open` raises for data the plugin keeps that it can't start with: the file, and what is wrong with it. The program says it in words, and stops |
| `bearer_token(headers)` | `auth.contract` | The credential a request carries as a bearer token |
| `json_fail(status, kind, detail)` | `transport.contract` | The reply that says a request failed, for a transport that fails one the program never saw |

**`sqlfile` is a library,** not a part of any contract: `open_db` opens a SQLite file at a layout,
makes a new one, and upgrades an older one by the steps the plugin gives, telling the plugin's
host what it upgraded. neojac's `sqlite` and `accounts` plugins declare it, by its place in neojac's
tree, as a plugin declares any library:

```toml
[packages]
sqlfile = { path = "../../../libraries/sqlfile" }
```

**`accountbook` is a library of `auth` plugins:** accounts of a username and a password, their
sessions, signing in through GitHub and Google, and the links mailed to their addresses, over a
book that keeps them. It imports `auth.contract`,
so only a plugin of `auth` declares it.

- **`AccountsAuth` is an `Auth` but for where its accounts are kept.** A plugin's class extends it
  and gives `open_book(host)`, the `Book` it keeps them in. It derives from `AuthSettings`, and
  adds a setting of its own, `rounds`, which is the plugin's beside its own: `accounts` adds
  `path` ([Serving a space](server.md#the-accounts-plugin)).
- **A `Book` is seventeen methods, each one step done whole:** a session by its token's hash,
  one begun and one ended, an account found by its username or email, one made unless either is
  taken, the user an identity of another service names (as it is known, and made where it is
  not), that service's identities, `away_key()`, the key that signs what a caller carries
  to another service and back, a program that shows no page kept waiting under its code
  (`expect`), said to be someone's or turned away (`decide`), and collected once (`collect`);
  an account's address and whether it is checked (`address`), an address given to an account
  that has none unless another has it (`give_address`), a mailed link kept by its token's hash
  (`link`), and a link followed once: one that checks the address (`check`), and one that sets
  the password, ending the account's sessions (`reset`).
- **What is taken is an answer, not an error:** `add` says whether the account was made. So a
  book over a database several programs reach is a statement or two for each method, and holds
  no transaction open.
- **neojac's `accounts` gives a book over a SQLite file,** whose key is the process's own. A
  plugin that keeps accounts where every instance of an app reaches them gives a book over that,
  with a key they all read, and is the same plugin otherwise.
- **A class that sets `postinit` fields of its own** calls `super.postinit()` first: the
  library's class sets its own there.

### What a store is asked

`store.contract`'s `Store` is rows by their ids, with no query language: a graph database is used
as rows too. The runtime above it owns which node is which object, what of the graph is in memory
and what a call changed ([An app's data](data.md#what-of-the-graph-is-in-memory)).

| Method | Gives or does |
|---|---|
| `open(host)`, `kept_as()` | Makes ready to hold rows, in the program `host`; what its data is called, where an app says what is wrong with what it kept |
| `rows(ids)` | The rows of those ids, those it holds: a `Row` is a node or an edge, with its type's name, its fields as JSON text, an edge's two ends and its place in the order edges were made, and its `version` |
| `edges(id)` | Every edge at a node, out of it and into it, in the order they were made |
| `write(w)` | Keeps what one commit writes, all of it or none: the rows to keep and those to take out, each at the version it was read at, the roots first given to users, and the shared root. `StoreConflict` when a row is at another version, or a user has a root already. Gives the store's new mark |
| `mark()`, `since(mark)` | Where its writes are counted to, and what was written after a mark by any user of it: the rows as they are now, and the ids taken out. `None` when it no longer knows that far back |
| `types()`, `shapes()`, `of_type(name)` | How many rows it holds of each type, the shape each type's rows were written in, and every row of one type: what a program is held against as it starts, reading rows only of a type whose shape it has changed |
| `every()` | Every row, one at a time and without its data: what `sweep()` reads |
| `root_of(user)`, `roots()`, `shared_root()` | The ids of a user's root, of every user's, and of the shared one |

- **A store that one program uses** may answer `since` with nothing and keep its mark to itself, as
  the tests' `jsonstore` does. One that several programs share, as `sqlite` is, tells each what
  the others wrote.
- **A write is the only thing that changes it,** and it is whole: a store never holds half of what
  a call made.

### A plugin picked as a space is built

A `ui` or a `bundler` plugin is a `jac.toml` with a table of its abstraction's name, and the files
that table names:

```toml
[project]
name = "bundle"
kind = "plugin"

[plugin]
fills = "bundler"
interface_ver = 1

[bundler]
build = "bundle.mjs"
settings = ["minify"]
```

- **A `[ui]` table** says which library's functions the language's state, derived values and
  effects become, which hosts the library runs on and which npm packages are its own
  ([A project's own `ui` plugin](ui-bindings.md#a-projects-own-ui-plugin)).
- **A `[bundler]` table** names the script that bundles a space, the one that serves it under
  `neojac dev`, and the settings a project may give it
  ([A project's own bundler](ui-bindings.md#a-projects-own-bundler)).
- **A plugin that fills one of the two and has no such table** is E2216.
- **Its settings are the names its table lists,** written in `jac.toml` and read as the space is
  built. They are not fields, and no variable of the environment overrides one.

### A second plugin of each abstraction

The repository's `tests/plugins/` holds a second plugin for each abstraction that is picked as a
program starts, each a package a project declares by its path, and the suite runs one built
program under both. Each is a short
example of its interface:

| Plugin | Fills | How it differs from the standard one |
|---|---|---|
| `jsonstore` | `store` | The rows in one JSON file |
| `ticket_auth` | `auth` | No accounts: callers sign in at another service, which says whose each ticket is |
| `line_transport` | `transport` | A wire of its own, a line of JSON each way over TCP: it carries calls and serves no paths |
| `chat_model` | `llm` | A model behind a chat-completions API: one dialect, and nothing of tool rounds or decoding |
| `queue_jobs` | `jobs` | One worker, which runs the jobs queued in their order |
| `timer_schedule` | `schedule` | A thread for each scheduled function, which sleeps until it is due |
| `file_limits` | `limits` | Uses counted in a SQLite file, so they outlast the program |
| `spool_mail` | `mail` | Each letter a file of its own in a directory: nothing leaves the machine |
| `flat_files` | `files` | Each file's bytes in one directory, and what is known of it in a JSON file beside it: no database. A piece of a file is five bytes |

## What is refused

| Code | Condition |
|---|---|
| E2214 | `jac.toml`, a project's or a place's, names a plugin that its `[packages]` does not declare and neojac does not ship |
| E2215 | A plugin is bound to an abstraction it does not fill |
| E2216 | A plugin's package is not where `[packages]` says, or its manifest does not say what it fills: its `class`, or for `ui` and `bundler` its table |
| E2217 | A package declares an abstraction: the abstractions are neojac's own |
| E2218 | A module imports a plugin |
| E2221 | A library or a plugin declares a plugin: only a project does |
| E2227 | The project declares a plugin that no binding names and no abstraction lists, or a place one that its `[provides]` does not name |
| E2239 | `--place` names a directory that is no place: no `jac.toml`, no `kind = "place"`, or no `[provides]` |
| E2242 | The program uses an abstraction that its project leaves open and its place does not provide |
| E2230 | A plugin was written for another version of its abstraction's interface than this neojac's |
| E2233 | A plugin, or a library a plugin declares, imports a module of stdjac or the contract of an abstraction it does not fill |
| E1050, E1052, E1053 | A setting left out, a key that is no setting, a value of another type. E1053 too for a plugin's class that does not derive from its abstraction's settings |
| E1281 | The plugin's class does not conform to the abstraction's interface |
| E5158 | An abstraction's table holds something other than `plugin`, plugins' tables and the abstraction's own settings; a plugin's table holds a setting of the abstraction; `[packages]` an entry that is no source; or a place's `[provides]` a key that is no abstraction picked as a program starts, or the place a table other than its plugins'. For `ui` and `bundler`: the table of a plugin the space is not built with, a setting the plugin does not list, or a form `jac.toml` had before (`ui = "preact"`, `bundler_config`) |
| E1214 | A `ui` plugin that does not run on the space's host |
| E5090 | Spaces that run in one program are bound to different plugins for an abstraction a space has one of; or a plugin is bound for one crossing (`[crossings.<a>.<b>.transport]`), which neojac does not build yet: every crossing of a project is carried by the plugin its `[transport]` binds |

## Differences from Python and from the reference design

- The reference design's plugins are Python packages a program finds installed as it starts, and each adds what it
  likes. Here a plugin fills one abstraction the language has, the build compiles it in, and what
  a program means does not depend on which one it has.
- Python has no counterpart: a library there is imported by the code that uses it.
