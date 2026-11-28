# neojac

**The one tool an AI agent needs to build almost anything.**

neojac is a compiler for the [Jac](docs/start/index.md) programming language, with everything
a project around a program needs, in one download. Give it to a coding agent and the agent has a
language, every toolchain, every package ecosystem, the documentation and a way to check its own
work, with nothing else to install.

| In the one binary | What it is for |
|---|---|
| The compiler | One Jac project becomes a native server, a web page, a desktop app, a phone app and a command-line program: `neojac build` |
| CPython, Node, Clang and Rust | Python, JavaScript, C, C++ and Rust code, compiled and run as their own tools do: `neojac python`, `neojac node`, `neojac cc`, `neojac cargo` |
| Every ecosystem's packages | PyPI, npm, crates and C libraries in one manifest and one lock: `neojac install` |
| The documentation, offline | A page, what a word means, an error by its code, a search: `neojac docs` |
| Playbooks written for agents | When to use each, the steps, the commands, what a correct result looks like: `neojac skills` |
| What an editor asks | Definitions, references, types and diagnostics, from a language server or the command line: `neojac lsp`, `neojac query` |
| A browser it drives | Open the page it just built, read it, click through it: `neojac browse` |
| The architecture, drawn and enforced | A project's layers and what each may import, as a picture and as a check: `neojac arch` |
| Checks | Types, lint rules, tests and one layout for source: `neojac check`, `neojac test`, `neojac fmt` |
| Hosting | An app sent to the hosting platform, built there from its source, and looked after: `neojac launch` |

## Get the binary

On Linux (x86_64 or arm64) and macOS (Apple Silicon):

```sh
curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash
neojac version
```

On Windows, download `neojac-<version>-windows-x86_64.zip` from a
[release](https://github.com/jaseci-labs/neojac/releases) and unpack it: `bin\neojac.exe` finds
its runtime beside it. [Install](docs/start/install.md) has the options, and how to uninstall.

### Give it to your agent

In the directory your agent works in:

```sh
neojac skills install
```

That writes neojac's playbooks to `.agents/skills`, where a coding agent loads them from
(`--to <dir>` for another place). Then tell the agent that neojac is there, in the file it reads
its instructions from (`AGENTS.md`, `CLAUDE.md`, a rules file):

```markdown
This project is built with neojac, which is installed. Before writing Jac, run `neojac skills`
and read the skill for the task at hand. Look things up with `neojac docs <word>` and
`neojac docs search <text>`, and read what an error means with `neojac docs <code>`. Check
your work with `neojac check` and `neojac test`, and lay source out with `neojac fmt`.
```

## Prompts to try

Paste one into your coding agent (Claude Code, Cursor, Codex, or any other) in an empty directory.

**One project, four apps**

> Using neojac, build a to-do app as one project: a backend that keeps each signed-in user's
> to-dos, a web page for it, the same page as a desktop app and as a phone app, and a
> command-line client. Start with `neojac skills` and read `starting-a-project` and
> `building-an-app`. Build everything with `neojac build`, start the web app with
> `neojac dev`, and tell me where each artifact is.

You get one project whose `dist/` holds a web server with its page, a desktop app, a phone
app's bundles (and an `.apk` where the Android SDK is at hand) and a command-line program, all
calling the same backend functions.

**Data that stays, with no database to set up**

> Using neojac, write a program that keeps a reading list as a graph under `root`: books,
> authors, and which book led me to which. Add a command to add a book and one to print the
> trail from any book. Read the `modelling-with-graphs` skill first. Run it twice and show
> that the second run still has what the first added.

**A function a language model answers**

> Using neojac, write a function that takes a sentence like "lunch with Sam, $42 on Tuesday"
> and gives back a typed `Expense`, answered `by llm()`. Read the
> `language-models-and-agents` skill first. Then give the model a tool that looks up a
> currency rate, and show me both working. `ANTHROPIC_API_KEY` is set.

**Every ecosystem in one program**

> Using neojac, build a command-line tool that reads a CSV with a Python package, renders a
> chart with an npm package, and hashes the result with a Rust crate. Read
> `using-python-packages`, `using-npm-packages` and `using-c-and-rust`. Install everything
> with `neojac install` and show me `jac.toml` and the output.

**Check its own work in a browser**

> Using neojac, build a small sign-up page with a backend that keeps who signed up. Then open
> it with `neojac browse`, sign up through the page as a new user, and tell me what the page
> shows and what the backend kept.

## Use it on the code you have

neojac is useful to a codebase with no Jac in it. From least commitment to most:

- **Run what you have through its toolchains.** `neojac python script.py`, `neojac node
  server.mjs`, `neojac npm test`, `neojac cargo build`, `neojac cc main.c`. One install gives
  an agent every toolchain, at versions the release fixes, on any machine.
- **Bring your manifests into one.** `neojac absorb` takes a `package.json`, a `Cargo.toml`
  or a C module's manifest into `jac.toml`, with what its lock pins into `jac.lock`. From then
  on `neojac install` installs every ecosystem's packages, and one lock says exactly what a
  build was made with. [Packages](docs/toolchain/packages.md).
- **See your architecture, and hold the code to it.** Name your layers in an `archwire.jac`
  and say which may import which. `neojac arch` draws it, in the terminal, as an SVG, as
  Mermaid, or as a page that follows the project while it is edited. `neojac check` refuses
  an import the picture does not allow, in Jac, Python, JavaScript and TypeScript files
  alike. [Architecture](docs/toolchain/arch.md).
- **Port a file into Jac.** `neojac port` translates C, C++, Rust, Python and JavaScript
  source into a Jac module that behaves as the file does, or refuses it and says why.
  `neojac port --check` reports what would port before anything is written.

A prompt for a repository you already have:

> neojac is installed. Absorb this repository's package manifests with `neojac absorb`, write
> an `archwire.jac` that puts the directories under `src/` in layers as they depend on each
> other today, and show me `neojac arch --text`. Then list the imports that cross a layer
> the wrong way.

## Plugins: use anything with neojac

Jac has words for what every app needs: data that stays, who is calling, a model that
answers, work that runs later. Each word is an **abstraction**, and what carries it out is a
**plugin** your project chooses. neojac ships one for each, and any of them can be replaced
with your own, with no change to the app's source and no rebuild of neojac.

| What you write | The abstraction | The standard plugin |
|---|---|---|
| `root`, `root.shared`, `++>` | `store`: where the graph is kept | `sqlite` |
| `:prot`, the caller's `root` | `auth`: who is calling | `accounts` |
| A call from outside, a call to another app | `transport`: how calls travel | `http` |
| `by llm()` | `llm`: the model that answers | `anthropic` |
| `@job`, `flow`, `wait` | `jobs`: work run apart | `process_jobs` |
| `@schedule` | `schedule`: work run on a clock | `loop_schedule` |
| `@limit` | `limits`: how often a caller may ask | `memory_limits` |
| `File`, `@accepts` | `files`: where a file's bytes are kept | `local_files` |
| A component and its JSX | `ui`: what a page is rendered with | `react`, `react_native` |
| Nothing: a page is bundled as it is built | `bundler`: what bundles a page | `vite`, `expo` |

So the graph can live in Postgres or MongoDB, sign-in can be your company's, the model can be
any provider's, and jobs can go to the queue you already run.

**A plugin is a small package written against one contract.** The contract is the interface
the abstraction asks for, and it is in this repository:
[`abstractions/store/contract.jac`](abstractions/store/contract.jac) for `store`, and so on
for each.

```toml
# mongostore/jac.toml
[project]
name = "mongostore"
kind = "plugin"

[plugin]
fills = "store"
interface_ver = 1
class = "mongostore.store.MongoStore"
```

**A project uses it by naming it.** In the app's `jac.toml`:

```toml
[packages]
mongostore = { git = "https://github.com/you/mongostore", rev = "a1b2c3d" }

[store]
plugin = "mongostore"

[store.mongostore]
database = "notes"
```

`neojac install` fetches it and pins it, and `neojac build` compiles it into the program.
`neojac check` of the plugin's module, in its own directory (`neojac check store.jac`), holds it to
its contract while you write it.
[Plugins](docs/apps/plugins.md) is the whole of it, and the standard plugins in
[`abstractions/`](abstractions/) are working examples of each.

A prompt:

> Using neojac, write a `store` plugin that keeps a space's graph in Postgres. Read the
> `writing-a-plugin` skill and `neojac docs store.contract` first. Check it with
> `neojac check` of its module in its own directory, then bind it in a small app and show the
> app's data surviving a restart.

## Learn more

- **`neojac docs`** prints the documentation's map, for the version installed. The same pages
  are in [`docs/`](docs/), starting at [docs/start](docs/start/index.md).
- **[`examples/jaclang_org`](examples/jaclang_org/)** is a whole project: a website with its
  server, a desktop app, a phone app and a command-line program, built from one source tree.
- **[`examples/raylib_shooter`](examples/raylib_shooter/)** is one small 3D game written four
  times, in Jac, C, Rust and Python, each built and run by neojac and timed against the others.
- **[Coming from Python](docs/start/coming-from-python.md)** is the short way in for someone
  who reads Python.

## About this repository

| | |
|---|---|
| [`abstractions/`](abstractions/) | The language's abstractions, a directory each: its manifest, the contract a plugin of it implements, and its standard plugins |
| [`stdjac/`](stdjac/) | What a program says of the abstractions, and what connects it to their plugins: stdjac, which a release ships as the runtime's `rt/stdjac/` |
| [`libraries/`](libraries/) | Libraries the standard plugins use |
| [`docs/`](docs/) | The documentation `neojac docs` prints, and the skills `neojac skills` installs |
| [`examples/`](examples/) | Programs written in Jac |
| [Releases](https://github.com/jaseci-labs/neojac/releases) | Every release of neojac. Each is tagged on the commit of this repository it ships |

- **The compiler's own source is not in this repository.** What a program meets of neojac is:
  stdjac, the contracts, the plugins and the libraries here are compiled into the programs it
  builds, and a release ships them, and `docs/`, as they are here.
- **Everything here is under the [MIT license](LICENSE),** and so are the released binaries.
- **neojac is not the open-source `jac`** of [jaseci-labs/jac](https://github.com/jaseci-labs/jac),
  the language's reference design. They are separate compilers with separate releases, both can
  be installed on one machine, and a program written for one is not taken unchanged by the
  other. [Coming from the reference design](docs/start/coming-from-the-reference-design.md)
  says where they differ.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** says how a change is made here.
