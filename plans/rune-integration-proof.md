# Implementation plan: native Jac/Rune integration proof (#90)

Parent epic: https://github.com/jaseci-labs/neojac/issues/89
Implementation milestone: https://github.com/jaseci-labs/neojac/issues/90

## What are we doing?
Implement Milestone A of #89: one Jac/Rust executable that renders real Rune UI on Linux, invokes a retained captured Jac callback, and shuts down safely.

## Why?
The epic's research proves individual pieces through a shared library. It has not established native executable linking, general Rust bindings, or callback lifetime and runtime-lock safety together. Those boundaries must work before JSX and component lifecycle work begins.

## What will it look like?
```text
Jac main → typed Rune builders → linked Rune application → Linux window
                                   ↓ retained input
                              Jac captured state
                                   ↓ shutdown
                          zero live callback roots
```

## What do I need to decide?
Nothing for this scope. Use the assigned VM and Linux first. Compiler source access, ownership, and a compatible build are open dependencies to resolve during setup; no owner or compiler API is assumed.

## How do we know it works?
**Planned verification:** a clean build produces one Jac/Rust executable; real window and headless paths render; Jac and Rust reference trees agree; a callback runs after registration returns; synchronized workers progress during Rune waits; replacement, exceptions, and shutdown leave balanced roots and drops. Record exact revisions and reproduction commands.

<details>
<summary>1. Scope, established evidence, and implementation environment</summary>

**Known from the epic:** Rune revision `41cfc073ca5845f1d689a41535d796f37a8f7eba` supported real layout, input, offscreen rendering, and captured Jac callbacks through a research shared library. The tested compiler had gaps in public reexports, dependency types in generated shims, string-conversion signatures, and worker progress during foreign calls. These findings must be reproduced against the selected compiler; they are historical evidence, not current results.

**Observed during planning:** the assigned VM is reachable. A fresh public checkout at `/data/workspace/neojac` is at `3f8a290d7f71df41f117aae9a7b9ce948b41318b`. It lacks the local `plans/` research files, and `neojac` is not on PATH. The public repository does not contain compiler source.

All editing, builds, tests, and evidence generation must run on VM `neojac-codex-20261126`, ID `m_agrbupqeoajqutpyoal2xlluvq`, SSH user `jac`. Use the saved agent credential through:

```sh
/home/jac/.config/instabox/agents/neojac-codex/instabox exec neojac-codex-20261126 -- <command>
```

Never print or copy the API key into the repository. Persistent checkout and build data stay under `/data`. Record available CPU, RAM, disk, desktop session, and drivers before choosing build concurrency; start with two Cargo jobs.

**In scope:** epic stages 0–2 as bounded by #90: pins, inventory, native linking, exercised typed binding fixes, callback ownership, foreign-entry lock protocol, headless/window proof, and reproducibility.

**Deferred:** JSX lowering, generic component frames/hooks/effects, async I/O embedding, complete editor/IME behavior, broad API implementation, macOS/Windows, optimization and release packaging. The epic's editor adapter belongs to Milestone B under the current #90 scope; include its binding signatures in the inventory now. Rune's commit-hook patch is a later component-runtime dependency, not a reason to delay this proof.

</details>

<details>
<summary>2. Work package A — recover inputs and establish compiler access</summary>

1. Create a dedicated branch on the VM after inspecting worktree state; preserve existing work.
2. Recover the complete fixtures from the epic's evidence comment:
   https://github.com/jaseci-labs/neojac/issues/89#issuecomment-7205664713.
   Restore the engine fixture, signature probes, results JSON, and README into a clearly marked research directory. Preserve provenance and distinguish historical from newly generated results.
3. Identify compiler/runtime repository, implementation owner, source access, build instructions, artifact location, and version pairing mechanism. Verify access and run its smallest existing build/test before depending on it. Record unavailable dependencies with their exact failure and linked task; continue independent Rust/reference work.
4. Install or obtain an explicitly versioned neojac build on the VM using the project's documented distribution process. Verify executable path, version, build identity, Rust toolchain, target, and shipped public-runtime revision.
5. Create a machine-readable input manifest recording the public checkout, compiler/runtime build, Rune/rune-kit revision, all eight workspace patches from the fixture, Cargo features, target, XKB version/build flags, compatibility source, and tool versions.
6. Restore/generate Cargo lockfiles. Keep ordinary dependency updates out of this milestone.
7. Produce an initial public API inventory from pinned Rune/rune-kit source, including reexports and feature/platform gates. Classify symbols as exercised, untested, unsupported with linked reason, or excluded by feature/platform. Require complete classification, not complete implementation.

**Deliverables:** restored probes, input manifest, lockfiles, inventory generator/output, dependency/owner ledger, setup README.

**Exit:** version report is reproducible; compiler access/build path is established or explicitly blocking dependent packages; recovered fixtures have recorded provenance. No test is marked passed from historical results alone.

</details>

<details>
<summary>3. Work package B — build the real Rust reference and native dependencies</summary>

1. Build the upstream hello-equivalent using neojac Cargo against the frozen Rune revision. Retain real Rune and rune-kit; do not substitute lookalike builder fixtures for integration.
2. Reproduce the baseline-compatible XKB build from the evidence fixture: libxkbcommon 1.7.0 built with neojac's C toolchain, static core, documented disabled tools/integrations. Verify that the resulting configuration supports the selected window backend.
3. Compile the Linux `memfd_create` syscall compatibility shim once in the adapter's native dependency graph. Confirm it is necessary with the selected toolchain. Preserve errno behavior and fail visibly on unsupported targets; do not weaken unresolved-symbol checks.
4. Preserve the eight upstream workspace patches and explicit features from the research manifest. Inspect the resolved dependency graph for duplicate Rune versions and mismatched defining-crate identities.
5. Build a deterministic Rust reference tree using real layout, text, typed enum/color values, consuming child builders, context reads, and rune-kit Switch construction.
6. Add three reference modes: structural/layout report, offscreen PNG, and interactive Linux window. Use fixed dimensions, assets, and controlled inputs for comparisons.
7. Record actual window backend, DISPLAY/Wayland environment, graphics adapter/driver, software rendering if used, and required dynamic libraries. A headless image does not prove a window path.

**Exit:** native Rust reference runs on the VM, produces structural evidence and a PNG, and opens a visible window. If display access fails, record the blocker while continuing headless work; the window gate remains open.

</details>

<details>
<summary>4. Work package C — fix the exercised compiler binding boundaries</summary>

Make each compiler change independently reviewable, with non-UI regression fixtures in the compiler repository.

| Boundary | Implementation | Required regression |
|---|---|---|
| Public reexports | Resolve public reexport paths to canonical definitions, respecting visibility, renames, nested paths and cycle detection | Direct and renamed reexports import; private paths reject; cycles terminate |
| Dependency-defined return/argument types | Carry defining-crate dependencies into generated shim manifests and preserve canonical type identity | Factory from crate A returns crate B type; method/argument round trip builds without E0433 |
| String conversion signatures | Expose the exercised `impl Into<String>` methods through a typed conversion supported by the binding model | Jac string succeeds; invalid type rejects; owned temporary remains valid across consuming calls |
| Consuming and borrowed builders | Preserve ownership moves and borrow lifetimes through generated calls | Real `El.child`, typed colors/enums and context reads compile and behave like Rust |
| Retained closures | Use the epic's explicit typed adapter and held Jac context until general closure support has a proven contract | Captured callback survives registration return and releases on final foreign owner |

Re-run historical signature probes first: a gap already fixed in the selected build needs verification rather than another implementation. Add concrete file targets only after compiler source inspection; do not invent source paths or runtime primitives.

The Rune adapter may bridge retained callbacks and genuinely unsupported signatures. It must not replace general reexport/type fixes with a permanent C-only widget whitelist.

**Exit:** targeted compiler regressions pass, real Rune binding cases compile, and paired compiler/public revisions are recorded.

</details>

<details>
<summary>5. Work package D — link Jac and Rune into one executable</summary>

1. Use the compiler's supported native Rust crate/linking path to embed the pinned Rune dependency graph in the Jac application.
2. Retain the research shared-library runner solely as a diagnostic control. The acceptance executable must not load a Rune probe library at runtime.
3. Construct the exercised tree from Jac through typed imports and the minimal ownership adapter. Run the same fixed inputs against the Rust reference.
4. Compare canonical tree/layout data: element kinds, child order, text, dimensions within a declared tolerance, typed state and Switch state. Use images as supporting rendering evidence; only require pixel equality where backend/font configuration makes it stable.
5. Inspect link metadata/dependency output to prove Jac and Rune code reside in the same executable and only one pinned Rune graph is linked. “Single executable” permits documented Linux system/driver libraries; it does not claim a fully static libc/GPU stack.
6. Build both headless and window modes from the same pinned source/profile. Test debug and release before closing the milestone.

**Exit:** one Jac/Rust executable produces matching reference evidence, offscreen rendering and a real Linux window without the research shared library.

</details>

<details>
<summary>6. Work package E — implement retained callback ownership</summary>

**Proposed internal contract:** registration identity contains root ID, handler ID, generation, payload signature and lifecycle state. Reserve component identity for the later component runtime. Keep the ABI private and version it with the paired runtime.

1. Store captured Jac state in a runtime-supported held/rooted context. A named ABI trampoline recovers the registration; a captured Jac closure itself is not a C function pointer.
2. Have Rune's typed closure own a shared RAII registration token. Cloning a Rust closure shares the token; final drop schedules exactly one release on the owning UI thread while the Jac runtime is live.
3. Track states `active → retiring → released`. In-flight dispatch temporarily owns a valid registration. Replacement advances the generation; stale IDs/generations cannot reach a newer handler.
4. Copy event data into owned, explicitly sized payloads. Keep borrowed Rune context within the current UI turn. Do not retain raw event pointers.
5. Catch Jac exceptions inside the trampoline and convert to a typed status/error reported by the application root. Contain Rust panics before C ABI boundaries; document abort-profile limits.
6. Define shutdown order: stop accepting dispatch; invalidate generations; drain or reject queued work; wait for active UI dispatch to finish; drop retained Rune closures/tree; process token releases; release held Jac roots; retire the runtime entry context.
7. Avoid registry-to-Rune-to-registry strong cycles. Keep release infrastructure alive until final tokens are gone. For unexpected foreign-thread drops, enqueue release rather than entering Jac unsafely.
8. Expose test-only counters for registrations, token clones/final drops, active dispatches and held roots.

**Tests:** callback after registration returns; captured state mutation; closure clone/final drop; replacement and stale dispatch; repeated mount/drop cycles; close with queued work; exception; shutdown invoked twice; attempted callback after root invalidation. Retained context memory must remain valid until dispatch is rejected safely.

**Exit:** terminal counters balance to zero and deterministic expected callback traces match. Process exit is not cleanup evidence.

</details>

<details>
<summary>7. Work package F — release and reenter the Jac runtime safely</summary>

1. Inspect actual runtime locking/thread-state rules with the compiler owner. Implement a supported foreign-entry boundary that roots arguments before releasing the Jac execution lock around Rune's blocking loop and reacquires it on every return path.
2. Implement depth-aware enter/leave guards for callbacks and window turns. Rune's `App::turn_scope(enter, leave)` provides the proposed turn boundary; confirm exact semantics at the pinned revision. Apply the same protocol to headless frame calls.
3. An already acquired nested callback/turn must not acquire or release the runtime twice. No borrowed Jac pointers may cross an unlocked wait.
4. Confine Rune contexts and tree mutations to the UI thread. Worker threads may enqueue owned messages; foreign-thread callback entry either marshals to UI or fails explicitly under the documented contract.
5. Ensure errors, failed initialization and close restore lock/thread state. A panic crossing an ABI boundary is never an error transport.
6. Build a synchronized progress test: the Jac worker signals readiness, then the UI enters a controlled Rune wait; require a worker-owned counter/event to advance before that wait returns. Use barriers/events and a bounded timeout, not a sleep-only inference.
7. Exercise nested callback entry, repeated turns, headless entry, failure during dispatch, and shutdown. Instrument enter/leave depth and require a balanced terminal state.

**Exit:** workers progress during real Rune waits, callbacks retain valid runtime context, and nested/error/shutdown paths balance locks and roots. Full async service embedding remains Milestone B.

</details>

<details>
<summary>8. Acceptance matrix and evidence bundle</summary>

| Gate from #90 | Planned evidence |
|---|---|
| Clean single-executable build | Fresh target directory; frozen lockfiles; version manifest; build/link logs; no probe-library loading |
| Window and headless rendering | Window screenshot and actual input log; PNG/hash; platform/features/driver record |
| Jac/Rust equivalence | Canonical tree/layout comparison with declared tolerances and typed state assertions |
| Retained captured callback | Registration-return marker preceding dispatch; captured state before/after and observable rendered update |
| Worker progress | Barrier-driven worker trace showing progress before Rune wait returns |
| Balanced ownership | Replacement/clone/drop/error/shutdown tests; zero terminal registrations/held roots/in-flight dispatches |
| Safe late work | Stale-generation and post-close requests rejected without dereferencing released contexts |
| Reproduction and dependencies | Clean-build README; exact commands; paired revisions; owner/repository links; inventory and remaining gaps |

Create a small runner with proposed modes `--headless`, `--window`, `--ownership`, and `--worker-progress`; these flags are planned interfaces, not existing commands. Fail on missing dependencies and report window checks as skipped/blocked rather than passed when no desktop is available. Retain stdout/stderr and structured pass/fail/blocked results with artifact paths.

Run focused compiler tests for compiler changes. Run the repository's documented `neojac python -I scripts/check.py` when public packages/examples change, using the paired build as well as the released build where compatibility is claimed. An unreleased-compiler label documents coupling; it does not replace paired verification.

</details>

<details>
<summary>9. Reviewable changes, dependencies, and completion</summary>

| Change set | Depends on | Reviewable result |
|---|---|---|
| A. Pins, recovery, inventory and setup | VM access | Reproducible inputs and explicit compiler dependency ledger |
| B. Native Rust reference and Linux support | A | Real headless/window baseline and compatibility build |
| C. Compiler binding fixes | A, compiler source/build | Standalone regressions plus paired compiler artifact |
| D. Jac-linked executable | B, C | Typed tree parity and link evidence |
| E. Callback token/registry protocol | Compiler runtime contract from A | Ownership/error tests and deterministic traces |
| F. Runtime foreign-entry protocol | Compiler source, E | Worker and nested-entry tests |
| G. Integrated proof and documentation | D, E, F | Full #90 acceptance bundle |

B and independent compiler regressions can proceed while other compiler dependencies are resolved. E's protocol can be specified early, but runtime implementation must use verified primitives. Do not estimate dates until the compiler source/build path and baseline native build are established.

Proposed repository placement: `plans/rune-integration-proof.md` for this plan; restored `plans/rune-ui-engine-probe/` for historical evidence; a separate `examples/rune-native-proof/` for the executable and native crate; `scripts/` for repeatable verification; compiler tests in their owning repository. These are proposed paths. Inspect package conventions before implementation. Promote reusable typed adapter code into a library only when its boundary is established; keep future JSX/plugin work separate.

Record each external task's owner, repository, issue/PR, commit, build artifact and verification command. If compiler access remains unavailable, mark dependent gates blocked and deliver reference/setup evidence without claiming #90 complete.

Close #90 only when every acceptance gate has fresh evidence and paired revisions. Update #89 with the completed proof, remaining gaps and readiness for Milestone B. Keep #89 open: this milestone does not implement the native component runtime or complete the epic.

</details>
