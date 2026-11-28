---
description: The Rust toolchain neojac carries - neojac cargo, rustc and rustdoc, the Rust targets and how each links, another target's standard library on first use, C in a crate's build, and neojac build of a Cargo.toml.
keywords: Rust, Rust toolchain, Rust target, wasm32-wasip1, Rust standard library
---
# Rust

`neojac cargo`, `neojac rustc` and `neojac rustdoc` run Rust 1.99, for every target below, from
any machine neojac runs on, with nothing else installed. They are the same Rust that compiles a
program's [Rust modules](rust-modules.md), and share one LLVM with neojac.

```sh
neojac cargo build --release                                # this machine
neojac cargo build --target x86_64-unknown-linux-musl       # a static Linux program
neojac cargo build --target aarch64-apple-darwin            # macOS on Apple silicon
neojac rustc --target x86_64-pc-windows-gnullvm main.rs     # Windows
neojac rustc --target wasm32-wasip1 main.rs                 # WASI
neojac cargo test                                           # unit tests and doctests
```

Each takes its tool's own command line: `neojac cargo --help` is cargo's help, and
`neojac cargo` exits with cargo's own statuses (101 for an unknown command, 1 for a bad flag).
There is no rustfmt or Clippy: `neojac cargo fmt` and `neojac cargo clippy` are unknown commands.

## Targets

| Rust target | Linked by |
|---|---|
| `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` | [`neojac cc`](c-and-cpp.md) for glibc 2.17 and later |
| `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl` | `neojac cc` for musl, static |
| `x86_64-apple-darwin`, `aarch64-apple-darwin` | `neojac cc` for macOS |
| `x86_64-pc-windows-gnullvm` | `neojac cc` for mingw-w64 with the Universal CRT (the Rust host on Windows) |
| `wasm32-wasip1` | LLD's `wasm-ld`, with the WASI C library neojac ships |

On macOS, a crate may link the system's libraries and frameworks (`#[link(name = "iconv")]`,
`#[link(name = "Foundation", kind = "framework")]`): the toolchain carries stubs of them, so a
build for macOS from any machine links.

## Another target's standard library

neojac carries the standard library of its own machine's target. Another target's is
compiled from source the first time a build names it, by neojac's own rustc, in under a minute on
a large machine:

```text
neojac: compiling Rust's standard library for x86_64-unknown-linux-musl
```

neojac fetches the source and keeps it and what it compiled beside the build cache, in a directory
`fetched/`; nothing is written beside neojac. Only that first build needs the network.
What it compiled is kept by what it was made from: the library's source, the rustc that compiled
it, and the arguments each of its crates was compiled with. A neojac that compiles the library the
same way takes what is there, and one that compiles it another way compiles its own.
`neojac rustc --print sysroot --target <target>` prints where a target's standard library is: the
one neojac carries for its machine, written out in its cache, the fetched one for any other.

## C and C++ in a crate's build

Every target's C and C++ compiler is `neojac cc` and `neojac c++`. cargo runs them through links to
neojac in its cache (`x86_64-linux-musl-cc`, `ar`, ...), each of which runs the tool its name
says, and sets the `cc` crate's `CC_<target>`, `CXX_<target>` and `AR_<target>` to them. So a crate
whose build script compiles C (with the `cc` crate) builds for any target, from any machine.

## Building a Rust program with `neojac build`

```sh
neojac build app/Cargo.toml -o app            # a plain build
neojac build app/Cargo.toml -o app --release
```

`neojac build` given a crate's `Cargo.toml`, or the directory that holds it, builds the Rust program
it describes ([build](../toolchain/build.md#what-a-program-is)), with no Jac, as it
builds a [Rust module](rust-modules.md): each crate compiled by neojac and kept in the build cache,
so a rebuild compiles what changed. It does so in a project whose archwire declares apps too.

It builds for this machine, and takes `-o` and `--release`. Every other option of `neojac build` is
a Jac program's, and is refused with a crate: `--target` among them, since
`neojac cargo build --target <target>` builds a crate for another target. A manifest given to
`neojac check` or `neojac test` is refused too; `neojac cargo check` and `neojac cargo test` are
cargo's.

```text
neojac build: a crate's build takes -o and --release, and '--target' is an option of a Jac program's build: `neojac cargo build --target x86_64-unknown-linux-gnu` builds a crate for another platform
```

## How the tools are installed

- The tools are part of neojac, on every platform: `neojac rustc`, `neojac rustdoc` and
  `neojac cargo` run them, and what starts one by its name (cargo starting `rustc`, a build script
  starting `cargo`) starts a link to neojac in its cache, which runs as the tool it is named
  ([The build cache](../toolchain/cache.md#what-neojac-writes-out-of-itself)). On Windows a name is
  a small launcher in place of a link.
- `neojac rustc -vV` prints rustc's version, and two lines of 64 hex digits each, which are how
  cargo tells one build of the toolchain from another. `neojac-build:` names the build of rustc.
  `neojac-std:` names the standard libraries that rustc compiles against, as they are installed
  here: one neojac's rustc compiles the standard library as that neojac plans it, so the same
  rustc is not always the same standard library. cargo compiles again what it compiled under
  other lines.

## Differences from rustup's Rust

- rustup installs one standard library per target with `rustup target add`. Here a target's
  standard library is compiled on its first use, and every target links with neojac's own linkers,
  with no system C toolchain.
- cargo and rustc behave as upstream's otherwise: `Cargo.toml`, `Cargo.lock`, `.cargo/config.toml`,
  `RUSTFLAGS` and `CARGO_INCREMENTAL` mean what they mean for rustup's cargo.
