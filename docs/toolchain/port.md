---
description: neojac port, which translates C, C++, Rust, Python, JavaScript and TypeScript source into Jac that behaves as the source does or refuses it - in a project, a file read as the project builds it and its module moved in one change with its wires and tables; outside one, the Jac written beside the source; the plan --check prints, what is refused and why, and how each language is read.
keywords: port, porting, transpile, transpiler, translate source, neojac port, --mapping, port plan, replaced-by-neojac
---
# port

`neojac port` translates source in another language into Jac. A port behaves as its source does,
or it is refused: port never writes Jac that is only close.

```sh
neojac port tools/gcd.py            # writes tools/gcd.jac
neojac port vendor/shelf            # every source under a directory
neojac port --check src             # write nothing: what would port, what is refused, the plan
neojac port src/half.c -o build/jac # outside a project: write under another directory
```

| Language | Files | Read by | Mapping |
|---|---|---|---|
| C | `.c`, `.h` | Clang: in a project for every target its C module compiles it for, else for every target neojac builds C for | [Porting C](../interop/port-c.md) |
| C++ | `.cc`, `.cpp`, `.cxx`, `.hpp` | Clang, the same way | [Porting C++](../interop/port-cxx.md) |
| Rust | A crate, by its `src/lib.rs` | rustc, for every target neojac builds Rust for | [Porting Rust](../interop/port-rust.md) |
| Python | `.py` | CPython | [Porting Python](../interop/port-python.md) |
| JavaScript, TypeScript | `.js`, `.mjs`, `.cjs`, `.ts`, `.mts`, `.cts`, `.jsx`, `.tsx` | TypeScript | [Porting JavaScript and TypeScript](../interop/port-javascript.md) |

Each language is read by its own compiler, the one neojac ships, so port sees a source exactly as
a build of it does: its types, what every name refers to, its macros expanded. A language's
mapping page lists what it translates, and port refuses the rest.

## A port

`gcd.py`:

```python
"""Greatest common divisors."""


def gcd(a, b):
    # Euclid's algorithm.
    while b != 0:
        a, b = b, a % b
    return a


if __name__ == "__main__":
    print(gcd(1071, 462))
```

`neojac port gcd.py` writes `gcd.jac`, a module of a `cpython` space, whose parameters are as
the source left them, unannotated:

<!-- example: not checked: a module of a cpython space, where a parameter may have no annotation -->
```jac
"""Greatest common divisors."""

def gcd(a, b) -> any {
    # Euclid's algorithm.
    while b != 0 {
        (a, b) = (b, a % b);
    }
    return a;
}

with entry:__main__ {
    print(gcd(1071, 462));
}
```

- **The Jac is in neojac's one layout**, as [`neojac fmt`](fmt.md) writes it. Outside a project
  the source's comments and docstrings are in it, at the declarations and statements they belong
  to. A project's source carries none, so there they go as [`fmt --fix`](lint.md#fmt---fix) has
  them go: they are removed, or, where the project's `jac.toml` says `notes = true` under `[fmt]`,
  kept in the module's notes annex, `notes/<module>.md`, under the declarations they belong to
  ([The notes annex](lint.md#the-notes-annex)). A module of a `cpython` space keeps its
  docstrings, which are the `__doc__` Python reads.
- **It is checked before it is written.** Port runs everything [`neojac check`](check.md) runs on
  what it made, and writes it only when that finds nothing: outside a project, a Python file's
  Jac as a module of a `cpython` space and a `.tsx` or `.jsx` file's as one of a browser space,
  other JavaScript's and TypeScript's as one of a node space, and C's, C++'s and Rust's natively,
  where what they use runs; in a project, the project as the port leaves it.
- **The same source gives the same Jac.** Nothing in a port is a guess: every fact comes from the
  source's own compiler.

## Same behavior

A port prints what its source prints, exits as it exits and raises where it raises. Where Jac
means something else than the source, port writes the Jac that keeps the source's meaning, even
when no one would write it by hand. C's `/` rounds toward zero and Jac's `//` toward negative
infinity, so `n / 2` of a signed `n` is written with a test of its sign:

```c
static int half(int n) {
    return n / 2;
}
```

```jac
def half(n: i32) -> i32 {
    return n // 2 + 1 if n % 2 != 0 and n < 0 else n // 2;
}

with entry {
    print(half(7), half(-7));
}
```

```output
3 -3
```

- **What the source leaves undefined may become defined.** A signed overflow is undefined in C,
  and the Jac raises `OverflowError`.
- **A port checks at run time no more than its source does.** TypeScript's types are erased, so
  JavaScript holds a TypeScript program to none of them. A place a port writes (a parameter, a
  variable, a field, a property, a return, an element) keeps the type TypeScript gives it only
  where every value that reaches it has that type with no conversion from `any`. A value TypeScript
  took on trust (an `any`, a cast that is no upcast such as `v as string` of an `unknown`, `v!` of
  what may be null) is `any`, and so is every place it reaches, through every file of the run; no
  run-time check is written that the source did not write as a test. What TypeScript did check is
  kept, so typed code stays typed where its types are true. A Python annotation is carried as the
  Python object it names, which Jac reads as `any` ([Porting Python](../interop/port-python.md)).
- **What has no such Jac is refused.** A Python comprehension has one variable, which a
  function made in it closes over, where Jac's comprehension has a variable for each pass, so
  such a comprehension is refused (E4005).

## What a path names

- **A file** is known by its extension, and one port does not translate is E4004.
- **A directory** is every source under it that port translates.
- **A C or C++ source is ported with the header of its name**: `geom.c` and `geom.h` are the
  module `geom`.
- **A directory with a `Cargo.toml` is a Rust crate**, ported from its `src/lib.rs`.

How each source is read, and where its Jac goes, depends on whether it is in a project: a
directory with a `jac.toml` above it ([Projects](projects.md)).

## In a project

A project's sources are read as the project builds them, and porting one moves its module from
its language to Jac in one change.

**What a path names is what `jac.toml` says.** A directory is every source of the trees
`jac.toml` describes under it, in every language, and not what `[project] exclude` leaves out
nor what neojac set aside in `replaced-by-neojac/`. A directory with an `archwire.jac` of its own is
read as that archwire describes it. A path `exclude` leaves out is E4006, one under a directory
neojac never reads as source (`node_modules`, `replaced-by-neojac/`) E4044, and one into a C module
or a crate `jac.toml` holds no table of, which its own manifest builds as a dependency, E4045: the
module nearest the path, where one holds another. A C, C++ or Rust source that no table builds, in
no C module's `sources` and in no crate, is E4046. A C module whose table says `vendored = true` is another project's code kept in this one
([C modules](../interop/c-modules.md#the-manifest)): it is built as it is, port reads
none of it, and a path into it is E4011.

**Each file is read as its build reads it.** Python with its package, so a relative import names
a module of the project; C with its module's table in `jac.toml` (its includes, its defines, its
own file's flags), for the platforms the module compiles it for (one compiled for none is E4007);
TypeScript in its `tsconfig.json`'s program (its libraries, its module resolution, its
`paths`), with the `node_modules` above it; Rust with the features the project builds the crate
with: those of the `[extensions]` row whose `cargo` is the crate, else its defaults (two rows
naming it with different features refuse it). rustc reads a crate whole, so its files are one
group of the plan: each is its own source, ported to its own module, read through the crate's
root, and they port together or not at all. A crate that ports whole keeps, as its
`[cargo."<directory>"]` table in `jac.toml`, only what its Jac still names: its `package`, and
the dependencies its Jac imports (`bstr`), with their pins in `jac.lock`, as the manifest of the
Rust that Jac takes from; its library, its features and the dependencies the port lowered away
(`pyo3`) go. Each `[extensions]` row built from it names the Jac instead, `jac = "src/py.jac"`,
the port of the file that holds its `#[pymodule]`, its features dropped
([Extension modules](packages.md#extension-modules)). The `Cargo.toml` and `Cargo.lock` neojac
writes from the table are written again from what it keeps; a run that is refused or stopped
puts all of it back, as it puts back the rest. A C file a unity build compiles only through another
source's `#include` is read in that source's translation unit, and ports with it: the source and
the files it includes port together or not at all (E4010 for such a file ported alone or held
back, E4043 for the source held back).

**The plan.** `neojac port --check` prints what would port and what is refused, and in a project
the plan: each module after the modules of the project it imports, so that each step leaves a
project that builds, and modules that import each other as one group that ports together.
`--json` prints the same as data. A check leaves the project as it found it: what it tries in
place (`jac.toml`, `archwire.jac`, and every manifest written from `jac.toml`: a crate's
`Cargo.toml`, a C module's `cmodule.toml`, a tree's `package.json` or `pyproject.toml`) is put back with its text and its times of
change, so a build or another check after it finds nothing changed, and a second check of a
crate takes cargo's plan of it from the build cache.

```text
$ neojac port --check shop
the plan, each module after those it imports; a group ports together:
  1. shop: now
  2. shop.mathx: now
  3. shop.ping, shop.pong (together): now
  4. shop.report, after shop.mathx
  5. shop.use, after shop.mathx
port: 6 sources would port
```

**A run follows the plan.** Each step of it is one change, made in the plan's order: a module
that imports one the run refuses, or does not port, is held back with it (E4012), and every other
step that checks is written. Where a module of a group is refused for its own code, each other
module of the group is E4012 too, naming that one: modules that import each other port
together.

**A step is one change.** Porting a file in a project:

- writes its Jac beside it, under its name, laid out as the project's lint rules want it: the
  declarations in the module and the bodies in its annex, `impl/`, with no comment and no
  docstring (a module of a `cpython` space keeps its docstrings). Where the project says
  `notes = true` under `[fmt]`, what its comments and docstrings say is written whole in its
  notes annex, `notes/<module>.md`;
- moves the source to `replaced-by-neojac/`, at its path in the project;
- writes its imports of the project's modules as wires in `archwire.jac`: a module that
  `shop/use.py` imported, `from .mathx import gcd`, is the wire `shop.mathx ++> shop.use { gcd }`,
  naming what the Jac reads, and the module's Jac imports nothing of the project at its top level.
  An import in a function stays where it loads ([an import in a code body](../language/modules.md#an-import-in-a-code-body))
  and gets its wire too; a re-export (`export { total as summed } from "./total"`) is an `include`
  wire, `include web.total ++> web.gives { total as summed }`, naming every name it gives. An
  import by a path `tsconfig.json`'s `paths` aliases (`import { total } from "@/total"`) is the
  wire of the module the alias resolves to, `web.total ++> web.halve { total }`, and a module
  whose file's stem holds a dot is named by its quoted path,
  `"web/twice.gen" ++> "web/quad.gen" { twice }`
  ([a module whose name is no identifier](../language/modules.md#a-module-whose-name-is-no-identifier));
- keeps the wires of the files that stay in their language and use it: a `-->` wire declares an
  import their own source writes (C's `#include` and calls, JavaScript's `import`), and it now
  names what they take of a Jac module; a name such a wire gives from a C source that the Jac
  module no longer gives (a macro the source set before a header that reads it, as CPython's
  getargs.c sets `PY_CXX_CONST` for `pyport.h`) leaves it; a C source leaves its module's table
  in `jac.toml`;
- and makes all of it only if the project then checks. Otherwise nothing of that step is
  written (E4008, at its first source, after the errors the check found): its sources stay, and
  `archwire.jac`, `jac.toml` and every manifest written from it are as they were for it.

```text
$ neojac port shop/use.py
shop/use.py -> shop/use.jac
shop/use.py -> replaced-by-neojac/shop/use.py
```

- **The C that stays calls the Jac.** A C source of the module that is not ported, and called a
  function of the ported file or read its data, calls the Jac module's function and reads its C
  data through its wire, by the header beside the Jac module or the module's own headers
  ([C modules](../interop/c-modules.md#calling-jac-from-c)). Which module gives a name is a fact
  of each target: of two parts of a source that define one function, each for the platforms
  that include it (CPython's `thread_pthread.h` and `thread_nt.h`), the C of a target calls the
  one its own build has.
- **A header ported with its source stays only while C that stays reads it.** A header beside a
  source of its stem (`count.h` beside `count.c`) is, once the source is Jac, the Jac module's
  face to C, which the C that stays includes to call it. It moves to `replaced-by-neojac/`,
  beside its source, in the run in which nothing that stays reads it: the run that ports its
  last reader, or any later run, since every run judges every header whose source is Jac. What
  reads it:
  - a C or C++ source a C module's table lists, on each platform the module is recorded for,
    whose compile opens it, through another header too;
  - a C or C++ source in the module's directory that no table lists: another system's file, which
    no record of this copy has read, so it cannot be said not to include the header. Every
    ported header of its module stays until a record of its platform reads it, and the next run
    moves those nothing reads.

  A table's `headers` naming the header is not a read of it (a face is no C module's header,
  [C modules](../interop/c-modules.md#the-manifest)), and a face written by hand, with no
  source of its stem in `replaced-by-neojac/`, never moves. The move is one of the step's
  changes: journalled, and put back with the sources where the project would not check. For a
  header whose source ports in this run and that stays, port says why, in one of two forms:

  ```text
  native/count.h stays beside native/count.jac: native/unity.c, which stays C, includes it
  native/count.h stays beside native/count.jac: 1 source of its C module that no record has read (native/beos.c) may include it, until a record of their platform reads them
  ```

  The run that moves it says so as it says a source's move,
  `native/count.h -> replaced-by-neojac/native/count.h`.
- **A C module's ported sources stay its code.** Port takes each off the module's `sources` and
  lists its Jac in the table's `jac` ([C modules](../interop/c-modules.md#the-manifest)): native
  code the module is built from, never an npm tree's space, even in a directory the tree's
  `files` names. The Jac module's files table keeps the flags the source was compiled with, and
  holds the headers its source included, in their order, with the macros it set before them:
  the Jac binds what its source's translation unit declared, read as the source read it. A
  module all of whose C++ sources are ported keeps `language = "c++"`. A header
  library under `node_modules` the module includes (node-addon-api's) is wired to the Jac as any C
  module is (`node_modules.kit.kit ++> addon.twin { Tally }`). So a Node addon built from the
  module is built from the Jac and loads in Node as the C++'s did
  ([Extension modules](packages.md#extension-modules)).
- **A Python project's tests and scripts are its space's clients.** A file of the project's tree
  that its wheel does not list (`tests/`, `scripts/`, a `setup.py`) imports the package as the
  space builds it, so it holds no module back, and its Python import of a ported module reaches
  the Jac. A module the wheel ships ports too: port lists its Jac in the project's `[wheel]`
  `files` in its source's place (`fastlib/api.py` becomes `fastlib/api.jac`), and the wheel
  holds it as Python's own module ([Building and testing a Python project](packages.md#building-and-testing-a-python-project)).
- **A JavaScript file reads a ported module as its JavaScript stood.** A later run ports a file
  that imports or requires a module an earlier run made Jac: the reader takes the Jac module's
  names, its `default` and, in a CommonJS directory, its exports as the JavaScript module gave
  them. A module ported from TypeScript gets a face beside it, `<stem>.d.ts`: TypeScript's own
  declarations of the source, which the reader and the TypeScript files that stay read of the
  Jac module ([A project's own JavaScript](../interop/npm.md#a-projects-own-javascript)); the
  journal records it with the change. A declaration file of the tree (`env.d.ts`) holds no code
  and is never ported: `--check` says so of it.
- **A ported npm tree's own tools see what they saw.** Its tests, its scripts and its build run
  on what its space emits, laid out as a tree of the source's shape: at each ported source's
  place a forwarder of the source's own name and extension that gives the module (`main.tsx`,
  `auth.setup.ts`, `counter.mts`), a TypeScript module where the source was one, and what the
  space emits apart in the laid tree's `.jac/`, each module's face beside its emission. No face
  stands among the tree's own files. The Jac file stands at the source's place too, a link to
  the project's file, and the source maps name it there: a test runner reports a ported test's
  failure at `tests/login.spec.jac:24:5`, where it reported `tests/login.spec.ts:24:5`, and its
  file filter names a ported test by its stem (`login.spec`). `neojac test`, `neojac npm run build` and `neojac npx vite
  build` run there, with the tree's configuration as it is, so a tool that matches a file by the
  source's name (a test runner's pattern, an `index.html`'s script) finds its forwarder ([A
  project's own suites](test.md#a-projects-own-suites)). A file that stays and imports a source
  by its TypeScript extension (`import { bump } from "./counter.mts"`) reaches its forwarder. The
  laid top stands for the project's top: a path that leaves the tree (`../../.env`) reaches the
  project's own file, as it did from the source tree.
- **A module imported by a file of no space** (a script outside every space and every Python
  project's tree) is refused (E4009): that file would have nothing to import.
- **`-o` is for sources outside a project.** In one, the Jac is written beside its source.
- **One run at a time.** A run claims the project while it works (`.jac/port/claim`), and a
  second `neojac port` in the same project is refused until it is done; a run that dies lets the
  claim go.
- **A run that is stopped leaves nothing half made.** Each change is journalled
  (`.jac/port/journal.json`: the texts it replaces, the files it makes, the sources it moves)
  before it is applied, and the journal goes once the change is final. Ctrl-C puts the change
  back at once; after a kill, the next `neojac port` in the project undoes what the journal
  holds, and says so, before it does anything else. Until then the project is neither as it was
  nor as the port would leave it, and `neojac check` and `neojac build` refuse to read it (E4013).

## Outside a project

A source outside any project is read as `neojac build` reads it alone, for every target neojac
builds its language for, and its Jac is written beside it, under its name: `tools/gcd.py`
becomes `tools/gcd.jac`. Directories whose names start with a dot, and `node_modules`, `build`,
`target`, `dist` and `__pycache__`, are left out. A C source is read with the flags of the C
module it is in (the `cmodule.toml` above it).

| `-o` | Writes |
|---|---|
| A name ending in `.jac` | That file, for one source |
| Anything else | A directory: a file's port in it, and a directory's sources under it as they are under the directory |

- **An output that is already there is refused** (E4003), so a port someone has edited is never
  written over. Remove it to port again.
- **The source is never changed**, and neither is a `cmodule.toml`, a `Cargo.toml`, an
  `archwire.jac` or a `jac.toml`.
- **The files of a C module port together.** Nothing wires a Jac module into the C that stays,
  so a file is refused while a source that calls it stays C (E4002). A function defined with
  `...` is a Jac function of C's variadic arguments, by the C ABI
  ([Functions of C's variadic arguments](../interop/c-libraries.md#functions-of-cs-variadic-arguments)),
  which C calls as it called the C.

## Platforms

**C, C++, Rust and Python that differ by platform** port to one module where every target agrees.
A statement that differs is written under `comptime if` on `target()`, and so is a declaration
that differs, among the module's declarations or a class's members
([comptime if](../language/compile-time.md#among-declarations-and-members)); C and Rust whose
declarations differ throughout go to the module's target variant files (`geom.windows.jac`),
which [Modules](../language/modules.md) describes. Python's tests of `sys.platform` and
`os.name` port to `comptime if` the same way.

A Python `if` whose test joins a platform test to tests made as the program runs, where the
platform test comes first and guards them (`if not (WINDOWS and err.winerror == 6):`), is split:
`comptime if` on the platform, and in each arm what the platform leaves of the test, so that
`err.winerror`, which only Windows gives, is checked only for Windows:

```text
comptime if target().os == "windows" {
    if not err.winerror == 6 { return "raise"; }
} else {
    return "raise";
}
```

A platform test that guards nothing after it (`if err.errno == 2 and WINDOWS:`) stays part of
the test as the program runs: Python evaluates what stands before it on every platform.

A Python module that another imports only under a test of the platform (`if sys.platform ==
"win32": from . import _windows`) is in the plan's group of its importer, and ports with it: the
group is checked for each target, and the module only for the targets whose test picks it, as
Python imports it only there. Python's test of what such a module has, `if hasattr(_psplatform,
"getloadavg"):`, ports to `comptime if` on [`hasattr` of the
module](../language/compile-time.md#hasattr-of-a-module) where the module is one the run ports or
is Jac already; `if hasattr(m, "x") and rest:` is `comptime if hasattr(m, "x") { if rest { ... }
else { ... } } else { ... }`. A test of a module that stays Python is Python's, as the program
runs.

Such a module that no target loads, only a system neojac builds for no target of (`if
sys.platform.startswith("sunos"):`), has nothing to check its Jac against: it stays Python
(E4017). One whose Jac fails the check of the one system that loads it stays Python too, with
that check's errors shown (E4018). In both, the importer imports it as Python does where its test
picks it, and the rest of the run is written.

**What port checks is checked for each target.** The Jac a run writes is checked first as the
host builds it, then each target's variant, under that target's operating system and
architecture, its variant file in place of the module's file: the Windows variant is checked
with Windows' system headers. So a C record a system header declares with other fields on
another target (`struct stat`) is that target's record in that target's check, and meets no
other declaration of it ([one record across the program](../interop/c-libraries.md#one-record-across-the-program)). A module only another platform's C table holds (a Linux source, from macOS) is checked under
that platform, with its C module's interface read for it. A C or C++ source read for several
targets is one module: its Jac file and its target variant files, which share the module's wires,
and the C module's `jac` names the module's own file; each variant is checked for its target. Where that check fails, the file stays C,
which its C module builds there as it is, with that check's errors shown (E4015).

## What is refused

A file ports whole or not at all. Port reports every construct it refuses, each at its place in
the source with what to do instead, writes nothing for that file, and exits with status 1.

```text
$ neojac port tail.py
tail.py:3:1: error[E4005]: port writes no Jac yet that keeps the meaning of module code after `if __name__ == "__main__":`: a Jac module's `with entry` code runs before its `with entry:__main__`
 3 | print("after")
   | ^
    = help: Move the code above the `if`.

1 source refused, nothing written for it
`neojac docs port` says what port translates and what it refuses.
```

| Code | Refuses |
|---|---|
| E4001 | A construct outside the language's mapping |
| E4002 | Outside a project, a C file whose functions a source left in C still calls |
| E4003 | An output that is already there |
| E4004 | A file that is no source port translates |
| E4005 | A construct whose Jac would mean something else |
| E4006 | In a project, a path its `[project] exclude` leaves out |
| E4007 | In a project, a C source its module compiles for no platform |
| E4008 | In a project, a port after which the project would not check |
| E4009 | In a project, a module a file of no space imports |
| E4010 | A file a unity build compiles only inside a source not ported with it |
| E4011 | In a project, a path into a C module its table says is another project's code (`vendored = true`) |
| E4012 | A module that imports one the run does not port, held back with it |
| E4015 | A C file only another platform compiles, whose Jac fails that platform's check: it stays C |
| E4016 | A Python source importing a module neojac cannot find |
| E4017 | A Python module only a system neojac builds for no target of loads: it stays Python |
| E4018 | A Python module whose Jac fails the check of the one system that loads it: it stays Python |
| E4030 | A C file calling a header's `static inline` function, where no C module holds the header |
| E4043 | A unity build's source, held back because a file it includes is refused |
| E4044 | In a project, a path under a directory neojac never reads as source (`node_modules`, a name beginning with `.`, `replaced-by-neojac/`) |
| E4045 | In a project, a path into a C module or a crate `jac.toml` holds no table of: a dependency |
| E4046 | In a project, a C, C++ or Rust source no table of `jac.toml` builds: in no C module's `sources` and no crate |

- **An object in memory nothing constructed is never ported** (E4001): a C++ placement `new` into
  storage the program gives, an explicit destructor call, and an object used in memory no
  constructor made (a class's object in the zero-filled memory a C library hands back). No Jac
  form keeps an object in raw memory; the source makes the object with `new` where it first needs
  it and deletes it where it is done, and that ports
  ([Porting C++](../interop/port-cxx.md#what-is-refused)).
- **A source its own compiler rejects** is reported by that compiler, under its own code
  (`error[cpython SyntaxError]`, `error[tsc TS2322]`, Clang's and rustc's own messages).
- **`neojac port --check`** reports the same and writes nothing: run on a codebase, it lists what
  stands between it and a port, and in a project the plan.

## Reading a mapping

`neojac port --mapping <language>` prints a language's mapping page: `c`, `c++`, `rust`, `python`
or `javascript`. The pages under [Using other languages](../interop/index.md) are those, printed
from the tables the translations read.
