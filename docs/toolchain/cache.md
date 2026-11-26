---
description: The build cache - where it is, what it keeps, its size and what is deleted over it, NEOJAC_CACHE_DIR and NEOJAC_CACHE_SIZE, builds running at once, and exactly when a build or a module is compiled again.
keywords: build cache, cache, cache size, CACHEDIR.TAG, up to date, incremental build, rebuild, fetched
---
# The build cache

A build compiles each module on its own and keeps what it compiles in the build cache: a directory of your own, shared by every build you run. A rebuild compiles only what an edit changed, and a build with nothing changed does nothing at all.

```sh
neojac build main.jac -o main     # compiles main.jac, what it imports, and the runtime's modules
neojac build main.jac -o main     # nothing changed: does nothing
```

On a terminal the second build says so:

```text
✓ main is up to date
```

The first build of anything compiles the runtime's modules too; every later build, of any program, finds them in the cache.

## Where it is

| Platform | Directory |
|---|---|
| macOS | `~/Library/Caches/neojac/2/` |
| Linux | `$XDG_CACHE_HOME/neojac/2/`, or `~/.cache/neojac/2/` when `XDG_CACHE_HOME` is unset |
| Windows | `%LOCALAPPDATA%\neojac\2\` |

`NEOJAC_CACHE_DIR` names another directory instead: the cache is then `$NEOJAC_CACHE_DIR/2/`.

```sh
NEOJAC_CACHE_DIR=/tmp/jaccache neojac build main.jac -o main
```

`2` is the format of what the cache holds. A neojac that keeps another format keeps it in a directory of that name beside this one, and neither touches the other's: an older neojac's `1/` stays until you delete it.

Beside the format's directory, neojac keeps `fetched/`: what a command downloads the first time it needs it, such as another platform's C libraries for a cross-build ([build](build.md#--target-building-for-another-platform)), a target's Rust standard library, or the browser `neojac browse` drives ([browse](browse.md#the-browser)). It is a cache too: anything in it is fetched again when it is missing. `browse/` beside it holds the directories of the browser sessions that are open.

neojac never writes into its own installation. What it makes for the toolchain's programs (CPython's interpreter, which a program using Python embeds) is kept in the cache too, so a release may be installed read-only.

Deleting the cache when no build is running is safe: the next build makes it again, and compiles everything once more.

## What it keeps

| In `2/` | What it is |
|---|---|
| `CACHEDIR.TAG` | The file that marks the directory as a cache ([the cache directory tag](https://bford.info/cachedir/)), so backup tools can leave it out |
| `objects/` | Compiled units: each Jac module compiled for a target, each C file, each C module's interface, each Rust crate, and the shared library a plain build links a program's Rust modules into. And each Jac module's record: what a later build takes the module by ([below](#modules-taken-from-an-earlier-build)) |
| `size` | How many bytes the cache holds, as the builds that added to it counted |
| `lock`, `size.lock` | The locks builds hold while they run, and while one adds to `size` |
| `sweep.lock`, `trash/` | The lock of the one build deleting what is over the cache's size, and what it has taken out of `objects/` and is deleting |
| `claims/` | An empty file for each Rust crate and build script's run a build has made here, which a build locks while it makes that one |
| `compilers` | Each neojac's identity, remembered by its executable's size and time so that it is computed once |
| `pystubs/`, `jsstubs/`, `typescript/` | What a build learned of Python packages' and npm packages' types, and the TypeScript neojac reads npm types and a project's TypeScript with. The TypeScript is one entry: placed whole, deleted whole, and fetched again by the next command that needs it |

A compiled Jac module is kept under a hash of the code generator (LLVM, and neojac's use of it to compile a unit), the target and the module's content, so a module that no edit touched is never compiled twice, by any build of neojac with that code generator: a neojac built from an edited compiler compiles again only the units whose code it generates differently. A C file is kept under the Clang that compiles it, its command line and every file it read, so it is compiled once for every copy of a project, every install of the same release, and every neojac with the same Clang. A program's C files are looked up together first: when no file any of them read has another size or time than at the last build, each one's object is the one that build found.

A Rust crate is kept under the rustc that compiles it, its command line and every file it read, each named by what it holds: the standard library's crates by where they are in the toolchain, not by where the toolchain is. Two neojacs with the same Rust toolchain, in two checkouts or two installs, compile a crate once. What a crate's build script writes (its `OUT_DIR`) is a folder of `objects/` that one run of the script makes and no build writes again: a script that runs with other inputs gets another folder, and a build whose inputs a script has run with reads that run's folder where it is.

### Its size, and what is deleted

Nothing in the cache is ever out of date: an entry is named by everything it was made from, so an edit makes a build look for another entry and leaves the old one as it was. What is deleted is deleted to keep the cache to a size, and only costs compiling it again.

`NEOJAC_CACHE_SIZE` gives that size: a number of bytes, or one followed by `K`, `M` or `G` (`500M`, `20G`). The size is the cache's: a run given it records it in the cache (`budget` beside the entries), and every run keeps the cache to the size recorded there, 10G where no run ever gave one, until a run is given another. So a run that gives no size never trims what another put there under a larger one.

```sh
NEOJAC_CACHE_SIZE=20G neojac build main.jac -o main
```

- A build marks each entry it uses as used now, and counts what it adds. That is all it does to the cache while the cache is under its size: its work there is in proportion to what it used, however much the cache holds.
- When the cache is over its size, a build that finishes deletes the entries used longest ago, and what it used itself last of all, until the cache holds three quarters of its size. Nothing waits on it: it lists and sizes the entries without a lock, then takes them out in holds of the cache's lock alone of a tenth of a second at most, each when no other build is inside, and gives the lock back between them; another build that starts meanwhile goes on at once. One build deletes at a time, and a build that finds another deleting leaves it to that one. An entry another build used since it was listed stays, and a directory is moved into `trash/` while the lock is held and deleted after, so a sweep that dies leaves its trash to the next.
- An edit compiles again only the units it changed: the module's own, the program's own unit, and a unit that took in a copy of a function the edit changed, to inline it ([build](build.md#--release); a `--release` build takes in more).
- A plain build's unit of a module is the same in every program that imports the module, so one program's build uses what another's compiled: the runtime and the standard library are compiled once for all of them. The units they replace stay until they are the ones used longest ago, so an edit undone finds them.
- A program deleted, or built with other options, leaves what it was made from in the cache. Alternating `neojac build main.jac -o main` and `neojac build main.jac -o main --release` compiles each of the two once.
- What a build that died left behind is counted when the cache is next measured, and goes as anything else does.
- Another format's directory beside `2/` is never touched.

## Builds running at once

Builds share the cache. Every command that uses it (a build, a check, a port, an absorb) holds the cache's lock, shared, from its start to its end, and a step inside a command (a port's check of what it writes, a reading of TypeScript) runs within the command's hold, never between two of its own. Entries are taken out only by a command that holds the lock alone, so none deletes what another is using, nor what a step of its own is about to read. When a command dies, the operating system releases its lock.

- Builds starting at the same moment into a cache that does not exist yet all succeed: the directory is made whole under a name of its own, with its tag, and moved into place.
- Builds that compile Rust crates run side by side, in one cache as in two. A build claims a crate, or a build script's run, while it makes it (a file of `claims/` it holds a lock on, which the system releases if the build is killed). Another build that needs the same one leaves it and does its other work; with nothing else to do it waits, and says so: `neojac: waiting for the crates another build is compiling`. Then it reads what the first made, or makes it itself if the first failed.
- A directory `NEOJAC_CACHE_DIR` names that holds files but no `CACHEDIR.TAG` was not made by neojac, and is refused rather than emptied:

```text
neojac: the build cache /tmp/jaccache/2 holds files and no CACHEDIR.TAG: neojac keeps its cache in a directory of its own, and deletes there what was used longest ago once it is over its size
```

## When a build has nothing to do

A build also records what it read, in the project's `.jac/build/` ([Projects](projects.md)), one record for each output. The next build of that output has nothing to do, and does not touch the output, when all of these are as they were:

- the compiler: the same neojac executable, by whatever name it was run, with the same toolchain (`lib/`, or what `NEOJAC_LIB_DIR` names);
- the command line: the same arguments, with the paths in it made absolute;
- the output: as the last build left it;
- every file the build read: each module, annex, `jac.toml`, C source and header, package declaration;
- every path the build looked for and did not find: a platform variant (`main.linux.jac`) or an annex that did not exist then makes the build stale once it does;
- every directory it scanned for annex parts (`main.<part>.impl.jac`): a new part makes it stale;
- every environment variable it read: changed, set where it was unset (even to an empty value), or unset. For a family of variables read by prefix, a new member counts too. The record keeps a digest, never a value;
- the project's wiring: its `archwire.jac` judged whole and found right, with nothing of it changed since ([below](#the-archwires-record)).

A file the build never looked for (notes, the program it wrote, `.jac/`) changes nothing, whatever it does to the directory's time. A build with `--emit-ir` or `--verify-reuse` always runs.

When a build does run, it compiles only the modules whose code changed, and links. A module rewritten with the same content compiles nothing.

### The archwire's record

Every command judges the project's `archwire.jac` whole: every file under it, whichever program the command was run for ([What a command judges](../language/modules-wiring.md#what-a-command-judges)). That judgment is of the project and not of a program, so it is made once and recorded once, in `.jac/build/` beside the builds' records. It stands while these are as they were:

- the compiler, `archwire.jac` and `jac.toml`;
- the wiring of every Jac module under it: the imports it writes, its `__all__`, and which of the names wired into it it spells;
- what its own engine read of every Python, JavaScript and TypeScript file under it: its imports and the names it gives;
- every file of a crate or a C module `jac.toml` holds;
- which source files and folders each of its directories holds.

So an edit is judged for what it changes:

| An edit | What the next command does |
|---|---|
| A function's body, a comment, a file that is no source | Nothing for the archwire. A program that loads the module is built, with no judging; any other is up to date |
| An import, a wired name no longer spelled, a file added or removed, `archwire.jac` itself | Judges the archwire once, whichever program it was run for. A program that reads nothing of what changed is then up to date, and its build does nothing more |
| Something that breaks the wiring | Every command reports it, for every program, until it is mended |

`neojac check` reads the same record: a check of a program whose project's wiring stands judges none of it again.

Commands started together on a project whose wiring changed judge it once between them: the first judges, and the others wait for what it finds, their status line saying so. `neojac test`, which builds its test modules together, pays for one judgment and not one for each.

## Modules taken from an earlier build

A plain build keeps, beside each module's compiled units, a record of the module: its objects, the functions other modules may take copies of to inline, and what it refers to. The next build of a program that holds the module takes it from the record, as it is, and generates no code for it. It does when all of these are as they were:

- the module's own source, annexes included;
- what every module of the program declares: its text but for the bodies of its functions. An edit inside a function's body changes this for no module; a new function, parameter, field, global or import does for all of them;
- what the bodies of the functions its code refers to decide for their callers, which the compiler works out for every function: whether it can raise, what it borrows, what it needs of the place it runs. An edit that changes that for one function has the modules that refer to it generated again, and no others;
- the program's own facts: its platform and options, its classes' layouts, which modules start when;
- what the module's code holds of the build that no source of it says: an app's plan, which the archwire and `jac.toml` make (the spaces it runs, the pages it serves and at what base, its profiles' arrangements, its settings, where it keeps its data), is in the code of the runtime's module that reads it. A change to the plan, moving the project elsewhere among them, has that module generated again;
- the compiler;
- what the module's code saw of each module whose functions it calls: those of that module's functions small enough to take a copy of. An edit to a large function there changes nothing here. An edit that changes a small one, or makes a large one small, has every module that calls into that module generated again.

So an edit inside one function's body generates code for that module, and for the modules that could have taken a copy of what changed. Anything else that is edited generates the program's code again; what that code compiles to is still taken from the cache, unit by unit, wherever it is the same.

The program's own unit (what is the whole program's: its classes' numbers, how a virtual call picks its method) is kept the same way, under the program's facts, what each module lets others copy, and the names and sizes of what the unit holds; a build that finds it neither generates copies for it nor compiles it.

A plain build also keeps what the ownership check found of each module, beside its record, with what each function's own body writes and calls. The next build does not check a module's ownership again when the module's source and what every module declares are as they were, the check reported nothing of it, and each edited function reaches what it did: the fields it and everything it calls may write. A call added to a function that writes nothing new changes that for no one. An edit that does change it has the modules whose check read the edited module checked again, and a module that is generated is always checked, since generating its code reads what the check finds. Whether each function can raise is kept the same way, with what it calls: after an edit only the edited module's bodies are read again, and the rest is worked out from what was kept.

A `--release` build, and one under the `nogc` memory profile, compile the program as a whole and take no module from a record.

A build that takes modules from records makes the same program as one that takes none. `--verify-reuse` checks that on a build: it works out which modules the build would take, generates every module's code all the same, and compares each of those records with what the code generated now comes to. It fails, naming the modules, when one differs:

```text
neojac: what the build cache holds of m3 is not what the sources make now: 1 of the 23 modules a build would take from it
```

That is a defect in neojac (a record kept under too little of what it was made from), or a cache that something else wrote to. The build after it takes nothing stale: the check leaves the records it made.

Apps follow the same rule, step by step: a space is compiled again only when something its compile read changed, bundled again only when a file its bundler read changed or a path it looked for appeared, and the program rebuilt only when its sources changed ([Building apps](../apps/building.md)).

## The same bytes

A plain build of the same sources to the same output path writes the same bytes from an empty cache and from a full one. On macOS a plain build's debug map names the cache's object files by where they are on the machine that built it; a `--release` build is linked without one, so it is the same bytes wherever it is built ([build](build.md#--release)).

## What goes wrong

| Message | Cause |
|---|---|
| `the build cache <dir> holds files and no CACHEDIR.TAG` | `NEOJAC_CACHE_DIR` names a directory with other files in its `2/`. Name an empty or new directory |
| `cannot make the build cache <dir>` | The directory cannot be created: check its parent's permissions |
| `waiting for the crates another build is compiling` | Not an error: another build in this cache is compiling Rust crates this one needs, and this one reads them once they are made |
| `NEOJAC_CACHE_SIZE is the build cache's size in bytes, or with K, M or G after it (10G), not '<value>'` | The variable holds something else: write a number, or one with `K`, `M` or `G` |
