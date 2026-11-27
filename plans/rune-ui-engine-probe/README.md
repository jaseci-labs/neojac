# Real Rune research fixture

This fixture exercises real Rune and rune-kit through neojac's Rust toolchain.
It is evidence for the implementation plan, not the implementation of native Jac
JSX. The Jac caller loads the research library through a C ABI; this does not
prove static Jac/Rust linking or broad direct binding of Rune's public API.

On Linux, first build libxkbcommon 1.7.0 with `neojac cc`, using Meson, Bison and
Ninja. Disable X11, Wayland tools, documentation and xkbregistry for the core
static library. The VM experiment used:

```ini
# neojac-native.ini (adjust the executable path)
[binaries]
c = ['/data/home/.local/bin/neojac', 'cc']
ar = '/usr/bin/ar'
strip = '/usr/bin/strip'
```

```sh
meson setup xkb-build xkb-source --native-file neojac-native.ini \
  --buildtype=release -Ddefault_library=static \
  -Denable-x11=false -Denable-wayland=false -Denable-tools=false \
  -Denable-docs=false -Denable-xkbregistry=false \
  -Denable-bash-completion=false
ninja -C xkb-build -j2 libxkbcommon.a
```

The fixture also builds `compat.c` through Cargo's `cc` integration. Rune's
window path references `memfd_create`, whose libc entry point appeared after
neojac's glibc 2.17 baseline. The shim invokes the Linux syscall directly. It
does not suppress unresolved-symbol checks or link a newer host libc.

Set `RUNE_PROBE_XKB_LIB_DIR` to that build directory, and choose a persistent
Cargo target directory with enough disk space. Then run:

```sh
neojac cargo run --manifest-path plans/rune-ui-engine-probe/Cargo.toml
neojac cargo build --manifest-path plans/rune-ui-engine-probe/Cargo.toml --lib
neojac build plans/rune-ui-engine-probe/main.jac -o rune-jac-probe
./rune-jac-probe /path/to/target/debug/librune_actual_probe.so
```

The first command checks real layout and a retained Rune click handler. The last
command checks that the handler calls a captured Jac closure and returns `42`.
No Rust callback retains the Jac context after the synchronous probe returns.

For an offscreen PNG, the debug executable accepts Rune's `--snap <path>` flag.
This needs a working graphics adapter, such as Mesa's software Vulkan driver in
a VM. That is a separate test from CPU layout/input.

The recorded VM run used the exact pinned Rune archive and local path overrides
to the same eight patched dependencies, avoiding another Git download. The
manifest here specifies those same upstream revisions directly. Its dev profile
disables debug info and incremental compilation to limit build storage.
