---
description: How an archwire.jac declares the imports between a project's modules as wires in graph import blocks, restricts them with edge rules that say only what the wires do, and limits the packages a module may import.
keywords: graph import, wire, import wiring, edge rule, graph, stale rule, archwire, archwire.jac
grammar: archwire, graph_import, wire_module_path, import_rule, import_wire, module_pattern, wire_payload, wire_target, wired_name
---
# Import wiring

An `archwire.jac` file states, in one place, which module of a project imports what from which
other module. Each import is a **wire**, and **edge rules** say which
[layers](modules-layers.md) may feed which. The modules it governs then write no imports of each
other: the names a wire gives a module are in scope there as if the module had imported them.

Every project has an `archwire.jac`, and every command holds the whole project to it
([What a command judges](#what-a-command-judges)). It declares the project's layers too: every
module an `archwire.jac` governs is in a layer ([Layers](modules-layers.md)). A module that is
of no project, and one of a project of fixtures that no `archwire.jac` governs, writes ordinary
`import` statements instead; see [Modules](modules.md) and
[Projects](../toolchain/projects.md#a-project-of-fixtures).

## Syntax

```ebnf
graph_import ::= "graph" "import" wire_module_path? "{" (import_rule | import_wire)* "}"

import_wire ::= "comptime"? ("include" | "type")? wire_module_path ("++>" | "-->") ("[" (wire_target ("," wire_target)* ","?)? "]" | wire_target ";"?)

wire_target ::= wire_module_path ("|" wire_module_path)* wire_payload?

wire_payload ::= "{" (("*" | any_word | wired_name) ("as" wired_name)? ("," ("*" | any_word | wired_name) ("as" wired_name)?)* ","?)? "}"

wire_module_path ::= (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" wired_name)?

import_rule ::= "edge" NAME ":" module_pattern ("|" module_pattern)* "-->" module_pattern ("|" module_pattern)* (wire_payload | ";")

module_pattern ::= "*" | wire_module_path ("." "*")?
```

A `graph import` block is valid only in a file named `archwire.jac` (E2088), and that file holds
`graph` blocks and nothing else: no statement, no declaration, no comment and no docstring (E2089).

## What an archwire.jac governs

An `archwire.jac` governs the modules in its directory and in every directory below, down to the
next directory that has its own `archwire.jac` or `jac.toml`. Modules are named by their path from
the `archwire.jac`'s directory: `core/clock.jac` is `core.clock`, and `main.jac` beside it is
`main`.

For the modules it governs:

- **An import of another governed module is a wire, never written at the module's top.** Writing
  it there is E1144, and the message gives the wire to add.
- **An import in a code body is admitted by its wire.** With `units ++> shapes { label }`, a
  function of `shapes` may write `import from units { label }`: the wire names what may be
  taken, and the import binds it in that body, starting `units` where it runs
  ([Modules](modules.md#an-import-in-a-code-body)). One the wires do not admit is E2094, whose
  message gives the wire to add.
- **Imports of anything else stay in the module:** the standard library, Python and npm packages,
  C libraries, and modules outside the governed tree.
- **Every name a wire binds must be used** where it lands (E1146). A name listed in the consuming
  module's `__all__` counts as used: `__all__` is the module's public surface. A wire for another
  target is held to it too, in that target's file, whichever system the check runs on.
- The file is checked when the first module it governs loads. If it has syntax errors, the wires
  that parsed still apply and E2093 says the wiring may be incomplete.

### What a command judges

Every command that loads a program (`neojac check`, `build`, `run` and `test`, and the editor)
judges the `archwire.jac` of the project it runs on, and judges it whole, as
[`neojac arch`](../toolchain/arch.md) does. What the program at hand loads makes no difference:

- **Every module under the archwire is in a layer** (E2201), and every file under it in a language
  whose imports are wires is a module: `.jac`, `.py`, the JavaScript and TypeScript extensions,
  and the files of a crate or a C module whose table `jac.toml` holds. What is
  [not the project's source](../toolchain/projects.md#what-is-not-the-projects-source) is left
  out.
- **Every import between the project's files is held to its wire, in both directions.** A Jac
  module the program does not load is read for the imports it writes and the names it uses; a
  file in another language is read by its own engine ([Declared wires](#declared-wires---)).
- **Every edge rule and every layer is judged over all of it.**

So a mistake in a module is reported by every command, whichever program it was run for, and an
`archwire.jac` that one command takes, every command takes.

- **A module no program loads is read, not compiled.** Its imports and the names it spells are
  held to the wires. Its types, and a wired name its provider does not declare (E1145 between two
  Jac modules), are reported by a command on a program that loads it.
- **The judgment is made once.** It is of the project, not of a program, so it is recorded, and
  stands until something of the wiring changes: an import, a wired name, a file added or removed,
  `archwire.jac` itself. A change to a function's body judges nothing again
  ([The archwire's record](../toolchain/cache.md#the-archwires-record)).
- **A dependency's archwire is its own project's.** A [library](../toolchain/packages.md#jac-packages)
  and a [plugin](../apps/plugins.md) are projects with an `archwire.jac` of their own, judged
  whole by the commands run on them. A program that loads their modules holds those modules to it
  and does not judge the rest again. The runtime's and the standard library's are neojac's.

A project has an `archwire.jac`, or says in `jac.toml` that it has none
([Projects](../toolchain/projects.md#archwirejac), E2231).

## Wires

A wire is `provider ++> consumer`, read "the provider feeds the consumer".

| Wire | Equivalent import, in the consumer |
|---|---|
| `core.clock ++> main { now }` | `import from core.clock { now }` |
| `core.clock ++> main { now as current }` | `import from core.clock { now as current }` |
| `core.clock as clk ++> main;` | `import core.clock as clk;` |
| `core.clock ++> main;` | `import core.clock;` |
| `include core.shared ++> main;` | `include core.shared;` |
| `include core.shared ++> main { pad, trim as strip }` | `include from core.shared { pad, trim as strip }` |

- A payload `{ ... }` lists names. A wire without a payload binds the module, and ends with `;`.
- `as` on the provider aliases the module and belongs to a wire without a payload (E0089). A name
  is aliased inside the payload.
- A wire names one provider (E0087). It may name several consumers, either with `|`
  (`core.clock ++> main | app.view { now }`: the payload goes to both) or as a bracketed list in
  which each consumer has its own payload.
- A wire that binds a module without an alias is the one wire that need not be used: it loads the
  module for the effect of its `with entry` code.
- An `include` wire with a payload gives the consumer those names as its own, as
  [`include from`](modules.md#include-and-a-re-export) does: a module that imports the consumer
  takes them from it, and the consumer need not use them itself (no E1146).
- A payload names each name once (E0090), and an empty payload is an error (E0044).
- `comptime` and `type` before the provider are the wire forms of `comptime import` and
  `import type`.
- The provider may be a `.py` file of a [cpython space](../apps/hosts.md): the wire binds what the
  Python import it stands for binds, a name of the module (`helper ++> api { shout }`) or the
  module (`helper ++> api;`). A whole dotted wire whose head is a Python package,
  `fastlib.api ++> checks.run;` where `fastlib/__init__.py` is Python and `fastlib/api.jac` Jac,
  is Python's `import fastlib.api`: it binds `fastlib`, the package as Python imports it
  (`fastlib.__file__`), with the Jac module `fastlib.api` as its member.
- The provider may be a JavaScript or TypeScript file of the project, for a module that can import
  JavaScript: one of a browser or node space, or of a native program
  ([A project's own JavaScript](../interop/npm.md#a-projects-own-javascript)). The wire binds what
  the ES import it stands for binds: an export (`kit.loud ++> page { shout }`), the default export
  (`kit.loud ++> page { default as pick }`), or the module's namespace
  (`kit.loud as loud ++> page;`).

Three forms the grammar takes are refused today with E5090: a payload of `*`, an `include` of a
Python module, and a consumer that is a function or a method of a module rather than the module.

### A scoped block

`graph import <package> { ... }` holds wires between modules of one package, written relative to
it. Inside `graph import core`, `clock ++> host { now }` is `core.clock ++> core.host { now }`. The
scope must name a package under the `archwire.jac` (E2097).

### Wires for one target

A module with target variants (`host.jac`, `host.windows.jac`; see [Modules](modules.md)) may need
different imports on different targets. A wire's consumer then ends in the target the wire is for,
named as a variant file names it: an operating system, an architecture, or one of each.

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import core {
    libc ++> host.darwin | host.linux | host.wasi { c_stat }
    win ++> host.windows { wide }
    clock ++> host { now }
}
```

- A wire for a target lands in the module only when the program is built for that target, in
  whichever file is the module there: `host.jac` on Linux, `host.windows.jac` on Windows. Its names
  must be used there (E1146), and every check says so: a check on Linux reads `host.windows.jac`
  and its annexes for the names a Windows wire brings it.
- A name every target's file needs is a plain wire, as `clock ++> host { now }` is.
- A target the module has no file for is E1142: `win ++> host.windows { wide }` needs a
  `host.windows.jac`, and a wire for the targets the plain `host.jac` serves names each of them.
- No variant file writes an import of a project module. One that does is E1144, and the fix it
  gives is the wire with the targets its file is for.

### Declared wires: `-->`

`provider --> consumer { names }` injects nothing: it declares an import that the consumer's own
source writes. That is the wire of a file in another language, which cannot take its imports from
`archwire.jac` and so keeps them:

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    words --> helper { loud }
    marks --> helper;
    helper ++> api { shout }
}
```

`helper.py` holds `from words import loud` and `import marks`; `api.jac` holds no import, since its
`++>` wire is one.

- The wire mirrors the source's import: the names the statement lists, or no names where the
  source takes the module whole.
- The file's own language reads it, and holds wire and source to each other. An import the source
  writes and no wire declares is E1575; a `-->` wire that no file of the consumer writes is E1147;
  a name the provider lacks is E1145.
- A `++>` wire into such a file is E1142.
- Edge rules and layers apply to a `-->` wire as to any other.
- `neojac fmt --fix archwire.jac` mends the declared wires to the sources: it writes the wire an
  import lacks and removes the wire, or the name, that no source writes
  ([fmt](../toolchain/fmt.md#--fix)).
- Every command judges every such file under the archwire, whether a Jac module is wired it or
  not ([What a command judges](#what-a-command-judges)).
- Only imports between the project's own files are wires. An import of a package, or of the
  language's own library, stays in the file and is no wire.

Each language is read by its own engine, the one that runs or compiles the file:

| Files | Read by | An import is | The wire's names |
|---|---|---|---|
| `.py` | CPython | `import m`, `from m import a`, `from . import m`, resolved from the file's package and from the project | the names `from` lists; none for `import m` |
| `.js`, `.mjs`, `.cjs`, `.jsx`, `.ts`, `.mts`, `.cts`, `.tsx` | TypeScript | `import`, `export ... from`, `require("./m")`, `import("./m")`, resolved as the file's `tsconfig.json` says (its `paths`, its `baseUrl`) | the names the statement lists, `default` for a default import; none for `import * as m`, `import "./m"`, `require` and `import()` |
| `.c`, `.h`, `.cc`, `.cpp`, `.cxx`, `.hpp`, `.hh`, of a C module whose table `jac.toml` holds | Clang, each unit for every platform | every function, variable, type, enumerator and macro a file uses that another file of the project declares; `#include` itself is no import ([A C module's files](../interop/c-modules.md#a-c-modules-files)) | each name as written. A function or a variable is the file's that defines it; a source and the header of its name are one module |
| `.rs`, in a crate whose manifest `jac.toml` holds | rustc | every path that names an item another file of the crate defines: in a `use`, a type, an expression or a pattern ([A crate's files](../interop/rust-modules.md#a-crates-files)) | each item's name in its file: a variant's is its enum's. None where the file takes a module whole (`use crate::util::*;`), which covers the names it uses of it |

A module a build makes from native code, which `jac.toml` declares as an
[extension](../reference/jac-toml.md#extensionspath) (`[extensions."spamlib/_tally"]`), is a
module too, though no file is: a Python file that imports it is wired from it,
`spamlib._tally --> spamlib.core;`, and any name is taken of it.

A file's module name is its path from the archwire, without its extension, so two files of one
name and two languages in one directory (`util.py`, `util.ts`) are refused (E2224). Where a part
of the name is no word, quote the path, with `/` between its parts:

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    lib.tools --> "lib/paint-brush" { default, brush }
    "lib/paint-brush" --> "routes/_layout" | main;
}
```

`lib/paint-brush.ts` holds `import pick, { brush } from "./tools"`. A payload of a `-->` wire may
name any word the other language exports, a keyword of Jac's such as `default` among them.

A stem that holds a dot is quoted too, as is every file under a directory whose name is no word:
`"web/twice.gen"` is `web/twice.gen.ts`, where `web.twice.gen` would name `gen.ts` in a
directory `twice`. A quoted name that a dotted one could say is E2310: `"lib/tools"` is
`lib.tools`.

A name the provider lacks is E1145 where the file states all it gives. A CommonJS file, a file
that exports another's names with `*`, and a Python file with `from m import *` or a module
`__getattr__` do not, so any name is taken of them.

A `-->` wire into a Jac module is E1142. A Jac module writes no import of a project module, so a
wire into it is the import, `++>`; a module whose imports differ by target takes
[a wire for each target](#wires-for-one-target).

## Edge rules

```ebnf
import_rule ::= "edge" NAME ":" module_pattern ("|" module_pattern)* "-->" module_pattern ("|" module_pattern)* (wire_payload | ";")
```

An edge rule `edge Name: sources --> targets;` permits wires from a source layer to a target layer.
Rules inject nothing; they are checked against the wires.

- **A rule names [layers](modules-layers.md)** (E2210). The wires say which modules; the rules say
  which layers.
- **A wire needs one rule at each level of the layers it crosses** (E2099):
  [Rules between layers](modules-layers.md#rules-between-layers). A wire between two modules of
  one innermost layer needs none.
- **A rule with a payload admits only the names it lists** (E2091). Its payload lists names without
  aliases (E0096).
- Each rule has its own name (E2092).

### A rule says only what the wires do

A rule that admits more than the project does is a statement nobody checks, so it is an error:

- **A rule nothing uses** (E2205): no wire and no import is one it admits.
- **A layer of a rule that nothing it admits reaches** (E2206): `edge Core: core --> app | cli;`
  when no wire lands in `cli`.
- **A name in a rule's payload that nothing it admits carries** (E2207).
- **A flow two rules admit** (E2208): a wire at one level of the layers it crosses, or an import
  from outside. One rule admits each, so each arrow has one name to be called by.

These are judged by every command, over every module the `archwire.jac` governs
([What a command judges](#what-a-command-judges)). An `archwire.jac` with other errors is not
judged at all: what its rules admit is not known yet.

### Rules over imports written in modules

An import of something that is not a module of the project stays in the module that needs it. A
rule may still limit it: its source names the package as the import spells it.

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    edge Files: os --> kept;
    edge Drawn: "react" --> screen;
}
```

- `os` is `import os;` and `import from os { ... }`. A quoted source is a quoted import, as an npm
  package's is: `"react"` is `import from "react" { ... }`, and `"@radix-ui/*"` every package whose
  name begins so.
- The rule's targets are layers, as every rule's are, and its source is the package. One rule
  admits the import, whatever the depth of the layer it names.
- Once a rule names the package, a module of a layer no rule admits may not import it (E2090), and
  a payload admits only the names it lists (E2091).
- A source that names no module of the project is not checked to exist. A rule over a package
  nothing imports is E2205.

### A rule for every import from outside

A project may ask that **nothing** from outside it is imported without a rule. `jac.toml` says so:

```toml
[check]
imports = "ruled"
```

Every import of a standard-library module, a package, or a C or Rust library then needs an edge
rule that admits it into the module that writes it (E2211), and the message gives the rule. The
default is `"open"`: an import from outside needs a rule only once some rule names its package.

## Example

A project laid out as:

```text
jac.toml
archwire.jac
main.jac
app/view.jac
core/clock.jac
core/shared.jac
```

`archwire.jac`:

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph layers {
    layer core { core.*; }
    layer app { app.*; }
    layer program { main; }
}

graph import {
    edge Core: core --> app | program;
    edge App: app --> program;

    core.clock ++> [
        main { now },
        app.view { Tick, now as current },
    ]
    core.clock as clk ++> main;
    include core.shared ++> main;
    app.view ++> main { render }
}
```

`core/clock.jac`:

```jac
obj Tick {
    has n: int = 0;
}

def now -> int {
    return 1;
}

def later -> int {
    return 2;
}
```

`core/shared.jac`:

```jac
def helper -> str {
    return "shared";
}
```

`app/view.jac`, which writes no import of `core.clock`:

<!-- example: not checked: Tick and current are wired in by archwire.jac -->
```jac
def render(n: int) -> str {
    t = Tick(n=n);
    return str(current() + t.n);
}
```

`main.jac`. It imports `os` itself, since `os` is not a module of the project:

<!-- example: not checked: now, clk, helper and render are wired in by archwire.jac -->
```jac
import os;

with entry {
    print(now(), clk.later(), helper(), render(4), os.sep);
}
```

```sh
neojac build main.jac -o main && ./main
```

```text
1 2 shared 5 /
```

## What is rejected

| Code | Condition |
|---|---|
| E2088 | `graph import` in a file not named `archwire.jac` |
| E2089 | Anything but `graph` blocks in `archwire.jac`, a comment included |
| E2093 | `archwire.jac` has syntax errors (reported once) |
| E1144 | A governed module writes an import of another governed module |
| E2094 | An import in a code body that no wire admits |
| E1146 | A wired name is never used in the consumer, on any target |
| E1147 | A `-->` wire whose import no file of the consumer writes |
| E1575 | An import a file in another language writes of a file of the project, that no `-->` wire declares |
| E1141 | The provider is not a module under this `archwire.jac` |
| E1142 | The consumer is not a Jac module under it, or is named twice in one wire |
| E1143 | A wire from a module to itself |
| E1145 | The provider has no such name |
| E2097 | A scope or a consumer that names no module |
| E2213 | An `archwire.jac` that declares no layer |
| E2099 | A wire between two layers that no rule admits, at any level it crosses |
| E2210 | A rule that names modules |
| E2091 | A name crosses that the admitting rule's payload does not list |
| E2090 | An import from outside the project that no rule admits, when a rule names its package |
| E2211 | An import from outside the project that no rule admits, under `[check] imports = "ruled"` |
| E2092 | A rule named twice |
| E2205, E2206, E2207 | A rule nothing uses; a pattern of one nothing matches; a payload name nothing carries |
| E2208 | A flow two rules admit |
| E0086 | A wire not written `provider ++> consumer` or `provider --> consumer` |
| E0087, E0089, E0090, E0044, E0095, E0096 | Malformed wires and payloads |

A `graph import` block written in an ordinary module:

```jac
# expect: E2088
graph import {
    util ++> main { now }
}

with entry {
    print(1);
}
```

A module that writes an import its `archwire.jac` should hold gets the fix in the message:

```text
main.jac:2:26: error[E1144]: the import of 'core.clock' is written in 'main', which takes its
imports of the modules under its archwire.jac from wires: add `core.clock ++> main { Tick }` to
the `graph import` block and delete this import
```

`archwire.jac` also holds `graph layers` blocks, which group a project's modules
([Layers](modules-layers.md)), and `graph spaces` blocks, which declare an app's spaces; see
`neojac docs space`.
