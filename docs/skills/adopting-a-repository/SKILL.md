---
name: adopting-a-repository
description: Use when a repository written in Python, JavaScript, TypeScript, Rust, C or C++ is to become a neojac project as it stands - neojac absorb --check, what it takes and what it leaves as data, the archwire it writes, and each kind of open item with what closes it and what proves it.
---
# Adopting a repository

## When to use this

Use it when a repository that neojac did not make is to become a neojac project: its manifests
held by `jac.toml`, its files wired in `archwire.jac`, and no source file changed.

- Translating its source into Jac comes after, a module at a time, in the order
  `neojac port --check` plans: `porting-from-python`, and `neojac docs toolchain/port`.
- Adding a package to a project that is already neojac's is `using-npm-packages` or
  `using-python-packages`, not this.

## Before you start

```sh
neojac docs toolchain/packages     # jac.toml's tables, and the section on neojac absorb
neojac docs toolchain/projects     # what a project is, and what is not its source
neojac docs modules-wiring         # wires, and how a file in another language declares one
```

**The tools do the work, and you close the open items.** `neojac absorb` takes every manifest its
own engines read, and writes every wire. Never write a table it could have written, and never
edit `archwire.jac`'s wires by hand: `neojac fmt --fix archwire.jac` writes them from the
sources. What is yours is each fact no manifest states.

**Never write `human_mode = true` in the `jac.toml` absorb writes, nor `kind = "fixtures"`.** The
project keeps the rules every project keeps. If a `jac.toml` already there says
`human_mode = true`, remove it and the `[check.lint]` `ignore` and `exclude` it allowed, run
`neojac fmt --fix .` at the root and `neojac check` on its programs, and fix by hand what is left.

Work in a clean checkout, so that `git status` shows exactly what a step changed.

## Steps

1. **Look before anything is written.**

```sh
neojac absorb --check              # for a person
neojac absorb --check --json       # for a program: trees, data, open
```

Read three things in what it prints:

- **The trees.** Each manifest that is the project's, and the table it becomes. If one you
  expected is missing, its ecosystem's own workspace does not name it: fix that in the
  repository's manifest (a root's `workspaces`, `[tool.uv.workspace]`, cargo's `[workspace]`),
  not in `jac.toml`.
- **The data.** Directories whose manifest no workspace names: fixtures, templates. Nothing under
  them becomes a module. If one of them is real source, it is a workspace member the root does
  not list.
- **The open items**, each at its file.

2. **Take it in.**

```sh
neojac absorb
git status --short
```

It writes `jac.toml`, `jac.lock` where a lock neojac's engines read was there, `archwire.jac`, and
the lines of `.gitignore` for the manifests it now writes. Each manifest is the same bytes as
before, so `git diff` on one shows nothing, with two exceptions it tells you of: a
`package.json` whose `pnpm.overrides` it rewrote as npm's (listed under `rewritten`), and one
with a `workspace:` link, which npm is given as a range. If a step fails, every file is as it was.

3. **Read what stands between the archwire and a check that passes.** `absorb` prints the
   diagnostics every command would give and exits 1 when there are any. Each is at a wire or at
   a source's import.

| Diagnostic | Usually means |
|---|---|
| E1145 at a wire, `module 'pkg' has no '_ext'` | The source imports a module no file of the project is, in a project with a `[wheel]` table: an extension module a build makes that no table names. Before the project is recorded such an import is no error: absorb exits 0, and the project's `build` item stands for it. `neojac absorb --record` finds which crate it is linked from and writes `[extensions."pkg/_ext"]`; for one it does not take, write the table (`neojac docs toolchain/packages`, "Extension modules") and absorb again |
| E2224 | Two files of one name and two languages in one directory |
| E1575, E1147 | A wire and a source that disagree: `neojac fmt --fix archwire.jac` |

4. **Close each open item**, one at a time, and check after each.

| Kind | What it is | What closes it today |
|---|---|---|
| `lock` | Another tool's lock (`uv.lock`, `bun.lock`, `pnpm-lock.yaml`) | `neojac install`, which holds pip to a `uv.lock`'s pins (building from source a pin with no wheel for neojac's CPython) and npm to a `pnpm-lock.yaml`'s or a `bun.lock`'s. It removes the tree's `node_modules` to do so, and needs the network. Then `neojac absorb --check`: its `locks` lines count the pins reproduced, and the item names each one that was not, with the version installed. Say why each differs (for pip, the log the install named, `.jac/pins/<name>-<version>.log`; for npm, a peer its range does not admit, or one range given two versions); accept one only when the user agrees, in `jac.toml`'s `[lock.pypi]` or `[lock.npm]`, `accept = ["<name>"]`. Keep the file until the item is closed. A lock of another tool (`poetry.lock`, `yarn.lock`) is not read: keep it and report it. Once nothing of a lock is open, `neojac absorb` moves it to `replaced-by-neojac/` |
| `form` | A manifest form npm does not read and neojac does not rewrite (`pnpm-workspace.yaml`, `pnpm.packageExtensions`) | Do not hand-edit the table to make npm take it: say what you found. `pnpm.overrides` and `workspace:` links are no open item: absorb rewrites the first, and prints what it rewrote, and `jac.toml` keeps the second as written |
| `build` | A program that builds native code (`setup.py`, an in-tree build backend, `binding.gyp`), or a Python project that builds a wheel no record has said the files of yet: no space holds its Python until one does | For a Python project: `neojac absorb --record`, which runs the build and writes `[extensions."<path>"]` for a module linked from a crate or from C, with the C module's table, and `[wheel."<directory>"]`, what the project's wheel holds. For an npm tree with a `binding.gyp`: `neojac install`, then `neojac absorb --record`, which runs npm's node-gyp and writes each addon the same way, with the C module of every library it links. A record is of the platform it runs on, which each extension module lists (`recorded = ["macos-aarch64"]`): run it again on every other platform the project is built for, and it adds that platform's record to the same tables. Start each platform from a clean clone with `jac.toml`, `jac.lock` and `archwire.jac` carried over: what one system's build left behind (`build/`, `.jac/`) is not the next one's. On Linux an npm tree's record needs `make`. A build on a platform that is not recorded is refused (E5172); do not edit `recorded` to pass it. It says what of a build a table cannot hold: leave those programs in place and report what it said. A record that says all the build made moves the build's own files (`setup.py`, `MANIFEST.in`, `binding.gyp` and every other gyp file gyp loaded) to `replaced-by-neojac/`, and a later record puts them back for its run |
| `tests` | No manifest says how a Python project's tests are run (absorb writes `[test.pypi."<directory>"]` itself from a `[tool.cibuildwheel] test-command`, or as `pytest --import-mode=append` for a project that configures pytest or holds a `conftest.py` in its directory or one down, with the one dependency group that names it; and an npm tree's `[test.npm."<directory>"]` from its `test` script), or several dependency groups name pytest, or none does | Write `[test.pypi."<directory>"]` (below), from the command the repository itself uses: its CI, its `Makefile`; or its `groups`, the one the tests need |

An item neojac cannot close yet is reported, not worked around. Changing a manifest so that a
tool stops complaining changes what the repository builds.

5. **Say how each tree's tests are run**, and run them. A tree is tested only where `jac.toml`
   names its suite.

```toml
[test.pypi."."]                    # a Python project: its command
command = ["pytest", "tests", "--import-mode=append"]
groups = ["test"]                  # the [dependency-groups] the command needs

[test.npm."."]                     # an npm tree: a script of its package.json
script = "test"

[test.cargo."."]                   # a crate: neojac cargo test

[install.pypi."."]                 # what install adds beyond the dependencies, tested or not
groups = ["dev"]                   # absorb writes uv's default groups where a uv.lock describes it
extras = ["blobfile"]
```

```sh
neojac absorb --record             # every Python project: what its wheel holds, [wheel]
neojac install                     # its dependencies, and the groups and extras the tables name
neojac test                        # builds the project from the tables, then runs the command
```

- **Record every Python project**, one with no native code too: `neojac build` and
  `neojac test` need its `[wheel."<directory>"]`, and refuse without it (E5167).
- **The suite runs against the build**, not against the package's directory beside the tests,
  which holds no extension module. Where the tests' directory has an `__init__.py`, pytest puts
  the project's directory first on Python's path unless it is told `--import-mode=append` (or
  `importlib`): give it that.
- **What the tests need that no group or extra lists** (`pytest` and `hypothesis`, where a
  project names them only in its `[tool.cibuildwheel]`) goes in `[dependencies.pypi]`:
  `neojac install --pypi pytest hypothesis`.
- **A test group's package that depends on the project itself** takes the project as neojac
  builds it: `install` gives pip the repository's own Python projects as installed, so no
  release of the project is fetched beside it and `jac.lock` pins none.
- **A Python tree that ships no wheel** (a uv workspace's root, with no `[project]` table) is
  no Python project to record: its own scripts and hooks are a `<dir>_dev` cpython space absorb
  declares, and they are checked there, as Python.
- **An npm tree's addon is built from its recorded tables** before its suite runs: record it
  first (`neojac install`, then `neojac absorb --record`). Leave a script that needs a tool
  neojac does not ship (`bun`, `turbo`) unnamed, and report it.
- **Compare with the repository's own run.** The bar is the same tests passing. A test that
  fails the same way under the repository's own tools on this machine is not yours to fix:
  report it, and deselect it in the command only if the repository's own run does.
- **Programs the tests start** (`sysctl`, `ifconfig`) must be on `PATH` as they are for the
  repository's own run.

6. **Build what it publishes.**

```sh
neojac build                       # dist/<name>-<version>-<tags>.whl
```

`neojac absorb --record` declared, in `archwire.jac`, a `cpython` space that holds each Python
project and a `package` that ships it, named for the project. The wheel holds the files the
repository's own wheel does (`.jac/absorb/*/dist/` has that one, to compare), but for files only
its build backend writes into the metadata directory (setuptools' `top_level.txt`).

7. **Draw it.**

```sh
neojac arch --text
```

## When the repository is to stay on neojac

Only once every step above holds, and only where the maintainers mean neojac to be the build
from now on:

```sh
git rm --cached pyproject.toml Cargo.toml     # the command absorb printed: neojac writes these now
git add -A                                    # the moves into replaced-by-neojac/
```

absorb has already moved what `jac.toml`, `jac.lock` and the record stand in for into
`replaced-by-neojac/`: each manifest as it stood, the build's own files (`setup.py`,
`MANIFEST.in`, `binding.gyp` and the gyp files it loads) once a record said all the build made, and another tool's lock once
each of its pins was reproduced or accepted.

- **Untrack a manifest; do not delete it.** npm, pip and cargo still read it, and neojac writes
  it again in a fresh clone.
- **Commit the folder, and delete it only when every platform the project is built for is
  recorded.** A record is of one platform, and the build's own files are the only description of
  the others until then: `neojac absorb --record` on another platform puts them back from the
  folder for its run. The `recorded` lists of `[extensions]` say which platforms are.
- **A file that did not move is not replaced yet.** Its open item says what is left: a pin to
  accept, a build the record could not say whole.
- **Prove it from a fresh clone** of the commit: `neojac install --frozen`, `neojac build`,
  `neojac test`, with the same tests passing.
- **Say what the repository gives up**: an install from its source by pip or npm, and tools
  that read its manifests without neojac.

## Porting it to Jac, after

Once the project is adopted and its tests pass on neojac, its source can move to Jac a module at a
time, each step leaving a project that builds:

```sh
neojac port --check                # what would port, what is refused, and the plan
neojac port shop/mathx.py          # one module: its Jac, the source to replaced-by-neojac/, its wires
neojac test                        # the same tests passing, after each step
```

Port in the plan's order: each module after the modules of the project it imports. Each port is
one change, made only if the project then checks (E4008), and a C file the rest of its C module
still calls is called through the header beside its Jac, a C function defined with `...`
included. Commit after each step. A port that was killed leaves
its change journalled, and `check` and `build` refuse the project (E4013) until the next
`neojac port` in it undoes the change. An npm tree's own suite keeps running after a file of it is
Jac: `neojac test` runs its script on what the tree's space emits, where a forwarder stands in
each ported file's place.

## What a correct result looks like

- `neojac absorb --check` and `neojac absorb` name the same trees.
- `git status --short` shows `.gitignore` modified and `jac.toml`, `archwire.jac` (and `jac.lock`)
  new, and nothing else.
- `neojac test` passes the tests the repository's own run passes, for each Python project.
- A second `neojac absorb` prints `nothing changed`.
- `neojac arch --text` draws the project, with one layer, `all`.
- Every open item is either closed, or listed in your report with what the repository says
  about it.

## Mistakes to expect

| Symptom | Means | Fix |
|---|---|---|
| `absorb: ... holds no manifest to take into jac.toml` | No `package.json`, `pyproject.toml`, `Cargo.toml` or `cmodule.toml` in the directory or under it | Run it at the repository's root |
| The tables landed in a `jac.toml` above the repository | A `jac.toml` above it made that directory the project | Run it in a checkout that is under no other project |
| A fixture's files show up as modules | Its directory holds no manifest, so nothing marks it as data | Add it to `[project] exclude` in `jac.toml` |
| E5156 `... is null` | A `package.json` holds a `null`, which TOML has no value for | Take the `null` out of the manifest: npm reads an absent key the same way |
| E5157 | A manifest's text cannot be moved under a table's name as it is | Reformat that part of the manifest as plain tables |
| `cargo cannot read it` | `cargo metadata` refused the `Cargo.toml` | Fix what cargo says: neojac asks cargo which crates are the workspace's |
| After `--record` on macOS: `'IOKit/IOKitLib.h' file not found` at a C module's `cmodule.toml` | The C uses a framework the toolchain carries no headers of | Set `SDKROOT` to a macOS SDK, for every command in the project (`neojac docs interop/c-and-cpp`) |
| `--record` says `no run that was recorded linked it` | The build found the module already made, from before any record was kept | Remove what the build left in the repository (`build/`, `target/`) and record again |
| The suite fails with `cannot import name '_ext' from 'pkg'`, at a path in the repository | Python imported the package's directory, not the build | `--import-mode=append` for pytest; a test that starts `python -m` in the repository needs the build to hold that module |
| E5167 | A Python project has no `[wheel."<directory>"]` | `neojac absorb --record` |
