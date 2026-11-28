---
description: neojac cc and c++, the C and C++ compilers neojac carries, and the other tools (clang, ar, the LLD linkers, objcopy) - compiling for any target from any machine, the targets and their C libraries, and using them from build systems.
keywords: neojac cc, C toolchain, C compiler, C++ compiler, clang, libc++, glibc, musl, mingw-w64, -target
---
# C and C++

`neojac cc` and `neojac c++` compile and link C and C++ for any of neojac's targets, from any
machine neojac runs on, with nothing else installed. Clang and LLD are inside neojac, and so
are each target's C library headers and a prebuilt C and C++ runtime (the toolchain's `lib/`,
which the one file carries). The command line is Clang's.

```sh
neojac cc hello.c -o hello                                  # this machine
neojac cc -target x86_64-linux-musl hello.c -o hello        # a static Linux program
neojac cc -target aarch64-linux-gnu.2.28 hello.c -o hello   # Linux, glibc 2.28 and later
neojac c++ -target x86_64-windows-gnu app.cpp -o app.exe    # Windows
neojac c++ -target aarch64-macos.15.0 app.cpp -o app        # macOS 15 and later
```

These are the same compiler and linker `neojac build` uses for a program's [C modules](c-modules.md)
and its link. A program built with them is an ordinary native program for its target.

## Targets

| Target | C library | Notes |
|---|---|---|
| `x86_64-linux-musl`, `aarch64-linux-musl` | musl | Static executables |
| `x86_64-linux-gnu[.2.N]`, `aarch64-linux-gnu[.2.N]` | glibc | Dynamic, for glibc 2.N and later; 2.N from 2.17 (the default) to 2.44 |
| `x86_64-windows-gnu` | mingw-w64 with the Universal CRT | `-mwindows` for a GUI program, `-municode` for `wmain`, `-shared` for a DLL |
| `aarch64-macos[.N.M]`, `x86_64-macos[.N.M]` | libSystem | For macOS N.M and later; 14.0 is the default and the oldest |

- `-target` also takes LLVM triples (`x86_64-unknown-linux-gnu`, `x86_64-w64-mingw32`,
  `arm64-apple-macosx14.0`) and neojac's platform names (`linux-x86_64`).
- Without `-target`, `cc` compiles for this machine; on Linux that is glibc 2.17.
- A glibc version selects that release's headers and its link stubs: a function newer than the
  version asked for is not declared, and a program built for 2.17 references no symbol version
  newer than 2.17. It runs on that glibc and every later one.
- C++ uses LLVM's libc++, linked statically: the program needs no C++ runtime on the machine it
  runs on. `-std=c++23` with `<format>` and `<filesystem>` works on every target.
- On macOS the toolchain carries stubs of libSystem and of the CoreFoundation, Foundation, Security
  and SystemConfiguration frameworks. For other frameworks, name an SDK to compile and link
  against: `-isysroot <sdk>`, or the `SDKROOT` environment variable. `SDKROOT` is taken by a
  [C module](c-modules.md)'s build and by the reading of its files too, so a module that uses
  another framework (`IOKit`) builds, and is read for its wires, where the variable is set.

| Message | Cause |
|---|---|
| `unsupported target '<t>': the architecture is x86_64 or aarch64` | Another architecture, or `wasm32-wasi`, which `cc` does not target |
| `the oldest glibc neojac cc targets is 2.17` | A glibc version before 2.17 |
| `glibc 2.N is not a glibc release neojac cc knows (2.17 to 2.44)` | A version past the newest |
| `the oldest macOS neojac cc targets is 14.0` | A macOS version before 14.0 |

## What links

- A program links its target's C library, start files and compiler runtime, which neojac carries, and libc++
  and its ABI library for C++ (with libunwind, except on macOS).
- `-l` naming a part of that runtime (`-lc`, `-lm`, `-lpthread`, `-lgcc`, `-lgcc_s`, `-lunwind`,
  `-lSystem`, `-lmingw32`, `-lmsvcrt`, ...) links the toolchain's piece of it, so a link with
  `-nodefaultlibs` that names its runtime libraries, as a Rust program's link does, works on every
  target.
- On Linux targets, `-gz=zlib` and `-Wl,--compress-debug-sections=zstd` compress the debug
  information.
- `-print-file-name=<file>` prints the path of that file of the target's runtime
  (`neojac cc -target x86_64-windows-gnu -print-file-name=crt2.o`), or the bare name when the
  runtime has none, as Clang does.

A shared library is built as Clang builds one: `-shared -fPIC` for Linux, `-shared` (or `-bundle`)
for macOS, `-shared` for a Windows DLL. That is how a CPython extension module or a Node addon is
built for neojac's own interpreters; see [Python](python.md) and [npm and Node](npm.md).

## The other tools

| Command | Runs |
|---|---|
| `neojac clang`, `neojac clang++` | Clang's driver, as it is, without neojac's target setup |
| `neojac ar`, `ranlib`, `dlltool`, `lib` | llvm-ar's tools |
| `neojac ld.lld`, `ld64.lld`, `lld-link`, `wasm-ld` | LLD, for each object format |
| `neojac objcopy --strip-debug\|--discard-all\|--strip-all <file>` | Strips one file in place |

Each takes its tool's own command line, `--help` included. They are there for build systems that
want them by name:

```sh
make CC="neojac cc" CXX="neojac c++" AR="neojac ar"
```

```sh
neojac cc -target aarch64-linux-gnu -O2 -c counter.c -o counter.o
neojac ar rcs libcounter.a counter.o
neojac ar t libcounter.a
neojac cc -target aarch64-linux-gnu main.c -L. -lcounter -o main
```

The headers and runtimes come from inside neojac: Clang reads the headers out of it as it
compiles, and the linker reads a target's runtime where neojac wrote it out in its cache the first
time that target was linked. See [Building programs](../toolchain/build.md#how-the-runtime-is-found)
(`neojac docs build`).

## Recording what a build ran

A build system that is given neojac's tools can be asked what it ran. Where `NEOJAC_RECORD_TO`
names a file, each run of `neojac cc`, `c++`, `clang`, `ar` and the other tools above, and each
run of [`neojac cargo`](rust.md), appends one line to it, a JSON object:

```sh
NEOJAC_RECORD_TO=$PWD/runs.jsonl make CC="neojac cc" AR="neojac ar"
```

```text
{"tool": "cc", "cwd": "/work/counter", "args": ["-O2", "-c", "counter.c", "-o", "counter.o"], "inputs": ["counter.c"], "output": "counter.o"}
{"tool": "ar", "cwd": "/work/counter", "args": ["rcs", "libcounter.a", "counter.o"]}
{"tool": "cc", "cwd": "/work/counter", "args": ["main.c", "libcounter.a", "-o", "main"], "inputs": ["main.c", "libcounter.a"], "output": "main"}
```

| Key | What it holds |
|---|---|
| `tool` | The tool, by the name it was run by: `cc`, `c++`, `ar`, `ld.lld`, `cargo`, ... |
| `cwd` | The directory it was run in. The paths in the other keys are as they were written, from there |
| `args` | Its arguments, as given |
| `inputs`, `output` | For `cc` and `c++` alone: the files the command line names as inputs, sources, objects and libraries alike, and what `-o` names (`""` where there is no `-o`), as Clang's own option parser reads them |

- The variable is passed on, so a build that runs other builds (pip running a package's
  `setup.py`, cargo running a crate's build script) records every one into the same file.
- A record is of the run and not of its result: a compile that fails is recorded too.
- With the variable unset nothing is written.

## Differences from a system toolchain

- A system `cc` builds for the machine it is on, against that machine's C library. `neojac cc`
  builds for any target from any machine, against the C library and runtime it carries for that
  target, so a Linux program built on macOS needs no Linux system to link.
- The C++ standard library is always libc++, linked statically, not the system's libstdc++ or
  libc++ library.
- glibc is chosen by version (`.2.N`), not by the glibc installed where the program is built.
