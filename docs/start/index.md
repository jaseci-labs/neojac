---
description: What neojac is, what one download contains, the platforms it runs on and builds for, and where to go next.
keywords: neojac, release, platform
---
# What neojac is

neojac is a native-first implementation of the Jac language. Its compiler is written in Jac and compiles itself. It compiles a program, with neojac's own runtime, into one native executable through LLVM; nothing has to be installed where that executable runs.

```sh
echo 'with entry { print("hello from neojac"); }' > hello.jac
neojac build hello.jac -o hello
./hello
```

```text
hello from neojac
```

neojac defines the Jac language it compiles. It is not jaseci's `jac` with another backend: some forms `jac` accepts are errors here (see [Lint rules](../toolchain/lint.md) for the spellings neojac rejects). Read the language pages instead of assuming what `jac` or Python does.

## One command

Everything is a subcommand of `neojac`. `neojac` alone, or `neojac help` (`--help`, `-h`), lists them; `neojac help <command>` and `neojac <command> --help` (or `-h`) say what one takes, with examples; `neojac --version` (or `-V`, or `neojac version`) names the release, the platform it runs on and the commit it was built from. A command that is another program's command line (`python`, `node`, `npm`, `cc`, `cargo`, ...) passes `--help` to that program, and an option after `--` belongs to the program being run (`neojac run web -- --help`).

| Group | Commands | What they do |
|---|---|---|
| Learn | `docs`, `skills` | Print this documentation, and playbooks for common tasks |
| Build and run | `build`, `run`, `dev`, `check`, `test`, `fmt`, `port`, `precommit`, `launch` | Compile a program or a project's apps, run an app, work on one as it rebuilds, check for errors, run tests, format source, translate source in another language, check a commit, and launch an app on the hosting platform |
| Packages | `install`, `remove`, `absorb`, `packages`, `npm`, `npx` | A project's packages of every ecosystem, a repository's manifests taken into `jac.toml`, and npm on neojac's Node |
| Runtimes and toolchains | `python`, `node`, `cc`, `c++`, `cargo`, `rustc`, ... | The CPython, Node, Clang and LLD, and Rust that neojac carries |
| Inspect | `lsp`, `query`, `browse`, `arch`, `parse`, `grammar`, `emit-js`, `emit-py` | The language server and its answers, a browser it drives, a project's architecture drawn, syntax trees, the grammar, and what a space compiles to |
| About neojac | `help`, `version` | The commands, and the release |

[Commands](../reference/commands.md) has every command with its options.

## The documentation is in neojac

`neojac docs` prints these pages. Every release carries them, for its own version, and reading them needs no network:

```sh
neojac docs                   # the map: every section and its pages
neojac docs section basics    # a section's pages, each with what it covers
neojac docs start/first-program
neojac docs walker            # the page that defines a word
neojac docs E1030             # what an error code means, and the fix
neojac docs search edge filter
```

A word can be a page's name, a keyword or operator of the language, a builtin, a module, a diagnostic code, a command, a `jac.toml` key or an environment variable. `neojac skills` lists playbooks for common tasks, written for agents. See [docs and skills](../toolchain/docs.md) (`neojac docs toolchain/docs`).

A command given something it does not take says what was wrong, shows its usage, and names the nearest command or option when a word is mistyped. That goes to stderr with exit status 1; help is an answer, so it goes to stdout with status 0.

```sh
neojac buld hello.jac
```

```text
neojac: 'buld' is not a neojac command (did you mean 'build'?)

Run `neojac help` for the commands.
```

## What one download contains

A release is one file, `neojac` (`neojac.exe` for Windows), downloaded as `neojac-<version>-<platform>.gz` (`.exe.gz` for Windows). It needs no system compiler, SDK, Python, Node or Rust, and nothing is installed beside it.

The file is the executable, and inside it, compressed, everything the executable reads and everything it links into the programs it builds:

| Inside neojac | What it is |
|---|---|
| The executable's own code | The Jac compiler, with Clang, LLD, `rustc` and `cargo`: the tools below under their own command lines |
| `rt/` | The runtime, as Jac source: the builtins, the standard library, `stdjac`. Every program is compiled with it |
| `abstractions/`, `libraries/` | The abstractions a program speaks of, their standard plugins, and the libraries those are made with |
| `docs/` | This documentation and the skills, which `neojac docs` and `neojac skills` print |
| `lib/clang`, `lib/libc`, `lib/libcxx`, `lib/libunwind`, `lib/targets` | Clang's headers, and the C library headers and the C and C++ runtimes of every platform neojac builds for |
| `lib/clibs` | The C libraries CPython's standard library and Node are built on, for this platform |
| `lib/cpython` | CPython 3.15, to link into a program: its libraries for this platform, its standard library, its headers |
| `lib/node` | Node, to link into a program: its libraries for this platform, its headers, and npm |
| `lib/rust` | Rust's standard library, for the `rustc` that is neojac |
| `VERSION` | The release's version, the commit it was built from, and where its release is fetched from |

Each of them is in the file once. neojac reads Clang's headers out of itself as it compiles; the rest it writes out, a part at a time, into its cache the first time something has to open that part as a file, and reads there from then on ([The build cache](../toolchain/cache.md#what-neojac-writes-out-of-itself)). The cache can be deleted at any time: the next command writes out again what it needs.

What is for another platform (its C libraries, its CPython, its Node) is inside that platform's neojac. The first build for another platform fetches that file from the same release, checks it against the release's checksum, and reads those parts out of it.

The tools are neojac itself, not separate installs:

| Command | Runs |
|---|---|
| `neojac python` | CPython 3.15, with its own command line, in neojac's own process: a part of it, loaded from a library it builds of the CPython it carries the first time |
| `neojac node`, `neojac npm`, `neojac npx` | Node, and the npm it ships: a part of neojac the same way |
| `neojac cc`, `neojac c++`, `neojac ar`, `neojac ld.lld`, ... | Clang and LLD, compiling C and C++ for any platform neojac builds for |
| `neojac cargo`, `neojac rustc`, `neojac rustdoc` | The Rust toolchain, built against the same LLVM |

## Platforms

Releases run on:

| Platform | Notes |
|---|---|
| `linux-x86_64` | |
| `linux-aarch64` | |
| `macos-aarch64` | Apple Silicon. There is no Intel macOS release |
| `windows-x86_64` | `neojac.exe`, built on Linux and not yet tested on Windows. The installer does not install it |

A neojac on any of them builds programs for all of these, and for `macos-x86_64` and `wasm32-wasi` (WebAssembly), with `--target`. See [build](../toolchain/build.md).

## Where to go next

| To | Read | Or run |
|---|---|---|
| Install a release | [Install](install.md) | `neojac docs start/install` |
| Write, check, build and run a program | [A first program](first-program.md) | `neojac docs first-program` |
| Build programs, and cross-compile | [build](../toolchain/build.md) | `neojac docs toolchain/build` |
| Find errors without building | [check](../toolchain/check.md) | `neojac docs toolchain/check` |
| Run tests | [test](../toolchain/test.md) | `neojac docs toolchain/test` |
| Set up a project | [Projects](../toolchain/projects.md) | `neojac docs toolchain/projects` |
| Configure a project | [jac.toml](../reference/jac-toml.md) | `neojac docs jac.toml` |
| Find a page, a word or an error code | [docs and skills](../toolchain/docs.md) | `neojac docs toolchain/docs` |
