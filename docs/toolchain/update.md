---
description: How neojac replaces itself with a newer release - what neojac update fetches, checks and tries before it keeps a release, when a release takes over, which neojac follows the releases by itself and how often it asks, how to stay at a release or turn it off, and where it keeps what (neojac update, NEOJAC_UPDATE).
keywords: update, neojac update, upgrade, self-update, auto-update, newest release, follows the releases, update off, update on, downgrade, NEOJAC_UPDATE, neojac.next
---
# update

neojac is one file, and `neojac update` puts a newer release of that file in its place. A neojac
that the installer put in place as the latest release also does it by itself: it fetches a newer
release alongside a build, and that release takes over as a later command starts.

```sh
neojac update             # take the newest release, if it is newer than this one
neojac update 0.5.3       # take that release, older or newer, and stay at it
neojac update on          # this neojac follows the releases
neojac update off         # it stays as it is until `neojac update` is run
```

## What an update does

1. **It fetches the release**: the download for this machine's platform,
   `neojac-<version>-<platform>.gz`, from where this neojac's own release was published.
2. **It checks the download against its digest**, the `.sha256` published beside it. A download
   that does not match is not kept.
3. **It tries the release**: the fetched neojac builds a one-line program, and the program runs.
   A release that cannot do that on this machine is not kept.
4. **It keeps the release ready** beside neojac, as `.neojac.next` in the same directory.
5. **The release takes over**: one rename puts it in neojac's place, whole. There is no moment at
   which `neojac` is a file half written.

A step that fails ends the update and changes nothing: neojac is the file it was.

The digest is published with the release it describes. It tells a damaged or cut-off download from
a whole one. It does not tell a release from one that was altered where it is published.

## When a release takes over

A release takes over only when no other command of that neojac is running, so that a build, a test
run or `neojac dev` never finds itself a different neojac half way through.

- `neojac update` puts the release in place at once when it is the only command running, and says
  `neojac 0.6.0 took over from 0.5.3.`
- Otherwise it says the release is ready, and the release takes over when a command next starts
  with no other running. That command prints one line on standard error,
  `neojac 0.6.0 took over from 0.5.3`, and then runs as the new release, with the arguments it was
  given.

A command counts as running from its start to its end. A program that `neojac run` started is not
neojac, and does not count. A command that stays up does: `neojac dev`, a viewer that is serving,
and the language server an editor keeps running (`neojac lsp`). While one of them runs, a release
that is ready waits; it takes over at the first command started after they have ended.

## Following the releases

One neojac on a machine follows the releases: the one `install.sh` put in place as the latest
release, or the one `neojac update on` was last run with. A neojac installed with `--version`, and
a copy placed any other way (in a container image, by a build script that pins it), follows
nothing and is never replaced unless `neojac update` is run with it.

The neojac that follows asks which release is the newest when a build, a test run, an install or
`neojac dev` starts, at most once a day. It asks alongside the command, in a process of its own:
the command waits for nothing and is no slower when the network is. What it asks for is one small
file of the newest release, `neojac-version.txt`; nothing about the machine or its use is sent.

When the newest release is newer, that process goes on to fetch, check and try it, as `neojac
update` does, and leaves it ready. It takes over as described above, when a command starts with no
other running. What the process printed is in `~/.neojac/update/log`.

## Staying at a release

- `neojac update 0.5.3` takes that release, whether it is older or newer, and neojac stays at it:
  it stops following the releases, so that going back to a release is not undone the next day.
- `neojac update off` leaves neojac as it is, and discards a release that is ready and has not
  taken over.
- `neojac update` alone takes the newest release once, and changes nothing about whether neojac
  follows.
- `neojac update on` follows the releases again.

## Where nothing is replaced

| Where | What holds |
|---|---|
| `NEOJAC_UPDATE=off` (or `0`, `false`, `no`) | A run with it set asks for nothing, and a release that is ready does not take over as it starts. `neojac update` run by hand still fetches and takes over |
| CI (`CI`, `GITHUB_ACTIONS` and the others [telemetry](telemetry.md#turning-it-off) knows) | The same as `NEOJAC_UPDATE=off` |
| A neojac built from source | It has no release. `neojac update` says so, and it follows nothing |
| A directory that is not yours to write to | A neojac in one asks for nothing, and `neojac update` says who can replace it |
| Windows | `neojac update` says it does not replace neojac there yet |

## Where it is kept

Under `~/.neojac/update/`, apart from the build cache, so that clearing the cache changes nothing
about which neojac follows the releases:

| Path | What it is |
|---|---|
| `follows` | The path of the neojac that follows the releases. Absent when none does |
| `asked` | When the newest release was last asked for |
| `ready` | Which neojac a release is ready for, and its version, from when it is tried until it takes over |
| `log` | What the last update that ran alongside a command printed |
| `fetching` | Held by an update while it runs, so that two never fetch at once |

The release that is ready is `.neojac.next`, beside the neojac it is for. `install.sh --uninstall`
removes all of it.
