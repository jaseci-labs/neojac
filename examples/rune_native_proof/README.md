# Native Rune linking baseline (#90)

This is the first implementation slice of [#90](https://github.com/jaseci-labs/neojac/issues/90),
under epic #89. It builds real Rune and rune-kit with neojac 0.5.3, compares a Rust
reference against a Jac caller, and checks a captured Jac callback during real Rune input.
The Jac build uses neojac's native Rust-module linker; it does not load the historical probe library.
The development build may emit companion shared libraries beside the executable; keep them together.

This baseline does **not** satisfy the whole milestone. The tree is currently built
in Rust. General typed Jac imports, automatic application shutdown and
runtime-lock release remain separate acceptance gates. The synchronous callback
context lives until `rune_check` returns. No later callback may use it.

## Build

Use Linux x86_64, neojac 0.5.3 (build `4da9bcccf875`), Meson, Ninja, Bison,
pkg-config and a Vulkan implementation for snapshots. `inputs.json` records pins.
The eight Cargo patches are required by Rune, including platform-specific patches.

Build the pinned libxkbcommon with neojac cc (Python 3.12+ required):

```sh
python3 prepare.py --neojac /absolute/path/to/neojac --cache /absolute/path/to/cache
```

Export the static-library directory printed by the preparer:

```sh
export RUNE_PROBE_XKB_LIB_DIR=/absolute/path/to/xkb-build
export CARGO_BUILD_JOBS=2
export CARGO_TARGET_DIR=/absolute/path/to/persistent/target
python3 verify.py --neojac /absolute/path/to/neojac
```

The verifier runs the real Rust reference, builds and runs the Jac executable,
compares their complete stdout (button center, toggled state and callback result), records executable
ELF dependencies, and rejects a dependency on the historical probe library.
Results and command logs go to `artifacts/`; missing prerequisites fail visibly.
Pass `--snapshot` to additionally render an offscreen PNG with the Rust reference.
An offscreen PNG is not proof of an interactive window. To open the Rust window:

```sh
neojac cargo run --locked --manifest-path native/Cargo.toml -- --window
```

## Remaining dependencies

The public repository explicitly excludes compiler source. The release reproduces
missing reexports, `impl Into<String>`/closure bindings, dependency-type shim errors,
and no worker progress during the timing-based blocking Rust fixture. That result
is evidence for investigation, not a deterministic proof of lock ownership. See the historical probes in
`plans/rune-ui-probes.py`; rerun them to generate current evidence. The threading
documentation describes automatic unlock points but does not expose a supported
foreign-wait enter/leave API. Do not call guessed private runtime symbols.

The compiler repository/build owner and paired fix artifact are still required to
implement those gates. Neither a C-only widget whitelist nor passing this baseline
closes #90.

## Retained callback baseline

`ownership.jac` registers a captured handler in a function, returns its handle,
and only then dispatches real Rune pointer input. The Rust state and retained
Rune closure share an `Rc` token; its final drop releases the Jac hold through a
named, non-throwing release callback. Eight create/click/close cycles require
exactly eight releases and reject post-close dispatch and duplicate close.
Handles are monotonic process-wide identities, stored per UI thread; a handle
from another thread is rejected. Explicit close on the registering thread is
required before runtime retirement. Dispatch temporarily removes its runtime
from the registry, so recursive operations on the same handle are rejected.

This establishes the bounded ownership path. Replacement, queued work, foreign-thread
release, exception traces, automatic application shutdown and depth-aware runtime
entry still need the later protocol and tests. Do not use this baseline as a
production UI host.
