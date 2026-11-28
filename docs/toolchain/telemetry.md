---
description: neojac's anonymous usage statistics - the notice, every field of a week's report, what a report never holds, what counts as a run, where the records are kept, how a week's report is sent, and how to see them and turn them off (neojac telemetry, NEOJAC_TELEMETRY, NEOJAC_TELEMETRY_URL, DO_NOT_TRACK).
keywords: telemetry, usage statistics, neojac telemetry, telemetry off, telemetry on, privacy, anonymous, telemetry.neojac.dev
---
# telemetry

A release of neojac counts what it is used for: which commands run, how long they take and whether
they fail, which of their options are given, the codes of the diagnostics they report, what kinds of
program are built and for which platforms, and where in neojac an internal error was raised. A
week's counts are one anonymous report, and the totals of everyone's reports are public at
`telemetry.neojac.dev`.

The counts are what makes neojac better where it is used: a count of each diagnostic shows which
mistakes people actually make, which is what the error messages and these pages should answer
first, and an internal error counted by where it was raised is a defect found without anyone
filing it.

A week's report is sent as it stands, at most once a day, by a command that takes a while itself,
alongside its work and never making it wait; the collector keeps the latest. `neojac telemetry`
prints what is recorded, each week's report in the form it is sent.

```sh
neojac telemetry          # whether it is on, what decided that, and what is recorded
neojac telemetry off      # stop recording, and delete what is recorded
neojac telemetry on       # start again
```

## The notice

The first run of a release on a machine prints this on standard error, once:

```text
neojac collects anonymous usage statistics: which commands run, the codes of the
diagnostics they report, and neojac's version and platform. No file names, no
source, no arguments. The totals are public at telemetry.neojac.dev. Nothing has
been sent.
  neojac telemetry        show what is recorded on this machine
  neojac telemetry off    stop recording and delete what is recorded
  neojac docs telemetry   everything that is collected, and why
```

Nothing is recorded before it is printed. A run whose diagnostics are written as JSON
(`--diagnostics json`) neither prints it nor records anything, so the notice never lands among
records a program reads; the next run that writes for a person prints it. The installer
(`install.sh`) says the same in a line as it finishes, and its own test build records nothing.

## What a report holds

A report is one machine's counts for one calendar week, in UTC. Every value in it is a member of a
list neojac already has (its commands, their options, its diagnostic codes, its platforms) or a
count.

| Field | Values |
|---|---|
| Schema | `schema`: the report's version, 1. A change to the report's shape is a new number |
| Week and ID | `week`: the ISO week the counts are of (`2026-W48`). `id`: 32 hexadecimal digits, random, made on this machine for that week alone. It tells one machine's report from another's in the same week, and nothing ties one week's ID to the next |
| Release, OS, architecture, CI | Each of `groups` is the counts of one release, system and processor, run in CI or not: `release` (`0.4.1`), `os` (`linux`, `macos` or `windows`), `arch` (`x86_64` or `aarch64`), `ci` (`true` or `false`). A machine upgraded within a week has two |
| Commands | `commands`: for each command run, `runs`, how many of them exited with a status other than 0 (`failed`), and how many took under 1 second (`under_1s`), 1 to 10 seconds (`under_10s`), 10 to 60 seconds (`under_60s`) and longer (`over_60s`) |
| Options | Each of neojac's own commands' `flags`: for each option the command declares, how many runs gave it. The option's name only, never what was given with it |
| Diagnostics | `diagnostics`: for each of neojac's codes reported (`E1307`, `W3055`), how many times (`count`) and in how many runs (`runs`) |
| What was built | `built`: `kinds`, how many programs of each kind were built (`native`, a native program or library; `js`, a JavaScript space; `cpython`, a cpython space or a Python program; `app`, an app, whose spaces and program are counted under their own kinds too), and `targets`, how many native ones for each platform (`linux-x86_64`, `wasm32-wasi`, ...) |
| Internal errors | `internal_errors`: for each place in neojac an internal error was raised, how many. The place is the module and function of neojac's own source (`check.resolve_call`); for an internal error neojac reports itself, the function that reported it. Never the error's message, which can hold a path |

A report as `neojac telemetry` prints it:

```json
{
  "schema": 1,
  "week": "2026-W48",
  "id": "9f2c0a6e5b1d4c3a8e7f6a5b4c3d2e1f",
  "groups": [
    {
      "release": "0.4.1",
      "os": "linux",
      "arch": "x86_64",
      "ci": false,
      "commands": {
        "cc": {"runs": 40, "failed": 0, "under_1s": 40, "under_10s": 0, "under_60s": 0, "over_60s": 0},
        "check": {"runs": 12, "failed": 3, "under_1s": 9, "under_10s": 3, "under_60s": 0, "over_60s": 0,
                  "flags": {"--diagnostics": 2}}
      },
      "diagnostics": {"E1307": {"count": 5, "runs": 2}},
      "built": {"kinds": {"native": 3, "js": 1, "cpython": 0, "app": 1},
                "targets": {"linux-x86_64": 3}},
      "internal_errors": {"check.resolve_call": 2}
    }
  ]
}
```

How each count is taken:

- A command is counted under its first name, as `neojac help` lists it: `c++`, `clang` and the
  linkers under `cc`, `npx` under `npm`, `rustc` and `rustdoc` under `cargo`, `emit-py` under
  `emit-js`, `neojac --version` under `version`. `neojac <command> --help` is a run of `help`.
- An option is counted by its first spelling (`--verify` for `-v`), once a run however often it is
  given. One a command does not declare is not counted. `--` and what follows it are not options.
- A command that runs another program's command line (`cc`, `c++`, `clang`, `ar`, the linkers,
  `cargo`, `rustc`, `python`, `node`, `npm`, `npx`) has its runs counted and nothing else: no
  `flags`, since its arguments are that program's, and carry paths and definitions.
- The diagnostics are neojac's own, by code: what Clang, rustc or a test reports is not counted.
- A report holds at most 8 groups, those with the most runs, and at most 200 places of internal
  errors.

## What a report never holds

A path or a file's name, source, a name from a program, what a command or an option was given, an
environment variable, a host's or a user's name, a package's name, or the machine's address. The
statistics are of the `neojac` command alone: a program neojac builds records and sends nothing.

The country a report comes from is not worked out, and the collector keeps no address a report
came from.

## What a run is

A run is one `neojac <command>` that a person or a program of theirs started. Some runs of neojac's
executable are not:

- **A neojac that neojac started.** A build runs neojac again for its own steps (a space's
  compile, a C file's compile, a crate's rustc), and `neojac test` and `neojac npm` run programs
  that may run it. Each of those is part of the run that started it, and records nothing of its
  own: neojac sets `NEOJAC_TELEMETRY=off` for everything it runs.
- **neojac under another name.** The `python` of a project's `.jac/venv` and the links to neojac
  in its cache that build systems run as their compiler, linker or `rustc` are neojac's tools, not
  the `neojac` command, and record nothing.
- **`neojac telemetry` itself**, which shows and manages the records and adds none.

A run that ends by becoming another program (`neojac run`, which starts the program in its place)
is recorded as it hands over: its time is the build's, and its status 0. A run stopped by a signal
is not recorded.

## Where it is kept

Under `~/.neojac/telemetry/`, apart from the build cache, so that clearing the cache neither shows
the notice again nor forgets that recording was turned off:

| Path | What it is |
|---|---|
| `records/<week>.jsonl` | One line of JSON for each run that week, appended as the run ends; a line holding the week's ID; and a line for each time its report was tried, each time it was refused, and each time the collector took it, with how many runs it held. A report is made from these lines; nothing else reads them |
| `off` | There when `neojac telemetry off` turned recording off |
| `on` | There when `neojac telemetry on` turned it on |

Recording a run is one write of one line to the end of the week's file: no lock, and nothing read
of what was recorded before, so it costs a run nothing it would notice, and many runs ending at
once (`make -j` running `neojac cc`) each add their line. `install.sh --uninstall` removes
`~/.neojac`, and these with it.

## Turning it off

| | What it does |
|---|---|
| `neojac telemetry off` | Stops recording on this machine, for this user, and deletes what is recorded |
| `neojac telemetry on` | Starts it again |
| `NEOJAC_TELEMETRY=off` | Keeps it off for every run that has it in its environment, whatever was chosen with the command: nothing is recorded, no notice is printed and nothing is written. `0`, `false` and `no` say the same |
| `DO_NOT_TRACK=1` | The same, by the variable several tools share. Any value but empty, `0` or `false` |

A person uses the command; a fleet of machines or a CI configuration uses the variable.

A neojac built from source records nothing unless `neojac telemetry on` was run on the machine: a
report is grouped by release, and a build from source has none. What it records once it is turned on
is never sent: `neojac telemetry` counts those runs apart from the reports.

A run in CI is recorded with `ci` true when any of these is set to anything but empty, `0` or
`false`: `CI`, `GITHUB_ACTIONS`, `GITLAB_CI`, `BUILDKITE`, `CIRCLECI`, `JENKINS_URL`, `TF_BUILD`,
`TEAMCITY_VERSION`, `CODEBUILD_BUILD_ID`. The public totals can then be read with CI or without it.

## Sending

A week's report is always the whole week so far: every run recorded in it. It is sent by one of the
commands that take a while by what they are: `neojac build`, `neojac test`, `neojac install` and
`neojac dev`. A short command (`check`, `fmt`, `cc`, `run`, ...) never sends. Each week is one
request, a POST of `{"args": {"sent": <report>}}` to
`https://telemetry.neojac.dev/__jac/call/control/telemetry/take`, or to the address
`NEOJAC_TELEMETRY_URL` names. Such a command looks at each week it holds, the oldest first:

- **Something to send.** A week has something to send when it holds more runs than the last report
  the collector took of it, which `neojac telemetry` says. A week whose report was taken is sent
  again only once more is recorded in it.
- **At most once a day.** A week with something to send is sent when it was never tried, or was
  last tried a day ago or more, whatever came of that try. The week in progress is sent the same
  way as an ended one: on a machine used every day, its report reaches the collector each day as
  the week goes on.
- **Done when the collector has all of it.** A report the collector takes is noted in the week's
  file, with how many runs it held. An ended week the collector has all of is deleted; the week in
  progress is kept, and goes on being recorded into.
- **Refused, or no answer.** A refused report is tried again a day later; a week refused three
  times is not sent again, and is deleted once it has ended. A report that gets no answer (no
  connection, no answer within the limit, a status that says try later) is tried a day later.
- **Four weeks at most.** A week more than four weeks old is deleted, sent or not.
- **Alongside the command, never in its way.** The sending starts as the command starts, on a
  thread of its own in the same process, and has 5 seconds in all, for every week it sends. A
  command that ends first does not wait for it: the process ends, and what was not answered is
  tried a day later. A failure says nothing, and changes no exit status.
- **Nothing from what does not record.** `NEOJAC_TELEMETRY=off` and `DO_NOT_TRACK=1` send nothing, a
  neojac that neojac started sends nothing, a build from source sends nothing, even turned on, and
  the run that prints the notice sends nothing: on a machine's first run there is nothing yet to
  send.

So a machine in CI, which usually starts empty, sends its week so far with the first long command
after its first run, and nothing more that day: what it records after that is not sent unless the
machine is used again a day later. A CI machine is otherwise like any other.

`neojac telemetry` says of each week whether it is in progress or ended, when its report was last
sent and how many of its runs that held, when it was last tried, how often it was refused, and when
it is sent next.

The request is made as neojac's downloads are: the server's certificate is checked against the
certificates OpenSSL finds (`SSL_CERT_FILE`, `SSL_CERT_DIR`; Windows's own store on Windows), and a
proxy is taken from `https_proxy`, `http_proxy` and `no_proxy`.

The collector keeps one report for a week and an ID: a report sent again takes the place of the one
before, unless it holds fewer runs (two commands on one machine may send at once, the one that read
the records first arriving last). An install's week is one report however often it is sent. It keeps
reports for good: a report is counts and a week's random ID, and a trend is worth more the longer
it is. `NEOJAC_TELEMETRY_URL` sends the reports elsewhere instead, as an organization that wants
its machines' reports at a collector of its own does, or to watch them pass through a proxy.

## The public totals

`telemetry.neojac.dev`, in a browser, shows the totals of every report: active machines by week, by
release and by platform; commands by runs and by how often they fail; diagnostics by how many
machines met them; internal errors by release. The week in progress is shown as it goes, apart
from the totals of the weeks that have ended. No report, and no week's ID, is ever shown, and a
number is shown only where at least five machines are behind it. A container made fresh each time
(a dev container, a CI machine) is a new machine each time, which the counts of machines say.
