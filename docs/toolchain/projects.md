---
description: What makes a directory a project (jac.toml and archwire.jac), a project of fixtures, how its files are laid out (impl and test annexes, the notes annexes [fmt] notes = true keeps, variants), the .jac/ and dist/ directories neojac writes, and what neojac shows while it works, on a terminal and off one.
keywords: project, project root, .jac, dist, status line, progress, color, fixtures
---
# Projects

A project is a directory of Jac modules with a `jac.toml` at its top and an `archwire.jac` that wires them. The directory holding `jac.toml` is the project's root: where neojac reads the project's settings, where imports stop climbing, where tests are found from, and where neojac keeps what it makes for the project.

```text
shop/
    jac.toml
    archwire.jac
    main.jac
    cart.jac
    impl/
        cart.impl.jac
    test/
        cart.test.jac
```

```toml
[project]
name = "shop"

[test]
directories = ["."]
```

```sh
cd shop
neojac check main.jac
neojac build main.jac -o shop
neojac test
neojac fmt .
```

## The project's root

For a program, the root is the nearest directory at or above the main module's that holds a `jac.toml`, wherever neojac is run from. `neojac build app/main.jac -o x` and `cd app && neojac build main.jac -o x` read the same `jac.toml`. A main module with no `jac.toml` above it is a project of its own directory, with no settings.

The root decides:

| What | How |
|---|---|
| Settings | `jac.toml` is read from the root: the memory profile, lint rules, test directories, `fmt`'s exclusions, Python packages ([jac.toml](../reference/jac-toml.md)) |
| Imports | `import x` looks for `x.jac` beside the importing file, then in each directory above it up to the root ([Modules](../language/modules.md#how-a-module-is-found)) |
| Lint rules | The rules the project keeps judge the modules under the root ([Lint rules](lint.md#which-files-the-rules-judge)) |
| What neojac makes | It goes in `.jac/` at the root (below) |

`neojac test` with no paths finds the root from the current directory instead, and `neojac fmt` from each directory it is given: the nearest directory at or above it with a `jac.toml`.

`jac.toml` may be as short as one line, or empty. neojac reads only the tables it knows and ignores the rest, so the same file can hold settings for other tools.

## archwire.jac

`archwire.jac` is the project's wiring, in Jac:

- its `graph layers` block groups the project's modules into layers, and every module is in one ([Layers](../language/modules-layers.md));
- its `graph import` blocks declare which modules import what from which, and which layers may feed which ([Import wiring](../language/modules-wiring.md));
- its `graph spaces` block declares the project's spaces (where code runs: native, CPython, Node, a browser), its apps and its profiles ([Archwire](../apps/archwire.md)).

An `archwire.jac` governs the modules in its directory and below, up to the root. The commands that work on spaces and apps (`neojac build`, `neojac run` and `neojac check` with an app's name or `--space`, `neojac emit-js`, `neojac emit-py`) run from the directory that holds it, and refuse to run anywhere else:

```text
neojac: `neojac emit-py` writes a space of the project in this directory, and there is no archwire.jac here
```

Every project has one, but a [project of fixtures](#a-project-of-fixtures). Each command judges it whole, as [`neojac arch`](arch.md) does: every module under it is in a layer, whether the program at hand loads the module or not, and every import between the project's files, in Jac and in Python, JavaScript, TypeScript, Rust, C and C++, is a wire it declares ([Import wiring](../language/modules-wiring.md#what-a-command-judges)). A module of a project that no `archwire.jac` governs is refused, once for the project, at its `jac.toml`:

```text
jac.toml:1:1: error[E2231]: 'main.jac' is a module of the project 'shop', and no archwire.jac governs it: a project puts each of its modules in a layer and states their imports of each other as wires in one, at its root
```

A [library](packages.md#jac-packages) and a [plugin](../apps/plugins.md) are projects too, and each has its own.

The smallest `archwire.jac` names a layer for the project's modules:

<!-- example: not checked: a graph layers block is valid only in a file named archwire.jac, beside the modules it groups -->
```jac
graph layers {
    layer shop { main | cart; }
}
```

A directory with no `jac.toml` is not a project, and a program in one needs neither file. No
[lint rule](lint.md#which-files-the-rules-judge) judges it.

### A project of fixtures

`kind = "fixtures"` under `[project]` says the project's programs are written to exercise a
compiler: a compiler's test corpus, programs that must fail to compile.

```toml
[project]
name = "corpus"
kind = "fixtures"
```

- It needs no `archwire.jac`. Its modules that none governs write their own `import` statements, of each other too, and nothing judges which imports which.
- An `archwire.jac` in one of its directories still governs that directory and what is below it.
- No lint rule judges it but those its `[check.lint] select` names ([Lint rules](lint.md#a-project-of-fixtures)).
- It is neither a library nor a plugin, so no project declares it as a package.

### What is not the project's source

Every file under an `archwire.jac` in a language whose imports are wires is a module of the project, and one that no layer names is an error (E2201). Some of what sits in a project's tree is not its source, and neojac leaves it out:

| Left out | Why |
|---|---|
| A file or directory whose name begins with `.` | `.jac/`, `.git/`, an editor's settings |
| `node_modules/`, `eco/`, `target/`, `dist/` | What neojac and the ecosystems' tools write |
| A directory that holds an `@jac` directory | An emitted space's modules ([`neojac emit-js`](../reference/commands.md)) |
| A directory with an `archwire.jac` or a `jac.toml` of its own | That archwire governs it, or it is a project of its own |
| A crate or C module that `jac.toml` does not hold | A dependency: one module, its files its own business ([Rust modules](../interop/rust-modules.md), [C modules](../interop/c-modules.md)) |
| A path `exclude` under `[project]` names | Yours to say: a directory of `.jac` files a site shows as text, which no space's pattern should hold and nothing should check. [`neojac absorb`](packages.md#taking-in-a-repository-neojac-absorb) lists there each directory whose manifest no workspace names, and what git ignores |

```toml
[project]
name = "shop"
exclude = ["build/*", "scripts/bench/*"]
```

`exclude` is a list of fnmatch patterns of paths relative to the root, with `/` between parts. A directory that matches is not entered. A file that matches is no file of a module, so `shooter.py` that `exclude` names beside `shooter.jac` is no second file of the module `shooter` (E2224).

## How the files are laid out

A module is one `.jac` file and the annexes beside it, which are part of the module and are found by their names ([Modules](../language/modules.md#annexes)).

### Impl annexes

An impl annex holds the bodies of what its module declares. For `cart.jac` the compiler looks in three places, and loads each that exists:

1. `impl/cart.impl.jac`
2. `cart.impl.jac` beside the module
3. `cart.impl/cart.impl.jac`

and, in each, any parts `cart.<part>.impl.jac`. `impl/` is the convention: the lint rule `impls-in-annex` reports an annex beside its module, and `neojac fmt --fix` moves it ([Lint rules](lint.md#layout-policies), [Impl blocks](../language/impl.md)).

### Notes annexes

A module's source carries no comments and no docstrings, and `neojac fmt --fix` deletes them. A
project that keeps what they said says `notes = true` under `[fmt]` in `jac.toml`, and has a
notes annex beside `impl/` for each module that has notes:

```text
shop/
    jac.toml
    archwire.jac
    cart.jac
    impl/
        cart.impl.jac
    notes/
        cart.md
```

A notes annex holds what is said of a module and its declarations, in Markdown: `notes/cart.md`
for `cart.jac`. It opens with `# cart` and the module's own notes, and has a `## <declaration>`
heading for each declaration a note is about (`## Cart.add`). There `neojac fmt --fix` moves what
each comment and docstring said ([The notes annex](lint.md#the-notes-annex)). People read it, and
nothing in the compiler does. A project that does not say `notes = true` has no `notes/`.

### Test annexes

A test annex holds `test` blocks for its module: `cart.test.jac` beside `cart.jac`, or `test/cart.test.jac`. `neojac test` and `neojac check` load it with the module; a build does not ([test](test.md)).

### Variants

A module may have a file for each platform it differs on, `fs.linux.jac`, `fs.darwin.jac`, `fs.windows.jac` beside `fs.jac`; a build uses the one for its target ([Modules](../language/modules.md#how-a-module-is-found)).

`neojac fmt`, `neojac test` and a directory search leave out files and directories whose names start with `.`.

## What neojac writes

| Where | What | Written by |
|---|---|---|
| `.jac/build/` | One record for each output a build or check made, of what it read ([The build cache](cache.md#when-a-build-has-nothing-to-do)); each app's build directory; `logs/`, what each program an app's build ran printed | `build`, `check`, `run`, `emit-js`, `emit-py` |
| `.jac/test/<platform>/` | The test runners, at their modules' paths, each with its `.build.log` and `.log` | `test` |
| `.jac/venv/` | The project's Python virtual environment | `install` |
| `.jac/data/<app>/` | An app's graph, accounts and jobs, when it runs on this machine | the app ([Apps](../apps/data.md)) |
| `jac.lock` | What each ecosystem's resolver pinned for `jac.toml`: Python distributions, and each npm tree's lock ([Packages](packages.md)) | `install`, `npm`, `absorb` |
| An npm tree's `package.json`, `package-lock.json`, `node_modules/`, `.jac/`, in its directory (`eco/web/`) | An npm tree as its tools read it, written from `jac.toml` and `jac.lock`, its installed packages, and its spaces as compiled | `install`, `npm`, `build` |
| `dist/` | Each app's artifact | `build` with no main module ([Building apps](../apps/building.md)) |
| `-o <out>` | The program, wherever `-o` names | `build` |

`.jac/`, `dist/` and what neojac writes under `eco/` are made again by the commands that wrote them, so they do not belong in version control. `jac.lock` does. The compiled code itself is not in the project: it is in the [build cache](cache.md), shared by every project.

```text
.jac/
dist/
```

That is a `.gitignore` for a project.

## What neojac shows while it works

A command that takes more than a moment says what it is doing, on stderr: a build, a check, an app's build, and a command that reads or checks a program before it answers. What it shows depends on whether stderr is a terminal.

**On a terminal** there is one status line, redrawn in place: the output being made, the step it is at, and, for a step it waits on, how long that has taken so far.

```text
⠧ main: compiling units · 21/59  0.2s
```

The steps of a program's build are `loading modules`, `resolving names`, `checking types`, `checking ownership`, `generating code`, `preparing units`, `compiling units · <done>/<all>` and `linking`; an app's build adds its own (`building the program`, `bundling site with vite · transforming 4300 modules`, `assembling the artifact`). The line is cut with `…` to the terminal's width, so it never wraps. Its width is counted in the terminal's columns: a wide character (`漢`) takes two, a combining mark or a control character none, and a line is never cut in the middle of a character. Diagnostics, and the output of the tools a build runs, are written above it as they arrive.

A command that prints an answer shows the steps of the work the answer takes, and the status line is gone before the answer is printed, so the answer is alone on its lines:

| Command | Steps |
|---|---|
| `neojac arch`, `neojac query arch` | `reading archwire.jac`, `reading the modules it names` |
| `neojac query` of a program | The steps of a check up to `checking types`; all of them for `query diagnostics` and `query index` |
| `neojac port` checking what it made | The steps of a check |
| `neojac fmt` | `formatting · <done>/<all>: <file>` |
| `neojac fmt --fix`, `neojac precommit` | `fixing and formatting`, then the steps of each check |

`neojac arch`'s viewer shows the same steps each time it reads the project again after an edit.

When the work is done, the status line is replaced by the outcome:

| Outcome | Printed by |
|---|---|
| `✓ Built main in 1.94s` | A build that made its output |
| `✓ main is up to date` | A build that had nothing to do ([The build cache](cache.md)) |
| `✓ Checked main.jac in 0.21s` | A check with no errors |
| `✓ Wrote out-py in 0.41s` | `emit-js`, `emit-py` |
| `✗ web was not built` | An app whose build failed |

Durations read as `0.35s` under ten seconds, `12.4s` under a minute, `2m 05s` under an hour, and `1h 02m` beyond.

**Anywhere else** (a pipe, a file, CI), there is no status line and no outcome. A build or check that succeeds prints nothing at all, and one that fails prints its diagnostics alone, uncolored. neojac still says, on a line of its own, when it fetches something or waits for another build:

```text
neojac: fetching neojac for linux-x86_64, for its clibs
neojac: waiting for the crates another build is compiling
```

The exit status says whether the command worked, in both cases.

### Tools a build runs

A build runs other programs: Clang and rustc for C and Rust modules, the bundler of a browser space, another neojac for each program of an app. Their output is passed through, according to what it is:

- What a tool warns of or reports as an error is shown as the tool wrote it.
- What a tool only narrates (Vite's `transforming...`, the crates rustc is compiling) becomes the status line's detail, and is shown in full only if the tool fails.
- A tool's own colors and redrawing are taken out, and tabs become four spaces.
- A tool that cannot be started is reported (`cannot run`), with exit status 127.

Each program an app's build runs also leaves its output in `.jac/build/logs/`.

### Color

On a terminal, diagnostics and the status line are colored. The usual variables change that:

| Variable | Effect |
|---|---|
| `NO_COLOR` | Set to anything but the empty string: no color, wherever the output goes. It wins over the two below |
| `FORCE_COLOR`, `CLICOLOR_FORCE` | Set to anything but the empty string or `0`: color even where the output is not a terminal (a CI log that shows colors) |
| `TERM=dumb` | No status line and no outcome line, as when the output is not a terminal, and no color unless `FORCE_COLOR` or `CLICOLOR_FORCE` asks for it |

The status line's marks (`✓`, the spinner, `·`, `…`) need a UTF-8 locale, read from `LC_ALL`, `LC_CTYPE` or `LANG`. Without one the line uses ASCII (`|/-\`, ` - `, `...`) and the outcome has no mark.

On Windows, neojac does not yet ask what the console is, so it writes there as it does to a file: no status line and no color.

### NEOJAC_PROGRESS_TO

`NEOJAC_PROGRESS_TO=<file>` sends the steps to a file instead: neojac appends one line for each step, `<step>` or `<step> · <detail>`, draws nothing, and writes nothing to stderr but diagnostics. It is how one neojac shows the steps of another it runs (an app's build shows each program's build as `<outer step> · <inner step>`), and how an editor or a script can follow a build. The variable stays in the environment of the programs neojac runs (`neojac node`'s, a build step's), so a tool that reports its steps reports them to the same file.

```sh
NEOJAC_PROGRESS_TO=steps.log neojac build main.jac -o main
cat steps.log
```

```text
loading modules
resolving names
checking types
checking ownership
generating code
preparing units
compiling units
compiling units · 0/59
compiling units · 22/59
compiling units · 54/59
linking
```

A build with nothing to do writes no steps.

## What goes wrong

| Message | Cause |
|---|---|
| `neojac: jac.toml: Expected ']' at the end of a table declaration (at line 1, column 9)` | `jac.toml` is not valid TOML |
| `... there is no archwire.jac here` | A command for spaces or apps run outside the directory that holds `archwire.jac` |
| `the archwire has no space 'web'` | A space the archwire does not declare |
| A setting seems to be ignored | It is in a `jac.toml` that is not the project's root's: neojac reads only the nearest one at or above the main module |
