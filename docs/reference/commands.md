---
description: Every neojac command: what it does, its forms, its options and examples.
---
# Commands

What `neojac help <command>` prints for each command, in the order `neojac help` lists them. This page is printed by `neojac help --markdown`, from the same table.

## How a command line is read

Every command reads its arguments the same way, from the table this page is printed from, so what a command's help lists is what the command takes.

- An argument that begins with `-` and a letter, or with `--` and a letter, is an option. One the command does not have is an error, answered with the nearest it has or with the command that has it.
- An option that takes a value takes the next argument, whatever it is. One spelled with `--` also takes it after `=`: `--target=wasm32-wasi`.
- Options and names come in any order.
- `--` ends the options. What follows is names, or, for `run` and `dev`, the arguments of what is run.
- Anything else is a name: `-`, `-5` and `-->` among them.

## Learn

### `neojac docs`

Print the documentation: a page, or what defines a word.

```sh
neojac docs [--json]
neojac docs section <heading> [--json]
neojac docs <page | word> [--json]
neojac docs search <text> [-n <count>] [--json]
neojac docs [<page | word>] --serve [--listen <address>]
neojac docs --path
neojac docs --check
```

| Option | What it does |
|---|---|
| `--json` | Print the answer as data |
| `--path` | Print the directory the pages are in, for grep |
| `--check` | List what of neojac the pages leave out, and what in them leads nowhere |
| `-n <count>` | How many pages a search shows (default: 10) |
| `--serve` | Serve the pages to a browser, opened at the page or the word given |
| `--listen <address>` | Where --serve serves them (default: 127.0.0.1:8091) |

Alone, prints the map: every section, and under its heading its pages, each by its path and title. `docs section <heading>` prints a section's pages, each with what it covers. The pages are Markdown, for this version of neojac, and need no network.

A word is answered with what defines it: a page by its path (language/walkers) or the last part of it (walkers), a diagnostic code (E1307), a keyword or operator, a builtin, a module, a jac.toml key, an environment variable, a command, or a rule of the grammar.

Several words are one name (`neojac docs flow for`), and an operator is a word like any other, quoted where the shell would read it: `neojac docs '-->'`. A word that names nothing is an error, with the nearest that does; `docs search` finds the pages that mention a text. A word that names several things is answered with the first, after a note of the others.

`--serve` serves the same pages to a browser and prints their address: each page as it reads, the map beside it, and one box that searches the pages and answers a word.

| Example | What it does |
|---|---|
| `neojac docs` | The map of the pages |
| `neojac docs section basics` | A section's pages, each with what it covers |
| `neojac docs start/primer` | The language in one page |
| `neojac docs visit` | The page that defines a keyword |
| `neojac docs E1307` | What an error means, and the fix |
| `neojac docs search edge filter` | Pages that mention a text |
| `neojac docs --serve` | The pages, in a browser |

Its guide: [toolchain/docs](../toolchain/docs.md) (`neojac docs toolchain/docs`).

### `neojac skills`

Print playbooks for common tasks, or install them.

```sh
neojac skills [--json]
neojac skills <name> [--json]
neojac skills install [<name>...] [--to <dir>]
```

| Option | What it does |
|---|---|
| `--json` | Print the answer as data |
| `--to <dir>` | Where install writes (default: .agents/skills in the directory it is run in) |

A skill is a playbook for a task, written for an agent: when to use it, the steps, the commands and what a correct result looks like. Alone, lists them.

`skills install` copies skills, each a directory holding a SKILL.md, to where an agent loads them from: every skill, or those named.

| Example | What it does |
|---|---|
| `neojac skills` | The skills, each with what it is for |
| `neojac skills writing-jac` | One skill |
| `neojac skills install` | Every skill, into .agents/skills |

Its guide: [toolchain/docs](../toolchain/docs.md) (`neojac docs toolchain/docs`).

## Build and run

### `neojac build`

Compile a program, or a project's apps.

```sh
neojac build [<program>...] -o <out> [<option>...]
neojac build [<app>...] [--profile <profile>] [--place <directory>]
neojac build [<package>...]
neojac build <directory>/pyproject.toml
neojac build <directory>/package.json
```

| Option | What it does |
|---|---|
| `-o <out>` | The file to write |
| `--release` | Inline more across modules: faster code, from a build that takes longer |
| `--target <platform>` | Build for another platform: macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi |
| `--cpu <processor>` | Compile for a processor newer than the platform's baseline: a level of the architecture (x86-64-v2, x86-64-v3, x86-64-v4) or native; the program runs only on processors that have what it has |
| `--lib` | Build a C-ABI shared library of the main module's :pub functions and globals |
| `--c-archive` | Write the program's C modules as a static library; the program isn't built |
| `--gui` | Build a Windows program of the GUI subsystem, which starts without a console |
| `--monitor` | Have a program using Python fire sys.monitoring's events, for profilers and coverage |
| `--memory <profile>` | The memory profile: managed, rc or nogc (default: jac.toml's [memory] profile, else managed) |
| `--emit-ir <file>` | Also write the program's LLVM IR |
| `--verify-reuse` | Compile every module, and check each one an earlier build made against what its sources make now |
| `--profile <profile>` | Build the apps as the archwire's profile of that name arranges them |
| `--place <directory>` | The place the program is for: the directory whose jac.toml provides the plugin of each abstraction the project leaves open (default: this machine, each abstraction's standard plugin) |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

A program is a file, known by its extension: a Jac program's main module (.jac), a C or C++ program (.c, .cc, .cpp), a Rust one (.rs) or a Python one (.py), each file built alone with its language's standard library. Or it is a directory, known by the first of these manifests it holds: an archwire.jac that declares spaces (a project's apps), jac.toml (a Jac project, whose program is its main.jac), Cargo.toml (a Rust package), cmodule.toml (a C module whose sources define main). With none named, it is the directory you are in.

A program is built into one executable, which needs nothing installed where it runs; a Python program into the directory -o names, holding the program, the CPython it runs on and its standard library, and a launcher of the program's name. The options but -o and --release are a Jac program's.

Several Jac programs are built into one executable that holds each of them and runs the one its first argument names: a program is named by its file, a main.jac by its directory.

In a project whose archwire.jac declares spaces, a name with no extension or path in it is an app's or a package's: the ones named, or every one, are each built into dist/, and where each one is is printed. A package (`package <name> { ship <space>; }`) of a space that holds a Python project is that project's wheel.

A Python project the project holds ([pypi."<directory>"]), named by its pyproject.toml, is built into a directory of .jac/build/pypi/, which is printed: the files its wheel holds ([wheel."<directory>"]), each extension module of [extensions] built from its crate or its C module, and its metadata. It is what `neojac test` runs the project's own suite against. A Python project's wheel is built for this system alone. An npm tree, named by its package.json, has its extension modules built: each addon of [extensions] under it, from its C module, where the tree's code looks for it; with --target, for that platform, from the Jac its C module's files are ported to (an addon built from C and C++ is built on the system it is for).

A program is built for a place, which provides a plugin for each of the language's abstractions the project leaves open: this machine, each abstraction's standard plugin, unless --place names the directory of another, whose jac.toml says `kind = "place"` and, in [provides], the plugin of each abstraction there. A plugin the project names itself is the project's choice wherever it is built.

A build compiles each module on its own and keeps what it compiles in a cache (NEOJAC_CACHE_DIR, else neojac/ in your cache directory), so an edit recompiles only what it touched, and a build with nothing changed does nothing.

| Example | What it does |
|---|---|
| `neojac build hello.jac -o hello` | A program for this machine |
| `neojac build hello.c -o hello` | A C program of one file |
| `neojac build adder -o adder --release` | The Rust package in adder/ |
| `neojac build hello.jac -o hello.wasm --target wasm32-wasi` | The same program for WASI |
| `neojac build count.jac sort.jac -o tools` | Two programs in one executable: `tools count` runs the first |
| `neojac build` | Every app of the project in this directory |
| `neojac build web --profile fleet` | One app, under a profile |
| `neojac build web --place ../place` | One app, for the place in ../place |

Its guide: [toolchain/build](../toolchain/build.md) (`neojac docs toolchain/build`).

### `neojac run`

Build a program, or one of a project's apps, and run it.

```sh
neojac run [<program>] [<option>...] [-- <argument>...]
neojac run <app> [<option>...] [-- <argument>...]
```

| Option | What it does |
|---|---|
| `-o <out>` | Where to build the program (default: in its project's .jac/build/) |
| `--release` | Inline more across modules: faster code, from a build that takes longer |
| `--cpu <processor>` | Compile for a processor newer than the platform's baseline: a level of the architecture (x86-64-v2, x86-64-v3, x86-64-v4) or native; the program runs only on processors that have what it has |
| `--gui` | Build a Windows program of the GUI subsystem, which starts without a console |
| `--monitor` | Have a program using Python fire sys.monitoring's events, for profilers and coverage |
| `--memory <profile>` | The memory profile: managed, rc or nogc (default: jac.toml's [memory] profile, else managed) |
| `--fresh` | Start the app with no data: what it kept in .jac/data/<app> is set aside, in a directory beside it named for the moment |
| `--profile <profile>` | Build the app as the archwire's profile of that name arranges it |
| `--place <directory>` | The place the program is for: the directory whose jac.toml provides the plugin of each abstraction the project leaves open (default: this machine, each abstraction's standard plugin) |
| `-- <argument>...` | What follows is the app's own command line |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

A program is named as `neojac build` names one, and built as it builds one; then it runs, and neojac exits with its status.

A Jac module that a cpython or a node space of its project holds runs on that space's host, as `__main__`: the space's program, built with the module as its entry, whatever entry the space names.

An app is run from its project's root. It is built as `neojac build <app>` builds it, then runs in neojac's place: a signal sent to `neojac run` is sent to the app, and the status it ends with is the app's.

A phone app (one that runs a hermes space) is installed on the Android phone or emulator that is connected, an emulator started when none is, and started there; a space it reaches at this machine's own address is reached from the phone as this machine's port.

| Example | What it does |
|---|---|
| `neojac run hello.rs` | Build and run a Rust program of one file |
| `neojac run -- input.txt` | Run the program in this directory, with an argument |
| `neojac run web` | Build the app `web` and serve it |
| `neojac run cli -- docs status` | Pass the app its arguments |

Its guide: [apps/building](../apps/building.md) (`neojac docs apps/building`).

### `neojac dev`

Work on an app: rebuild and restart it as you edit.

```sh
neojac dev <app> [<option>...] [-- <argument>...]
```

| Option | What it does |
|---|---|
| `--listen <address>` | Where the app is while it is worked on (default: 127.0.0.1:8000) |
| `--fresh` | Start the app with no data, as `neojac run --fresh` does |
| `--profile <profile>` | Build the app as the archwire's profile of that name arranges it |
| `--place <directory>` | The place the program is for: the directory whose jac.toml provides the plugin of each abstraction the project leaves open (default: this machine, each abstraction's standard plugin) |
| `-- <argument>...` | What follows is the app's own command line |

Run from a project's root. The app is built and started, and from then on a change to a file of the project builds again what the change reaches. The app's program is started again only when what it is made from changed; a build that fails says why and leaves what is running as it is.

An app's page is served by its bundler's dev server instead of a bundle, when the bundler has one, so a page edit is one compile, which the open page then shows by itself. The page is at `--listen`, and what it asks of the app goes on to the app's program.

| Example | What it does |
|---|---|
| `neojac dev web` | Work on the app `web` |
| `neojac dev web --listen 127.0.0.1:9000` | Work on it with its page at another address |

Its guide: [apps/building](../apps/building.md) (`neojac docs apps/building`).

### `neojac check`

Check a program, or a project's apps, for errors without building.

```sh
neojac check [<program>] [<option>...]
neojac check [<app>...] [--profile <profile>] [--place <directory>]
neojac check [<app>] --space <space> [<option>...]
```

| Option | What it does |
|---|---|
| `--target <platform>` | Build for another platform: macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi |
| `--memory <profile>` | The memory profile: managed, rc or nogc (default: jac.toml's [memory] profile, else managed) |
| `--lib` | Check it as the shared library `build --lib` makes |
| `--space <space>` | Check one space's program on its host: an app's program of it where an app is named, else the space alone, as emit-js and emit-py load it |
| `--profile <profile>` | Check the apps as the archwire's profile of that name arranges them |
| `--place <directory>` | The place the program is for: the directory whose jac.toml provides the plugin of each abstraction the project leaves open (default: this machine, each abstraction's standard plugin) |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Runs everything a build checks (syntax, names, types, ownership, the memory profile's contract) and reports every error it finds, the tests of the modules it checks among them. Exits with status 1 when there are any.

A project's modules are held to the rules every project keeps: no comment, no docstring, every body in an impl annex, and an archwire.jac that states the imports. A project written by hand may take rules out, by `human_mode = true` under [project] in jac.toml. An AI agent never writes that key: where a project it works in has it, the agent removes it with the [check.lint] `ignore` and `exclude` it allowed, and runs `neojac fmt --fix`.

It takes what `neojac build` takes. A program is a Jac program's main module, or a directory, known by the first of these manifests it holds: an archwire.jac that declares spaces (a project's apps), jac.toml (a Jac project, whose program is its main.jac). With none named, it is the directory you are in.

In a project whose archwire.jac declares spaces, a name with no extension or path in it is an app's. The apps named, or every app and every space no app holds, are each checked as their build makes them: every program an app is, on its host, all at once. --space checks one of them. --target, --memory and --lib are options of one program's check: a main module's, or a space's.

| Example | What it does |
|---|---|
| `neojac check main.jac` |  |
| `neojac check` | The project in this directory: its apps, or its main.jac |
| `neojac check web` | The app web: each program it is |
| `neojac check web --space site` | The app web's program of site |
| `neojac check --space site` | The space site alone, on its host |

Its guide: [toolchain/check](../toolchain/check.md) (`neojac docs toolchain/check`).

### `neojac test`

Build and run tests.

```sh
neojac test [<path>...] [<option>...]
neojac test <file.jac> -o <runner> [<option>...]
```

| Option | What it does |
|---|---|
| `-k <text>` | Run only the tests whose names contain <text>; a module with none isn't built |
| `-j <jobs>` | Run on this many processors, which the runners' builds, the tests and the builds a test starts share (default: one for each core) |
| `-o <runner>` | Build the one module's test runner, and don't run it |
| `--target <platform>` | Build for another platform: macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi |
| `--place <directory>` | The place the program is for: the directory whose jac.toml provides the plugin of each abstraction the project leaves open (default: this machine, each abstraction's standard plugin) |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Runs the tests of every module under the paths given, or under jac.toml's [test] directories. Each module's tests are built into one runner, in the project's .jac/test/, and each test is a run of that runner by itself, in a directory of its own that NEOJAC_TEST_DIR names: the runners are built and the tests run in parallel.

The suites of the project's own trees that jac.toml names are run after them, each in its tree's directory: a Python project's by the command [test.pypi."<directory>"] gives, with the project's .jac/venv first on PATH and what `neojac build` makes of the project first on Python's path; an npm tree's by the script [test.npm."<directory>"] names; a crate's by `neojac cargo test`, with the arguments of [test.cargo."<directory>"]. A path that is a tree's manifest runs that suite alone, and -k runs none.

Exits with status 1 when a test fails, a suite does or a runner doesn't build, and 5 when there are no tests.

| Example | What it does |
|---|---|
| `neojac test` | Every test in the project |
| `neojac test tests/chess -k castling` | Some tests of one directory |

Its guide: [toolchain/test](../toolchain/test.md) (`neojac docs toolchain/test`).

### `neojac fmt`

Format Jac source.

```sh
neojac fmt [--check] [--fix] <path>...
```

| Option | What it does |
|---|---|
| `--check` | Change nothing: list the files that would change, and exit with status 1 if any would |
| `--fix` | First rewrite what has a fix: each old spelling the language rejects, and each rule the file's project keeps |

Rewrites the .jac files the paths name in neojac's one layout. A directory means every .jac file under it, but those its jac.toml's [fmt] exclude patterns name.

With --fix, a module and its annexes are fixed together, and nothing is written unless every file it would write parses. A comment and a docstring are removed; where jac.toml's [fmt] says `notes = true`, what each said is kept in the module's notes annex, notes/<module>.md, under the declaration it was about.

The rules are the ones every project keeps. A project written by hand may take some out, by `human_mode = true` under [project]. An AI agent never writes that key: where a project it works in has it, the agent removes it with the [check.lint] `ignore` and `exclude` it allowed, and runs `neojac fmt --fix`.

| Example | What it does |
|---|---|
| `neojac fmt src` |  |
| `neojac fmt --check .` | For CI |
| `neojac fmt --fix .` | Move a project to the one spelling |

Its guide: [toolchain/fmt](../toolchain/fmt.md) (`neojac docs toolchain/fmt`).

### `neojac port`

Translate source in another language into Jac.

```sh
neojac port [--check [--json]] [-o <out>] [<option>...] <path>...
neojac port --mapping <language>
```

| Option | What it does |
|---|---|
| `--check` | Write nothing: report what would port and what is refused, and in a project the plan, and exit with status 1 if anything is refused |
| `--json` | With --check, print what would port and the plan as data |
| `-o <out>` | Where to write, for sources outside a project: a .jac file for one source, else a directory (default: beside each source) |
| `--mapping <language>` | Print what port makes of each construct of a language: c, c++, rust, python or javascript |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Translates each source file into a Jac module that behaves as the file does, or refuses it and says why. A file is known by its extension, and a directory means every source under it that port translates. Each language is read by its own compiler, and the Jac is written in neojac's one layout, with the source's comments outside a project; in a project its rules hold, and the comments go as `neojac fmt --fix` has them go.

A file ports whole or not at all: every construct port refuses is reported (E4001, E4005), nothing is written for that file, and the exit status is 1. An output that is already there is refused (E4003).

In a project, a path is read as the project says, and porting a file moves its module in one change: the Jac is written beside the source, the source is moved to replaced-by-neojac/, its imports of the project's modules become ++> wires and its tables in jac.toml are updated, all of it only if the project then checks (E4008). Outside a project, the source is never changed.

| Example | What it does |
|---|---|
| `neojac port tools/gen.py` | Writes tools/gen.jac |
| `neojac port --check src` | What of a directory would port |
| `neojac port --mapping python` |  |

Its guide: [toolchain/port](../toolchain/port.md) (`neojac docs toolchain/port`).

### `neojac precommit`

Fix, format and check what is staged for a commit.

```sh
neojac precommit [--all] [--verify] [<path>...]
neojac precommit --install [--force]
```

| Option | What it does |
|---|---|
| `--all` | The whole project, where no path is given, in place of the staged files |
| `--verify, -v` | Change nothing: fail when a file is not as `neojac fmt --fix` leaves it, or doesn't check |
| `--install` | Install git's pre-commit hook, which runs `neojac precommit --verify`, and a commit-msg hook that refuses a commit naming an AI as its author |
| `--force` | With --install, replace a hook neojac did not install, keeping it as a .bak file |

Runs `neojac fmt --fix` on the .jac files staged for a commit (a module with its annexes), then checks each module as `neojac check` does, under the rules its project keeps.

A module is checked as a program of its own, so one that is no program is fixed and not checked: a file that is another target's variant, and one that jac.toml's `[check] exclude` names. `neojac check <main> --target <platform>` checks a variant in the program it is part of.

A file of a project whose archwire.jac declares spaces is checked in its project, whose apps are its programs: `neojac check` runs there once, however many of its files are staged.

Exits with status 1 when a check fails, when --verify finds a file to fix, or when it rewrote a staged file, which is then to stage again.

| Example | What it does |
|---|---|
| `neojac precommit` | Fix and check the staged files |
| `neojac precommit --all --verify` | For CI |
| `neojac precommit --install` | Once in a clone |

Its guide: [toolchain/lint](../toolchain/lint.md) (`neojac docs toolchain/lint`).

### `neojac launch`

Launch an app on the hosting platform, and look after it there.

```sh
neojac launch login [<address>]
neojac launch deploy <app> [--as <name>]
neojac launch secrets [set <KEY>[=<value>] | unset <KEY>] [--as <name>]
neojac launch logs [--lines <n>] [--as <name>]
neojac launch domains [add <domain> | remove <domain>] [--as <name>]
neojac launch delete [--as <name>] [--yes]
```

| Option | What it does |
|---|---|
| `--as <name>` | The app's name on the platform, which begins its address (default: the project's name) |
| `--lines <n>` | How many of each instance's last lines logs prints (default: 200) |
| `--yes` | Delete the app without asking for its name |

login signs in to the platform, at https://launch.neojac.dev unless an address is given: it prints a link and a code. Whoever signs in on that page, or makes an account there, and says the program showing the code is theirs has signed it in; login waits for that, and keeps the session for the commands that follow. deploy, run in a project, sends the project's files; the platform builds the app from them, runs it, and deploy prints what the build says and then the app's address.

The platform builds from source: the project's own directory is sent, without what a build or an install made in it, so its packages are ones jac.toml and jac.lock name by a version or a repository.

An app is launched under one name, which is its address's first word. Every other command is about that app: its secrets are variables of its environment, which the app starts again with when one changes; its logs are what its instances said; its domains are other names it answers at. A domain is the app's once its owner has shown it is theirs: domains add prints the records to make where the domain's DNS is kept, and domains says how far each has got. delete takes the app away for good, with everything it keeps.

| Example | What it does |
|---|---|
| `neojac launch login` | Sign in, or make an account, in a browser |
| `neojac launch deploy web` | Launch the project's app `web` |
| `neojac launch deploy web --as shop` | Under a name of its own |
| `neojac launch secrets set ANTHROPIC_API_KEY` | Set a secret, asked for and not echoed |
| `neojac launch logs --lines 50` | What its instances said last |
| `neojac launch domains add shop.example` | Another name for it |
| `neojac launch delete --as shop` | Take an app away for good |

Its guide: [toolchain/launch](../toolchain/launch.md) (`neojac docs toolchain/launch`).

## Packages

### `neojac install`

Install the project's packages, of every ecosystem.

```sh
neojac install [--frozen]
neojac install --pypi <package>...
neojac install --npm <package>... [--tree <directory>]
```

| Option | What it does |
|---|---|
| `--pypi <package>...` | Add these packages to jac.toml's [dependencies.pypi], and install them |
| `--npm <package>...` | Add these packages to an npm tree of jac.toml, [npm."<directory>"], and install them |
| `--tree <directory>` | The directory of the npm tree --npm adds to, made a tree if jac.toml has none there; a project's only tree needs no naming |
| `--frozen` | Install exactly what jac.lock pins, and fail if it doesn't cover jac.toml |

Installs what jac.toml lists and records in jac.lock exactly what was installed. A package jac.toml declares by a repository ([packages]) is fetched into eco/jac/<name>. jac.lock pins every package installed there, whoever installed it, and a package declared by its version that is not there stops the install. What the project's libraries and plugins need of PyPI and npm is installed with the project's own. PyPI packages ([dependencies.pypi]) go into the project's virtual environment (.jac/venv), on neojac's CPython. Each npm tree ([npm."<directory>"], which is the package.json of that directory) is installed by neojac's npm in its directory, where neojac writes its package.json and package-lock.json from jac.toml and jac.lock.

Where jac.toml has an [android] table, what a phone app's Android build is made with is fetched into neojac's cache, once the table accepts the Android SDK's licenses (`licenses = "accepted"`): the SDK unless ANDROID_HOME names one, a JDK unless JAVA_HOME names one, and an emulator where the table says `emulator = true`. Each is a pinned release, checked against its digest.

| Example | What it does |
|---|---|
| `neojac install` | What jac.toml lists |
| `neojac install --pypi numpy` | Add a PyPI package |
| `neojac install --npm lodash --tree eco/web` | Add an npm package |

Its guide: [toolchain/packages](../toolchain/packages.md) (`neojac docs toolchain/packages`).

### `neojac remove`

Remove packages from the project.

```sh
neojac remove --pypi <package>...
neojac remove --npm <package>... [--tree <directory>]
```

| Option | What it does |
|---|---|
| `--pypi <package>...` | Take these packages out of jac.toml's [dependencies.pypi] and the environment |
| `--npm <package>...` | Take these packages out of an npm tree of jac.toml and its installed packages |
| `--tree <directory>` | The npm tree's directory, where jac.toml has several |

Its guide: [toolchain/packages](../toolchain/packages.md) (`neojac docs toolchain/packages`).

### `neojac absorb`

Take a repository's manifests into jac.toml, and wire its files.

```sh
neojac absorb [<directory>] [--check | --record] [--json]
```

| Option | What it does |
|---|---|
| `--check` | Write nothing: print the trees it would take, the directories that are data, the open items, and what it would move to replaced-by-neojac/ |
| `--record` | Run each Python project's own build, and the node-gyp build of each npm tree with a binding.gyp, with the toolchain's tools recording, and write what it built: each extension module, made from a crate or from C, as [extensions], what its wheel holds, as [wheel], and in archwire.jac the space that holds the project and the package that ships it. The build's own files are put back from replaced-by-neojac/ for the run |
| `--json` | Print what it found, and what it wrote, as data |

Takes the manifests a directory holds into the jac.toml of the project it is in, each as a table named by its directory: a package.json with its package-lock.json ([npm]), a pyproject.toml ([pypi]), a Cargo.toml with its Cargo.lock ([cargo]) and a cmodule.toml ([c]). neojac writes each where it stands from then on, and no source moves. A directory with no jac.toml in it or above it becomes a project.

Which manifests are the project's is each ecosystem's own answer. The first manifest of an ecosystem met from the top is a tree, and under it only the workspaces its own tool names are: npm's, cargo's, uv's. Any other manifest there, a fixture's or a template's, is data: its directory is listed in jac.toml's [project] exclude, and nothing under it is taken.

It then writes the project's archwire.jac: one layer where there was no archwire, and a wire for every import between the project's files, as each language's own engine reads them. A step that fails leaves every file as it was.

What no manifest says, and only a program of the repository or a person knows, is an open item: a script that builds native code, a lock another tool wrote, how a tree's tests are run. Each is listed at its file.

What jac.toml, jac.lock and a record now stand in for is moved to replaced-by-neojac/, a folder at the project's top that holds each file at the place it stood and is no part of the project: a manifest as it stood before neojac wrote it, a build's own files (setup.py, MANIFEST.in, binding.gyp) once --record says all the build made, and another tool's lock once each of its pins is reproduced or accepted. Deleting the folder removes them. git's index is not changed: the command that stops git tracking the manifests is printed.

| Example | What it does |
|---|---|
| `neojac absorb --check` | What this repository is, with nothing written |
| `neojac absorb` | Make it a project |
| `neojac absorb crates` | The manifests under crates/, into this project |

Its guide: [toolchain/packages](../toolchain/packages.md) (`neojac docs toolchain/packages`).

### `neojac packages`

Print the project's Jac packages, and what is missing.

```sh
neojac packages [--json]
```

| Option | What it does |
|---|---|
| `--json` | Print one JSON document, which a package manager reads, and no text |

Prints the Jac packages of the project as the compiler finds them: each one's name, version and kind (and what a plugin fills), where its copy is and what installed it, every package that asks for it and for what, and whether it is found, missing or wrong. Then the version of each abstraction's interface in this neojac, which is what a plugin's interface_ver has to be, and every problem with its place in a jac.toml.

It reads and changes nothing: it fetches no package, writes no lock and hashes no file. Exits with status 1 when a package is missing or a check fails, and 0 when the project's packages are all as jac.toml asks.

| Example | What it does |
|---|---|
| `neojac packages` | What the project uses, and what is missing |
| `neojac packages --json` | The same, for a program to read |

Its guide: [toolchain/packages](../toolchain/packages.md) (`neojac docs toolchain/packages`).

### `neojac npm`, `neojac npx`

Run npm, or npx, on neojac's Node.

```sh
neojac npm [<npm argument>...]
neojac npx [<npx argument>...]
```

The npm that Node ships, with its own command line. In a project it runs in an npm tree of jac.toml (the one whose directory it is run in or under, or the project's only one), and what it writes to the tree's package.json and package-lock.json is taken into jac.toml and jac.lock as it ends.

Where some of the tree's sources are ported, `run`, `run-script`, `test` and `start`, and npx, run in the tree as its tools saw it: under .jac/test/spaces/, each ported source's place holds a file of its own name that gives the module, and what the tree's space emits is beside them.

Its arguments, --help among them, are that program's own: `neojac npm --help` is its help.

| Example | What it does |
|---|---|
| `neojac npm ls` |  |
| `neojac npm run build` | The tree's own build, its ported sources too |

Its guide: [interop/npm](../interop/npm.md) (`neojac docs interop/npm`).

## Runtimes and toolchains

### `neojac python`

Run neojac's CPython.

```sh
neojac python [<python argument>...]
neojac python <space directory> [-m <module> | -c <code>] [<argument>...]
```

CPython 3.15, with its own command line. In a project with a virtual environment (.jac/venv), it is that environment's Python.

A cpython space, as `neojac emit-py <space> -o <space directory>` writes it, is run by its directory: alone, its entry; with -m, a module run over its modules as `python -m` runs it (`-m pytest` runs a suite the space holds); with -c, code run over them as `python -c` runs it. A space with no entry takes -m or -c.

Its arguments, --help among them, are that program's own: `neojac python --help` is its help.

| Example | What it does |
|---|---|
| `neojac python -c 'import sys; print(sys.version)'` |  |
| `neojac python py -m pytest tests --import-mode=importlib` | The suite of the cpython space emitted into py |

Its guide: [interop/python](../interop/python.md) (`neojac docs interop/python`).

### `neojac node`

Run neojac's Node.

```sh
neojac node [<node argument>...]
```

Node, with its own command line.

Its arguments, --help among them, are that program's own: `neojac node --help` is its help.

| Example | What it does |
|---|---|
| `neojac node server.mjs` |  |

Its guide: [interop/npm](../interop/npm.md) (`neojac docs interop/npm`).

### `neojac cc`, `neojac c++`, `neojac clang`, `neojac clang++`, `neojac ar`, `neojac ranlib`, `neojac dlltool`, `neojac lib`, `neojac ld.lld`, `neojac ld64.lld`, `neojac lld-link`, `neojac wasm-ld`, `neojac objcopy`

Compile and link C and C++ with neojac's Clang and LLD.

```sh
neojac cc|c++ [-target <triple>] <clang argument>...
neojac clang|clang++|ar|ranlib|dlltool|lib <argument>...
neojac ld.lld|ld64.lld|lld-link|wasm-ld <argument>...
neojac objcopy --strip-debug|--discard-all|--strip-all <file>
```

The C toolchain neojac builds programs with, under its tools' own command lines. cc and c++ compile for any platform neojac builds for (-target), with that platform's C library and headers.

Its arguments, --help among them, are that program's own: `neojac cc --help` is its help.

| Example | What it does |
|---|---|
| `neojac cc -O2 hello.c -o hello` |  |
| `neojac cc -target aarch64-linux-gnu hello.c -o hello` |  |

Its guide: [interop/c-and-cpp](../interop/c-and-cpp.md) (`neojac docs interop/c-and-cpp`).

### `neojac cargo`, `neojac rustc`, `neojac rustdoc`

Build Rust with neojac's Rust toolchain.

```sh
neojac cargo|rustc|rustdoc [<argument>...]
```

The Rust toolchain neojac carries, built against neojac's own LLVM and linking every target through `neojac cc`. A target's standard library is fetched the first time a build names it.

In a project whose crates are tables of jac.toml, `neojac cargo` writes their Cargo.toml and Cargo.lock first, and jac.toml and jac.lock take what cargo changed as it ends.

Its arguments, --help among them, are that program's own: `neojac cargo --help` is its help.

| Example | What it does |
|---|---|
| `neojac cargo build --release` |  |

Its guide: [interop/rust](../interop/rust.md) (`neojac docs interop/rust`).

## Inspect

### `neojac lsp`

Serve an editor over the Language Server Protocol.

```sh
neojac lsp
```

An editor starts it and speaks the Language Server Protocol to it. It checks the programs the open files belong to as they are edited, with what is unsaved, and answers the editor from what the checks found.

| Example | What it does |
|---|---|
| `neojac lsp` | What an editor is configured to run |

Its guide: [toolchain/lsp](../toolchain/lsp.md) (`neojac docs toolchain/lsp`).

### `neojac query`

Ask what the language server answers, from the command line.

```sh
neojac query <what> <file>[:<line>[:<column>]]
neojac query index <program> [--no-lint]
```

| Option | What it does |
|---|---|
| `--no-lint` | index: the program as an editor that has turned the lint rules off is told of it |

<what> is one of definition, declaration, implementation, type, references, hover, symbols, completion, signature, diagnostics and arch. The file is checked as the language server checks it, in the program it belongs to, and the answer is printed: places as <file>:<line>:<column>-<line>:<column>, one to a line.

`arch` prints, as JSON, the architecture picture the file is in, as `neojac arch --json` does: a module's file gives its module, the line of a layer in archwire.jac that layer, and anywhere else there the project.

`index` prints, as JSON, what the language server keeps of a whole program for the answers that reach across programs: its files, the diagnostics of each, the names it declares, and every reference by what it refers to. The program is its main module, or `archwire.jac#<space>` for a space of a project. The language server runs it for each program of a workspace, several at a time, and keeps what it prints in the build cache.

| Example | What it does |
|---|---|
| `neojac query definition main.jac:12:9` | Where what is at 12:9 is defined |
| `neojac query references core/clock.jac:3:5` | Every use of it in its program |
| `neojac query symbols main.jac` | The file's outline |
| `neojac query arch core/clock.jac` | What the module takes and gives |
| `neojac query index main.jac` | A program's index, as JSON |

Its guide: [toolchain/lsp](../toolchain/lsp.md) (`neojac docs toolchain/lsp`).

### `neojac browse`

Drive a browser: open a page, read it, act on it.

```sh
neojac browse open <url> [--no-sandbox] [--chrome <path>]
neojac browse open <url> --cdp <address>
neojac browse back | forward | reload | close [--all]
neojac browse snapshot [-i]
neojac browse click | dblclick | hover | focus <element>
neojac browse check | uncheck | scrollintoview <element>
neojac browse fill | type <element> <text>
neojac browse select <element> <option>...
neojac browse upload <element> <file>...
neojac browse press | keydown | keyup <key>
neojac browse scroll <up | down | left | right> [<pixels>]
neojac browse mouse move <x> <y> | wheel <dy> [<dx>]
neojac browse mouse down | up [<button>]
neojac browse get title | url | text [<element>] | html [<element>]
neojac browse get value | box <element> | count <selector>
neojac browse get attr <element> <name>
neojac browse is visible | enabled | checked <element>
neojac browse eval <javascript>
neojac browse wait <element> | <milliseconds> | --text <text>
neojac browse wait --url <pattern> | --load <state> | --fn <javascript>
neojac browse console | errors [--clear]
neojac browse network requests [--filter <text>] [--clear]
neojac browse cookies [set <name> <value> | clear]
neojac browse storage <local | session> [<key> | clear]
neojac browse storage <local | session> set <key> <value>
neojac browse state save | load <file>
neojac browse tab [new [<url>] | <number> | close [<number>]]
neojac browse frame <element> | main
neojac browse dialog [accept [<text>] | dismiss]
neojac browse set viewport <width> <height>
neojac browse screenshot [<file>] [--full]
neojac browse pdf <file>
neojac browse session list
neojac browse serve [--no-sandbox] [--chrome <path> | --cdp <address>]
```

| Option | What it does |
|---|---|
| `--session <name>` | The session a command is for (default: NEOJAC_BROWSE_SESSION, else default) |
| `--timeout <seconds>` | How long a command waits for what it needs (default: 10, and 30 for a page to load) |
| `--chrome <path>` | Start this browser, a Chrome or Chromium, in place of the one neojac fetches |
| `--cdp <address>` | Attach to a browser that is running, by its debugger's address |
| `--no-sandbox` | Start the browser without its sandbox |
| `-i` | snapshot: only what can be acted on, with its refs |
| `--full` | screenshot: the whole page, not only the window |
| `--clear` | console, errors, network requests: forget what was kept |
| `--all` | close: every session |
| `--text <text>` | wait: until the page's text holds this |
| `--url <address>` | wait: until the page's address matches this pattern; cookies set: the site the cookie is for |
| `--load <state>` | wait: until the page has reached load, domcontentloaded or networkidle |
| `--fn <javascript>` | wait: until this expression is true |
| `--filter <text>` | network requests: only those whose address holds this |
| `--domain <domain>` | cookies set: the site the cookie is for |
| `--path <path>` | cookies set: the path the cookie is sent for |
| `--expires <seconds>` | cookies set: when the cookie ends, in seconds since 1970 |
| `--samesite <mode>` | cookies set: Strict, Lax or None |
| `--secure` | cookies set: sent only over HTTPS |
| `--httponly` | cookies set: kept from the page's scripts |

A session is a browser a background process holds: `open` starts one, the commands after it act on its page, and `close` ends it. The browser is Chrome's headless shell, which neojac fetches the first time and keeps beside its build cache; nothing is installed.

`snapshot` prints the page as its accessibility outline, each thing that can be acted on with a ref (`[ref=e3]`). An <element> is a ref of the last snapshot, written `@e3`, or a CSS selector. A command that acts on an element waits until it is visible, enabled, still, and not covered, then sends the browser real input.

| Example | What it does |
|---|---|
| `neojac browse open localhost:8000` | Start a session at a page |
| `neojac browse snapshot -i` | What can be acted on, with refs |
| `neojac browse click @e5` | Click an element by its ref |
| `neojac browse fill '#email' ann@example.com` | Fill a field |
| `neojac browse wait --text Welcome` | Wait for text to appear |
| `neojac browse screenshot page.png` | Save what the window shows |
| `neojac browse close` | End the session |

Its guide: [toolchain/browse](../toolchain/browse.md) (`neojac docs toolchain/browse`).

### `neojac arch`

Draw a project's architecture from its archwire.jac.

```sh
neojac arch [<layer> | <module>] [--mermaid | --json | --text]
neojac arch [<layer> | <module>] --svg <file> | --png <file>
neojac arch --view spaces [--profile <profile>] [<output>]
neojac arch [<layer> | <module>] --diff [--base <revision>] [<output>]
neojac arch [<layer> | <module>] --at <revision> [--diff] [<output>]
neojac arch --steps [--json]
```

| Option | What it does |
|---|---|
| `--view <view>` | layers (the default), or spaces: the spaces on their hosts, the apps that run and serve them, and the crossings between them |
| `--profile <profile>` | The spaces view as the archwire's profile of that name arranges it |
| `--mermaid` | Print the picture as a Mermaid flowchart |
| `--json` | Print the picture's content: its boxes, its arrows, the names each wire carries and where it is written |
| `--text` | Print the picture on the terminal |
| `--svg <file>` | Write the picture as an SVG |
| `--png <file>` | Write the picture as a PNG, drawn by the browser `neojac browse` drives |
| `--diff` | Mark what has changed since the branch this one follows: the modules whose files changed, the arrows that are new, gone or carry other names, and what takes from what changed |
| `--base <revision>` | --diff against this git revision, in place of where the branch left its upstream (or origin's main branch) |
| `--at <revision>` | The project's architecture as it stood at this git revision, in place of as it stands; with --diff, what changed from the base up to it |
| `--steps` | Print the steps of the project's history the viewer's slider goes through: where the branch began, each commit since, each turn of an agent, and the project as it stands when that is different |
| `--listen <address>` | Where the viewer is served (default: 127.0.0.1:8090) |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Run from inside a project. The picture is drawn from archwire.jac and from nothing else: its layers are the boxes, its wires the arrows, each labelled with the edge rule that admits it.

With no output option, the picture is served as a page that follows the project as it is edited: its address is printed, a click on a layer or a module opens it, a click on an arrow lists the names it carries, and a module opened shows its code beside the picture. An output option prints one picture and exits, and refuses a project whose wiring has errors: it prints them and writes nothing.

Every module archwire.jac names is read, whether or not a program loads it, and every target's wires are checked, so what is drawn holds for the whole project.

| Example | What it does |
|---|---|
| `neojac arch` | Serve the project's picture |
| `neojac arch --text` | Print it on the terminal |
| `neojac arch backends --text` | One layer, opened |
| `neojac arch compiler.gen --json` | One module: what it takes and gives |
| `neojac arch --mermaid` | A flowchart for a README or a pull request |
| `neojac arch --diff --mermaid` | What a branch changes, for its pull request |
| `neojac arch --view spaces --svg spaces.svg` | The spaces, as a file |

Its guide: [toolchain/arch](../toolchain/arch.md) (`neojac docs toolchain/arch`).

### `neojac turns`

Serve a client a session of work with an agent, over JSON-RPC.

```sh
neojac turns [--project <directory>] [--base <revision>]
neojac turns --schema
```

| Option | What it does |
|---|---|
| `--project <directory>` | The project the session is in (default: the directory it is started in) |
| `--base <revision>` | What the project's steps and changes are counted from, in place of where the branch left its upstream |
| `--schema` | Print the protocol as JSON: its version, each method with its parameters, and each event with its fields |

A client starts it in a project and speaks JSON-RPC 2.0 to it, one message a line, on its standard input and output. It is what `neojac arch` is made on: the client asks for a turn of an agent, answers what the agent asks to do, stops or undoes a turn, plans a change and builds it, and is sent each thing that happens as a `session/event`. The same methods answer about the project: its picture, what changed between two revisions, and the steps of its history.

The protocol has a version, and --schema prints it. The session's log, in the project's `.jac/arch/`, is its events as they were sent.

| Example | What it does |
|---|---|
| `neojac turns` | What a client is configured to run, in a project |
| `neojac turns --schema` | The methods and the events |

Its guide: [toolchain/turns](../toolchain/turns.md) (`neojac docs toolchain/turns`).

### `neojac mcp`

Serve an agent the project as tools, over the Model Context Protocol.

```sh
neojac mcp [--project <directory>]
```

| Option | What it does |
|---|---|
| `--project <directory>` | The project the tools answer about (default: the directory it is started in) |

An agent starts it and speaks the Model Context Protocol to it, on its standard input and output. Its tools answer about the project: `architecture` is the picture `neojac arch` draws, as its boxes and its arrows with the names each wire carries; `find` says where a layer, a module or a wired name is; `changes` says what has changed since a revision; `check` checks the project; `symbols` lists what a file declares; `docs` prints the documentation.

`neojac arch` gives it to the agent it works with. Any other agent or editor that takes an MCP server is given the command `neojac mcp`.

| Example | What it does |
|---|---|
| `neojac mcp` | What an agent is configured to run, in a project |

Its guide: [toolchain/arch](../toolchain/arch.md) (`neojac docs toolchain/arch`).

### `neojac agent`

Add the coding agents `neojac arch` works with, or list them.

```sh
neojac agent [--json]
neojac agent add <name> [--env <NAME>[=<value>]]... [-- <command>...]
neojac agent use <name>
neojac agent remove <name>
neojac agent registry [<word>] [--json]
```

| Option | What it does |
|---|---|
| `--env <NAME>[=<value>]` | A variable of the agent's environment, such as its API key; without a value, the one this environment has |
| `--json` | Print the agents added, or what the registry has, as JSON; a variable is listed by its name, never with its value |
| `-- <command>...` | The agent is this command, which speaks the Agent Client Protocol on its standard input and output, in place of one the ACP registry names |

An agent is a program that speaks the Agent Client Protocol: `neojac arch` starts it in the project, sends it what is asked for in the viewer, and shows what it does on the picture. add takes one the ACP registry lists by its name there, fetched and checked against the digest the registry pins, or a command of your own after `--`. With no command, agent lists the ones that are added, the one in use marked.

An agent signs in by itself and keeps its own credentials. One that takes a key from its environment is given it with --env; the agents and their variables are kept in a file only you can read, in neojac's configuration directory, never in the project.

| Example | What it does |
|---|---|
| `neojac agent registry claude` | What the registry has by that word |
| `neojac agent add claude-acp --env ANTHROPIC_API_KEY` | Add one from the registry, with the key this shell has |
| `neojac agent add mine -- ./my-agent --acp` | Add a command of your own |
| `neojac agent use mine` | Work with that one |

Its guide: [toolchain/arch](../toolchain/arch.md) (`neojac docs toolchain/arch`).

### `neojac parse`

Check that files parse, or print their syntax trees.

```sh
neojac parse [--tree] <file.jac | @list>...
```

| Option | What it does |
|---|---|
| `--tree` | Print each file's syntax tree |
| `@<list>` | A file naming the files to parse, one to a line |

Its guide: [toolchain/inspect](../toolchain/inspect.md) (`neojac docs toolchain/inspect`).

### `neojac grammar`

Print the grammar a parser implements.

```sh
neojac grammar <parser.jac> [--page] [-o <file>]
```

| Option | What it does |
|---|---|
| `-o <file>` | Write it to a file |
| `--page` | Print it as the documentation's page of it (docs/reference/grammar.md) |

Reads the grammar out of a parser's source (neojac's own is compiler/parsing/parser.jac), as compiler/parsing/jac.spec records it.

Its guide: [toolchain/inspect](../toolchain/inspect.md) (`neojac docs toolchain/inspect`).

### `neojac emit-js`, `neojac emit-py`

Write a space's JavaScript, or its Python code.

```sh
neojac emit-js <space> -o <dir> [<option>...]
neojac emit-py <space> -o <dir> [--app <app> [<option>...]]
```

| Option | What it does |
|---|---|
| `-o <dir>` | The directory to write |
| `--app <app>` | The space as that app's program of it, with its plan |
| `--profile <profile>` | The app under that profile |
| `--place <directory>` | The app for the place in that directory |
| `--laid` | emit-js: each source map names its Jac source at the source's project path under <dir>, where a laid npm tree links it, not in the project itself |
| `--package <directory>` | emit-js: a browser space of the package in that directory, by its own archwire and jac.toml, as an app of this project that loads the package builds it |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Run from a project's root: the modules of one space of its archwire, checked and written as an app's build would write them. emit-js is for a space on a JavaScript host (browser, node, hermes), emit-py for one on cpython.

Its guide: [toolchain/inspect](../toolchain/inspect.md) (`neojac docs toolchain/inspect`).

## About neojac

### `neojac help`

List the commands, or say what one takes.

```sh
neojac help [<command>]
neojac help --markdown
```

| Option | What it does |
|---|---|
| `--markdown` | Print every command's help as one Markdown page (docs/reference/commands.md) |

`neojac <command> --help` says the same of a command as `neojac help <command>`.

### `neojac version`

Name the release neojac is installed from.

```sh
neojac version
```

Prints the release's version, the platform it runs on and the commit it was built from; `neojac --version` and `neojac -V` do the same. A neojac built from source says so.

### `neojac update`

Replace neojac with a newer release of itself.

```sh
neojac update
neojac update <version>
neojac update on
neojac update off
```

Alone, fetches the newest release where it is newer than this neojac; with a version, that release, older or newer, which neojac then stays at. The release is checked against its digest, then builds and runs a program before it is kept. It takes this neojac's place whole, by one rename, when no other command of this neojac is running: at once, or else when the next command starts with none running, which says so and runs as the new release. A release that fails any of that changes nothing.

A neojac that follows the releases does this by itself: a build, a test run, an install or `neojac dev` asks for the newest release at most once a day, and fetches a newer one alongside its work, waiting for nothing. The installer's neojac follows them unless it was installed with --version. `on` makes this neojac the one that follows, and `off` leaves it as it is until `neojac update` is run. NEOJAC_UPDATE=off keeps a run from asking and from being replaced, and so does CI. A neojac built from source has no release, and none of this.

| Example | What it does |
|---|---|
| `neojac update` | Take the newest release |
| `neojac update 0.5.3` | Take that release, and stay at it |
| `neojac update off` | Stay at this release until asked |

Its guide: [toolchain/update](../toolchain/update.md) (`neojac docs toolchain/update`).

### `neojac telemetry`

Show what neojac records of its use, or turn it off.

```sh
neojac telemetry
neojac telemetry off
neojac telemetry on
```

A release of neojac counts what it is used for: the commands run, how long each took and whether it failed, the options each was given by name, the codes of the diagnostics they reported, the kinds of program built and the platforms they were built for, and where in neojac an internal error was raised. Nothing a command was given, a file's name or its source among it, is recorded. A week's counts are one report, with a random ID made for that week; the first run on a machine says so on stderr.

A week's report is sent as it stands, at most once a day, while the week goes on and once more when it has ended, to telemetry.neojac.dev (or where NEOJAC_TELEMETRY_URL says): by a build, a test run, an install or `neojac dev`, alongside its work. It waits for nothing and gives up after 5 seconds, and the collector keeps a week's latest report. Once the collector has all of an ended week, its records are deleted; a week is kept four weeks at most.

Alone, says whether recording is on and what decided that, then prints what is recorded: each week's report as it stands, as it is sent, with when it was last sent and tried and when it is sent next. `off` stops recording and deletes what is recorded; `on` starts it again. NEOJAC_TELEMETRY=off or DO_NOT_TRACK=1 keeps it off wherever it is set, and a neojac built from source records nothing until `neojac telemetry on`.

| Example | What it does |
|---|---|
| `neojac telemetry` | What is recorded on this machine |
| `neojac telemetry off` | Stop recording, and delete what is recorded |

Its guide: [toolchain/telemetry](../toolchain/telemetry.md) (`neojac docs toolchain/telemetry`).
