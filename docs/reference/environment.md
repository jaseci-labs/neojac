---
description: Every environment variable neojac reads, sets for the programs it runs, or that a program it built reads - NEOJAC_*, the names an app may not take, color and terminal variables, SDKROOT and the installer's - with what reads each and what it does.
keywords: environment variables, NEOJAC_STORE, NEOJAC_CACHE_DIR, NEOJAC_CACHE_SIZE, NEOJAC_CONFIG_DIR, XDG_CONFIG_HOME, APPDATA, NEOJAC_TELEMETRY, NEOJAC_TELEMETRY_URL, DO_NOT_TRACK, CI, HOME, NEOJAC_PROGRESS_TO, NEOJAC_RECORD_TO, NEOJAC, NEOJAC_TEST_DIR, NEOJAC_SLOTS, NEOJAC_DIAGNOSTICS_TO, NEOJAC_EXE, NEOJAC_RUST_SYSROOT, NEOJAC_PORT_TO, NEOJAC_DEPENDENCY_DIGEST, NEOJAC_BIN_DIR, NEOJAC_BROWSE_SESSION, GITHUB_TOKEN, GH_TOKEN, NO_COLOR, FORCE_COLOR, CLICOLOR_FORCE, TERM, XDG_CACHE_HOME, LOCALAPPDATA, SDKROOT, JAC_GC, JAC_THREADS, JAC_APP
---
# Environment variables

neojac needs no environment variable: a release carries its runtime, its toolchain and its documentation inside its one file. The variables below change what it does, are set by neojac for the programs it runs, or are read by the programs it builds.

## Read by neojac

| Variable | Read by | What it does |
|---|---|---|
| `NEOJAC_STORE` | Every command | A directory to read in place of what neojac carries: each of `lib/`, `rt/`, `rt/stdjac/`, `abstractions/`, `libraries/`, `docs/` and `VERSION` that the directory holds is read there, and each it does not is read from inside neojac. stdjac, `rt/stdjac/`, is a part of its own: an `rt/` that holds nothing but `stdjac/` gives stdjac and leaves the rest of the runtime to neojac, and an `rt/` with no `stdjac/` is read with neojac's stdjac. `abstractions/` and `libraries/` are one tree, as a plugin names the libraries it declares by their place beside it, so the directory holds both or neither. It is for building neojac itself: a neojac built from source carries nothing, runs with `NEOJAC_STORE=build/store`, and says so when it is run without ([build](../toolchain/build.md#how-the-runtime-is-found)); and for checking what neojac is released with against a release: a directory that holds a checkout's `abstractions/`, `libraries/`, `docs/` and, as `rt/stdjac/`, its `stdjac/`, makes the release read those and the rest from inside itself. A build made with it set is a build by another toolchain to the build cache |
| `NEOJAC_CACHE_DIR` | Every command | The build cache's directory, instead of the per-user cache directory. The cache is its `2/` ([The build cache](../toolchain/cache.md)); what neojac writes out of itself is its `store/`, `linked/` and `cross/` ([there](../toolchain/cache.md#what-neojac-writes-out-of-itself)), what it fetched is its `fetched/`, and a browser session's directory is under its `browse/` |
| `NEOJAC_CACHE_SIZE` | The same | The size the build cache is kept to: a number of bytes, or one followed by `K`, `M` or `G` (`20G`). Unset, 10G. Over it, a build that finishes alone deletes the entries used longest ago ([The build cache](../toolchain/cache.md#its-size-and-what-is-deleted)) |
| `XDG_CACHE_HOME` | The same, on Linux | Where the per-user cache directory is, when `NEOJAC_CACHE_DIR` is unset (else `~/.cache`) |
| `LOCALAPPDATA` | The same, on Windows | Where the per-user cache directory is, when `NEOJAC_CACHE_DIR` is unset |
| `NEOJAC_CONFIG_DIR` | `launch` | The directory the session `neojac launch login` keeps is in, instead of the per-user configuration directory ([launch](../toolchain/launch.md#signing-in)) |
| `XDG_CONFIG_HOME` | `launch`, on Linux | Where the per-user configuration directory is, when `NEOJAC_CONFIG_DIR` is unset (else `~/.config`) |
| `APPDATA` | `launch`, on Windows | Where it is there (else `~\AppData\Roaming`) |
| `NEOJAC_TELEMETRY` | Every command | `off` (or `0`, `false`, `no`): the run records nothing of its use, sends nothing, prints no notice about it and writes nothing, whatever `neojac telemetry on` chose ([telemetry](../toolchain/telemetry.md#turning-it-off)) |
| `NEOJAC_TELEMETRY_URL` | `build`, `test`, `install`, `dev` | The address a week's report of usage statistics is posted to, instead of the collector at `telemetry.neojac.dev` ([telemetry](../toolchain/telemetry.md#sending)) |
| `DO_NOT_TRACK` | Every command | Set to anything but empty, `0` or `false`: the same as `NEOJAC_TELEMETRY=off` |
| `NEOJAC_UPDATE` | Every command | `off` (or `0`, `false`, `no`): the run does not ask which release is the newest, and a release that is ready does not take neojac's place as the run starts. `neojac update` run by hand still does both ([update](../toolchain/update.md#where-nothing-is-replaced)) |
| `CI`, `GITHUB_ACTIONS`, `GITLAB_CI`, `BUILDKITE`, `CIRCLECI`, `JENKINS_URL`, `TF_BUILD`, `TEAMCITY_VERSION`, `CODEBUILD_BUILD_ID` | Every command | Any of them set to anything but empty, `0` or `false`: the run is counted as one in CI ([telemetry](../toolchain/telemetry.md#turning-it-off)), and it is held as `NEOJAC_UPDATE=off` holds it ([update](../toolchain/update.md#where-nothing-is-replaced)) |
| `HOME` | Every command that records its use, `telemetry`, and a release's commands and `update` | The home directory, whose `.neojac/telemetry/` holds what is recorded ([telemetry](../toolchain/telemetry.md#where-it-is-kept)) and whose `.neojac/update/` holds which neojac follows the releases ([update](../toolchain/update.md#where-it-is-kept)) |
| `NEOJAC_PROGRESS_TO` | Every command that shows a status line | A file to append each step to, one line each (`<step>` or `<step> · <detail>`), instead of drawing a status line ([Projects](../toolchain/projects.md#neojac_progress_to)) |
| `NEOJAC_RECORD_TO` | `cc`, `c++`, `clang`, `ar`, the linkers and `cargo` | A file to append one line to for each run, a JSON object: the tool, the directory it ran in, its arguments, and for `cc` and `c++` the inputs and the output ([C and C++](../interop/c-and-cpp.md#recording-what-a-build-ran)) |
| `NO_COLOR` | Every command | Set to anything but empty: no color, wherever the output goes. It wins over `FORCE_COLOR` |
| `FORCE_COLOR`, `CLICOLOR_FORCE` | Every command | Set to anything but empty or `0`: color even where the output is not a terminal |
| `TERM` | Every command | `dumb`: no status line, no outcome line, and no color unless forced |
| `LC_ALL`, `LC_CTYPE`, `LANG` | Every command that shows a status line | The first that is set decides whether the terminal takes UTF-8: without it, the status line is drawn in ASCII and the outcome has no `✓` |
| `NEOJAC_BROWSE_SESSION` | `browse` | The session a command is for, when it has no `--session` (else `default`) ([browse](../toolchain/browse.md#a-session)) |
| `SDKROOT` | `cc`, `c++` for a macOS target | A macOS SDK whose headers, frameworks and libraries a compile and link use, instead of the macOS stubs neojac carries. `-isysroot` on the command line does the same |
| `PATH` | The tools | `neojac node` and the Rust tools put their own directories first on it for the programs they start |

A build records the state of each variable it read. A change to one, or setting one that was unset (even to an empty value), makes the next build run instead of finding itself up to date ([The build cache](../toolchain/cache.md#when-a-build-has-nothing-to-do)).

The tools neojac carries read their own variables as they always do: `neojac python` reads CPython's (`PYTHONPATH`, `PYTHONMALLOC`, ...), `neojac install` passes pip's (`PIP_INDEX_URL`, `PIP_NO_INDEX`, ...) to pip, and `neojac node`, `npm` and `cargo` read theirs.

## Set by neojac for what it runs

| Variable | Set by | What it is |
|---|---|---|
| `NEOJAC` | `neojac test`, an app's build | The path of the neojac that is running, for a test or a build step that runs the compiler itself |
| `NEOJAC_TEST_DIR` | `neojac test`, for each test | The directory that is the test's own, where it writes its files: the same one each run, and no other test's ([test](../toolchain/test.md#a-tests-own-directory)) |
| `NEOJAC_SLOTS` | `neojac test`, for everything it runs | The named pipe that holds the run's free processors, a byte each: a neojac started under it takes one for each further thing it runs at once and gives it back, so the tests and the builds they start share the processors the run has ([test](../toolchain/test.md#the-processors-a-run-shares)) |
| `NEOJAC_TELEMETRY` | Every command, for everything it runs | `off`: a neojac that one runs (a build's own steps, what `neojac test` or `neojac npm` runs) is part of its run, and records nothing of its own ([telemetry](../toolchain/telemetry.md#what-a-run-is)) |
| `NEOJAC_UPDATE_ALONGSIDE` | A command of the neojac that follows the releases, for the `neojac update` it starts alongside itself | Set: that update leaves the release ready and does not put it in place, which the next command to start alone does ([update](../toolchain/update.md#following-the-releases)) |
| `NEOJAC_UPDATE` | `neojac update`, for the release it tries | `off`: the fetched neojac's trial build asks for nothing and replaces nothing |
| `PYTHON_CPU_COUNT` | `neojac test -j <jobs>` | `<jobs>`: the processors each build and runner is told it has (`os.cpu_count()` and `os.process_cpu_count()`), so a test that runs commands of its own runs as many at once as `-j` allows |
| `NEOJAC_PROGRESS_TO` | An app's build | The file the build steps of each program it runs are reported to, which the app's build shows as `<step> · <inner step>` |
| `NEOJAC_DIAGNOSTICS_TO` | A neojac running another | The file the inner one appends its diagnostics to, for the outer one to show. A program removes it from its environment as it starts, so programs it runs report for themselves |
| `NEOJAC_EXE` | Python's `sysconfig`, and on Windows the launchers that stand for neojac's tools | The neojac whose tools a build runs. A neojac that starts Python, Node, npm or cargo (`neojac python`, `node`, `npm`, `npx`, `install`, `remove`, `cargo`, `rustc`, `rustdoc`) sets it to itself, and `sysconfig`'s `CC`, `CXX`, `LDSHARED` and `AR` name it; with it unset they name `neojac`, as `PATH` finds it. The names a build's tools run neojac by (`rustc`, `cargo`, each target's `cc` and `ar`) are links to it in its cache ([The build cache](../toolchain/cache.md#what-neojac-writes-out-of-itself)). On Windows they are launchers, which run the neojac this names, and one started without it stops with `NEOJAC_EXE is unset: run it through neojac cargo or neojac rustc` |
| `CC`, `CXX`, `AR` | npm's scripts and Python build backends, under `neojac install`, `neojac npm` and `neojac npx` | `neojac cc`, `neojac c++` and `neojac ar`, of the neojac that is running: what a package compiles as it is installed, it compiles with them ([Packages](../toolchain/packages.md#what-a-packages-script-builds)). One the environment already names is left as it is |
| `NEOJAC_RUST_SYSROOT` | `rustc`, `rustdoc`, and a build of Rust crates | The sysroot a compile that names none is given, instead of this neojac's own: the standard library the crate is compiled against. What a build compiled against another sysroot it compiles again |
| `NEOJAC_PORT_TO` | rustc, under `neojac port` | The file rustc writes a crate's typed trees to, instead of compiling it: how `neojac port` reads Rust ([port](../toolchain/port.md)) |
| `NEOJAC_DEPENDENCY_DIGEST` | A build of Rust crates | A digest of a crate's dependencies, which the crate can read with `env!` |
| `JAC_APP` | An app's launcher, for a node space | The app's name, which picks its `JAC_<APP>_*` variables. Set it to run the launcher as another app's |
| `JAC_DEV_FRAMED`, `NEOJAC_DEV_TO` | A tool that runs `neojac dev` | A desktop app opens no window of its own, and the file `neojac dev` appends what it does to ([Building apps](../apps/building.md#working-on-an-app)) |
| `JAC_DEV_LISTEN`, `JAC_DEV_SERVED`, `JAC_DEV_PAGE` | `neojac dev` | Where the app's program listens, the page space a dev server serves in its place, and the page a window opens ([Building apps](../apps/building.md#a-page-from-its-bundlers-dev-server)) |

These are neojac's own plumbing: a program you run under neojac sees them, and you rarely set one yourself.

## Names an app may not take

`JAC_<NAME>` is how an app's own settings are given where it runs: `JAC_<APP>_LISTEN`, `JAC_<APP>_DATA` and `JAC_<APP>_ARRANGEMENT` for an app, `JAC_REMOTE_<SPACE>` and `JAC_<SPACE>_CODE` for a space, `JAC_<ABSTRACTION>` and `JAC_<SPACE>_<ABSTRACTION>` for the plugin picked, and `JAC_<ABSTRACTION>_<FIELD>` for a setting of the abstraction or of the plugin picked ([Plugins](../apps/plugins.md)). neojac's own variables are `NEOJAC_<NAME>` and can't be one of these, but a few variables with this prefix are read by neojac or by a program's runtime for themselves. They are reserved, and an app or a space whose name would form one of them is refused where it is declared (E2232):

`JAC_THREADS`, `JAC_GC`, `JAC_CUDA`, `JAC_FRESH`, `JAC_APP`, `JAC_DEV_PAGE`, `JAC_DEV_SERVED`, `JAC_DEV_LISTEN`, `JAC_DEV_FRAMED`, `JAC_DEPLOY_KEY`, `JAC_TICKS_OFF` and `JAC_REMOTE_TOKEN` (each is in the tables on this page).

An app named `dev` would be given its address by `JAC_DEV_LISTEN`, which `neojac dev` sets for itself, and a space named `token` its remote by `JAC_REMOTE_TOKEN`: each is E2232. No abstraction has a name that one of these starts with, so no plugin's setting can form one.

## Read by a program neojac built

| Variable | What it does |
|---|---|
| `JAC_GC` | `JAC_GC=off`: under the `managed` memory profile, the cycle collector never runs on its own (an explicit `__rc_collect_cycles()` still does). For finding leaks. See [Memory](../language/memory.md) |
| `JAC_THREADS` | How many threads a `flow for` loop runs on, 4 when it is unset. The program reads the digits the value starts with (`8x` is 8); a value that starts with none, or `0`, is 1. `JAC_THREADS=1` runs every loop in order, with a sequential run's results |

A program reads `JAC_GC` and `JAC_THREADS` from the environment it was started with. Other pages own the rest:

| Variables | Page |
|---|---|
| `JAC_CUDA` | [Devices](../accel/devices.md) |
| `JAC_LLM_MODEL` (the model `by llm(...)` asks), `ANTHROPIC_API_KEY` (the key the `anthropic` plugin sends), `OPENAI_API_KEY` (the key the `openai` plugin sends), `JAC_LLM_ADDRESS` (a gateway to the API, in place of `https://api.anthropic.com`, or the `openai` plugin's provider) | [by and sem](../language/by-and-sem.md) |
| `JAC_<ABSTRACTION>` (which of the plugins it was built with a program runs with: `JAC_STORE`), `JAC_<ABSTRACTION>_<FIELD>` (a setting of that plugin, `JAC_STORE_PATH`, or of the abstraction, `JAC_AUTH_REGISTRATION`), and `JAC_<SPACE>_<ABSTRACTION>` with `JAC_<SPACE>_<ABSTRACTION>_<FIELD>` for a space bound on its own. `ui` and `bundler` have none: they are picked as a space is built | [Plugins](../apps/plugins.md#picking-a-plugin-where-the-program-runs) |
| `SSO_GITHUB_CLIENT_ID`, `SSO_GITHUB_CLIENT_SECRET` (a GitHub OAuth app's, with which the `accounts` plugin offers signing in through GitHub) | [Servers](../apps/server.md#signing-in-through-github) |
| `SSO_GOOGLE_CLIENT_ID`, `SSO_GOOGLE_CLIENT_SECRET` (a Google OAuth client's, with which the `accounts` plugin offers signing in through Google) | [Servers](../apps/server.md#signing-in-through-google) |
| `SMTP_PASSWORD` (the password the `smtp` plugin gives the server it hands mail to) | [Servers](../apps/server.md#the-mail-an-app-sends) |
| `JAC_<APP>_LISTEN`, `JAC_TICKS_OFF` | [Servers](../apps/server.md) |
| `JAC_<APP>_DATA`, `JAC_FRESH` | [An app's data](../apps/data.md) |
| `JAC_<APP>_ARRANGEMENT` (which arrangement an app is, of those its artifact holds) | [Building apps](../apps/building.md#several-arrangements-in-one-artifact) |
| `JAC_REMOTE_<SPACE>`, `JAC_REMOTE_TOKEN`, `JAC_DEPLOY_KEY` | [Crossings](../apps/crossings.md) |

The standard library reads the variables Python's does, with Python's meaning: `HOME`, `TMPDIR` (for `tempfile`), `PYTHONTZPATH` (for `zoneinfo`), `PYTHON_CPU_COUNT` (for `os.cpu_count`), `COMSPEC` (for `subprocess` on Windows), and the rest, through `os.environ`.

## Read by the installer

`install.sh` reads these; neojac itself does not ([Install](../start/install.md)):

| Variable | What it changes | Default |
|---|---|---|
| `NEOJAC_BIN_DIR` | Where `neojac` goes | `~/.local/bin` |
| `NEOJAC_CACHE_DIR`, `XDG_CACHE_HOME` | Read by `--uninstall` alone, as neojac reads them: where the cache it removes is | the per-user cache directory |
| `GITHUB_TOKEN`, `GH_TOKEN` | Sent with the request for the latest release, so it is not held to GitHub's rate limit for unauthenticated requests | none |
