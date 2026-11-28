---
description: neojac arch, a project's architecture drawn from its archwire.jac - the layers, one layer or module opened, the spaces under each profile; a page that follows the project as it is edited, and the picture as text, SVG, PNG, Mermaid and JSON.
keywords: arch, architecture, diagram, picture, viewer, mermaid, svg, png, architecture diagram
---
# arch

`neojac arch` draws a project's architecture, and draws it from `archwire.jac` and nothing else.
Its [layers](../language/modules-layers.md) are the boxes. Its [wires](../language/modules-wiring.md)
are the arrows, each with the edge rule that admits it at that level of the layers beside it. Nothing in the picture is written
down a second time anywhere, so the picture cannot say something the code does not.

```sh
neojac arch                  # serve the picture as a page
neojac arch --text           # print it on the terminal
neojac arch platform --text  # one layer, opened
```

Run it from anywhere inside a project. For the project of [Layers](../language/modules-layers.md),
`neojac arch platform --text` prints:

```text
platform

               ┌─ time ──────────┐
               │ core.clock      │
               └─┬──────┬────────┘
                 │ Time │ Clock
                 │      └────────┐
                 ▼               │
┌─ machine ───────────────────┐  │
│ host · posix · shared · win │  │
└─────────┬───────────────────┘  │
          │ Machine              │
          └───────────────┐    ┌─┘
                          ▼    ▼
               ┌╌ screen ╌╌╌╌╌╌╌╌┐
               ╎ app.view · main ╎
               └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

## What is drawn

| In the picture | Where it comes from |
|---|---|
| A box | A layer, with what it holds. Opened, a layer's boxes are the layers it holds, or its modules |
| The bar at a box's left edge and the color of its frame, in `--svg`, `--png` and the viewer | What the box is: a layer in indigo, a module in grey, a space in orange, an app in pink |
| A chevron at a box's right edge, in the same three | The box opens: a click in the viewer shows what it holds |
| A module's words | The first sentence of the module's own docstring |
| An arrow | The wires between the two boxes' modules, from the provider to the consumer |
| A dotted arrow, its head hollow in `--text` (`▽`) | An arrow whose every wire is [declared](../language/modules-wiring.md#declared-wires---) (`-->`): the consumer is a file in another language, whose own source writes the import. A solid arrow has a wire that is the import (`++>`). In `--json` the arrow's `declared` says which, and each wire's `how` |
| `a JavaScript module`, `a Python module`, `a Rust module`, `a C file`, `a C++ file`, `a C module`, `a Rust crate` in a module's box | The module is a file of the project in that language, a C module, or a crate |
| The words beside an arrow | The edge rule that admits those wires between those two boxes: a wire has [a rule at every level](../language/modules-layers.md#a-rule-at-every-level), and each picture shows its own level's |
| A dashed box | Something outside what is opened: another layer, or what the project imports from outside itself |
| A purple box, in `--svg`, `--png` and the viewer | A library the project imports from outside itself: the runtime and standard library, npm, Python, C libraries, another project |
| A teal box, in the same three | One package of such a library, in the picture of a module that imports it |
| Lines that join into one | A box that takes from more than eight others, or provides to more than eight: their arrows share one line into it, or out of it, with a branch at each of the others |
| A box across the picture's width | A layer that provides to nearly every other, or takes from nearly every other. It names them in place of an arrow to each |

- **What a project imports from outside itself** is drawn too, by where it comes from: the runtime
  and standard library, npm, Python, C libraries. These imports are written in the modules; the
  picture is read from them.
- **`--view spaces`** draws an app project's [spaces](../apps/archwire.md): each space with its
  host, its entry and how many modules run in it, each app with what it runs and serves, and an
  arrow between two spaces for the wires that cross between them. `--profile <name>` draws them as
  that profile arranges them.

## What it takes

```text
neojac arch [<layer> | <module>] [--mermaid | --json | --text]
neojac arch [<layer> | <module>] --svg <file> | --png <file>
neojac arch --view spaces [--profile <profile>] [<output>]
neojac arch [<layer> | <module>] --diff [--base <revision>] [<output>]
```

| Argument | The picture |
|---|---|
| none | The project's layers |
| a layer's name | That layer, opened |
| a module's name, as wires write it (`core.clock`) | That module, with everything it takes from and gives to |
| `--view spaces` | The spaces, as the unnamed `graph spaces` block arranges them |
| `--profile <name>` | The spaces, as that profile does |

| Output | What is written |
|---|---|
| none | The picture is served as a page: see [The viewer](#the-viewer) |
| `--text` | The picture, on the terminal |
| `--svg <file>` | The same picture as an SVG. It is the same bytes each time for the same project |
| `--png <file>` | The SVG as the browser [`neojac browse`](browse.md) drives draws it. The first use fetches that browser |
| `--mermaid` | A Mermaid flowchart, for a README, an issue or a pull request, where GitHub draws it |
| `--steps` | The steps of the project's history, one a line, or with `--json` as data: where the branch left its upstream, each commit since, each turn of an agent, and the project as it stands when that is different |
| `--json` | What the picture is drawn from: each box and what it holds, each arrow with its wires, the names each carries, the rule that admits it at each level of the layers (`levels`), and its file and line |

The layout of `--text`, `--svg` and `--png` is neojac's own, and all three are one layout. Mermaid
lays its flowchart out itself, so it looks different and says the same.

`--at <revision>` draws the project as it stood at a git revision, in place of as it stands; with
`--diff`, the marks are what changed from the base up to that revision.

A tool of your own is made on these outputs and on the protocols beside them:
[building a tool on neojac](turns.md).

## What has changed: --diff

`--diff` draws the same picture with what has changed marked on it, so a change is read where it
lands. It compares the project as it stands, uncommitted work included, with a git revision: the
commit this branch left its upstream at, or `origin`'s main branch when the branch follows none.
`--base <revision>` names another.

| In the picture | What it says |
|---|---|
| `~ +120 −30` in a module's box, drawn in amber | A file of that module changed, by that many lines |
| `~ 3 of 12 modules, +400 −90` in a layer's box | That many of its modules changed |
| `+ new` in a box, drawn in green | A module or a layer the revision does not have |
| `− removed` in a dashed red box | One the revision has and the project no longer does |
| `+ new` beside a green arrow | An arrow the revision does not have |
| `+3 −1` beside an amber arrow | An arrow that carries three names more and one fewer |
| `− removed` beside a dashed red arrow | An arrow the revision has and the project no longer does |
| A box or an arrow left at full strength | A box that takes from a module that changed, and the arrow out of one |
| Everything else, faded | What the change does not reach |

The last line of the picture counts it: `changes since origin/main: 14 modules in 12 layers,
+1385 −983 lines in 110 files`. Every output takes `--diff`: `--text` writes the words, `--svg`
and `--png` the colours too, `--mermaid` colours the boxes, and `--json` gives each box and arrow
its `change` and the words drawn for it (`mark`), and each arrow the names it gained and lost
(`added`, `removed`).

- A file of the project that is no module's (a test's fixture, a page of documentation) is counted
  in the last line and marks no box.
- A repository held inside the project as a git submodule is compared with the commit the revision
  pins it at.
- `--diff` is refused outside a git repository, and for a `--base` git does not know.

## The whole project is checked

`neojac arch` reads **every** file under `archwire.jac`, whether or not any program loads it,
and every target's files, as [every command does](../language/modules-wiring.md#what-a-command-judges).
So before it draws, it has held the whole project to the wiring's rules:

- a wired name its module never spells, on any target (E1146);
- an import of a project module written where a wire belongs (E1144);
- a module in no layer (E2201);
- an import from outside the project with no rule, where `jac.toml` asks one for each (E2211);
- an edge rule, or a part of one, that nothing uses (E2205, E2206, E2207), an import in a module's
  text included.

**An output option refuses a project whose wiring has errors.** It prints them, writes nothing and
exits with 1: a picture that leaves the terminal is of a project that checks. `--diagnostics json`
prints them as records.

## The viewer

With no output option, `neojac arch` serves the picture and prints where:

```text
The architecture of shop is at http://127.0.0.1:8090/?key=5f0c2a9e41b7d3c86a1e0f9b2d4c7a35
```

The address carries the viewer's key, made anew each time it starts. The page keeps it as a
cookie, and the server answers nothing without it: a viewer can start an agent and run an app, so
only the browser that was given its address may ask it to.

- **A click on a layer or a module opens it.** The line at the top left of the picture says where
  it is, and each part of that line goes back.
- **The picture is a canvas.** A drag moves it, and so do the wheel and two fingers on a trackpad;
  a pinch, or the wheel with Ctrl or Cmd held, zooms where the pointer is. At the lower right,
  `−` and `+` zoom, the percentage fits the picture so that it reads (a tall one to its width),
  and the frame beside it shows the whole picture however small. A double click on the background
  fits it again. Until it is moved by hand, the picture stays fitted as the window, the panels
  around it and the cards on it change.
- **One picture becomes the next.** A box that is in both moves to its new place and takes its
  new size and colors, a line that still joins the same two boxes is routed anew as they move,
  what is gone fades and what is new comes in last. A layer opened grows out of its box, and
  going back folds it into that box again. A browser that asks for reduced motion is shown each
  picture at once.
- **A legend at the lower left says what the picture's marks mean:** the bar at a box's edge
  that tells a layer from a module, a space or an app, a dashed box, a box across the width, the
  chevron of a box that opens, a solid arrow and a dotted one, lines that join, the words beside
  an arrow, the colors of what has changed and what a change does not reach, and the outlines of
  the box whose code is shown and of where an agent is. It lists only the marks the picture shown
  has, each drawn as the picture draws it, so it changes with the picture. A click on **Legend**
  puts the list away or shows it again, and the page keeps that choice.
- **Resting on an arrow says what it carries:** which box takes how many names from which, and
  the edge rules that admit them. **A click lists the names**, in a card beside the line that
  Escape or a click elsewhere puts away. Where lines join into one, a branch answers for its own
  arrow and the shared line for all of them.
- **Find** looks up a layer, a module or a wired name as it is typed (`/` goes to it). A layer or
  a module is opened; a name opens the module that provides it, with its code at the name's
  declaration.
- **Layers and Spaces** switch the view, in a project of more than one space, and a project
  with profiles has a list of them.
- **Changes** always carries the lines added and removed since the revision it compares with,
  whatever is shown. Pressed, it marks [what has changed](#what-has-changed---diff) on the
  picture, and says at its top right how many modules and layers that is. The code then follows the picture: it
  shows the changes of whatever is open, a layer's or the whole project's as much as a module's.
  - **The code is a diff:** the lines added in green, the lines removed in red where they stood,
    and the unchanged code between changes folded to a line that a click opens (**Whole file**
    shows it all).
  - **The arrows above the code** (`p` and `n`) step through every change of what is open, on from one
    file to the next; `[` and `]` step by file, and a list names the files by module. A module's
    files come before those of the modules that take from it, so a change is read before what
    depends on it. The count says where that is: `37 of 102 · file 3 of 9`.
  - **The picture says what is being read:** the box that holds the file shown is outlined, and
    opening a layer or a module in the picture narrows the code to its changes.
  - The card of an arrow lists the names it gained and lost, and a click on an arrow that is new
    or changed shows its wire in `archwire.jac`.

  `neojac arch --diff` opens the viewer with it on.
- **A module opened shows its code on the picture.** The module's file is a card over the
  picture's lower right, half the picture's height, and the picture is fitted again in the room
  beside it; the card's left edge drags to make it wider or narrower. A layer and the spaces show none. The `×` at its right
  puts the code away; while it is away, **Code** at the lower right of the picture brings it
  back. In a narrow window the card lies across the foot of the picture. The browser's Back
  returns to what was shown before.
- **A name in the code is what the language server says of it.** Resting on a name shows what it
  is. A click marks its other uses in the file; a click with Ctrl or Cmd held, or a double click, goes to its
  definition, and from there to its declaration: on a function whose body is in an impl annex, it
  goes back and forth between the declaration and the impl. The list at the right of the file's
  name is its outline: what the file declares. Names are colored by what they are, and a diagnostic is underlined where it is. When the code is of another module than the picture's,
  **Show ... in the picture** opens that module.
- **The page follows the project.** It asks the server each second whether a file it read has
  changed, and the server reads the project again when one has.
- **A wiring error is drawn where it is.** The viewer does not refuse a project with errors: it
  draws the wire or the box in red. `neojac check` prints each error with its code and its place.
- **The page loads nothing from anywhere else.** Its code is a Jac program, compiled for the
  browser when neojac is built, and it is served from the same address as the picture.

The code view is a client of [the language server](lsp.md): the viewer starts a `neojac lsp` of
its own the first time code is shown, and relays between it and the page. So what a name is said
to be is what an editor is told, and the first answer about a file waits for its program to be
checked, which the code view says while it lasts (`checking main.jac...`). The server also indexes
the project's other programs in the background, as it does for an editor. A file that is not Jac
is shown as it is, with no answers. Only files of the project and of neojac's runtime are shown.

## Working with an agent

The viewer is also where a coding agent is put to work on the project. An agent is a program that
speaks the [Agent Client Protocol](https://agentclientprotocol.com): Claude Code, Gemini CLI,
Codex and the others its registry lists, or one of your own.

```sh
neojac agent registry claude                           # what the registry has by that word
neojac agent add claude-acp --env ANTHROPIC_API_KEY    # add one, with the key this shell has
neojac agent add mine -- ./my-agent --acp              # or a command of your own
neojac agent                                           # the ones added, the one in use marked
```

- **`neojac agent add <name>`** takes the agent the registry lists by that name: it fetches the
  build the registry pins for this machine and checks it against the registry's digest. After
  `--`, the agent is the command given, started as written, with no shell.
- **An agent keeps its own sign-in.** One that is signed in by its own command needs nothing more.
  `--env <NAME>=<value>` gives an agent a variable of its environment, such as an API key, and
  `--env <NAME>` takes the value this environment has. The agents and their variables are kept in
  `agents.json` in neojac's configuration directory, which only you can read, never in the
  project. **Agents** in the viewer does the same: it lists the registry, adds from it, and sets
  or forgets a variable, whose value the page is never sent.

The panel beside the picture is the agent's, under **Agent**. The line between it and the
picture drags to size it, and the button at the far left of the top bar puts it away and brings
it back:

- **What is typed at its foot is asked of the agent**, with what the picture is opened on: a layer with
  its modules, a module with its file. A click on a box with Alt or Cmd held adds it too. Each
  is a chip above the text, and its `×` leaves it out. Enter sends; Shift and Enter is a new line.
- **An image goes with what is asked:** a screen capture or a picture, pasted into the text,
  dropped on the panel, or chosen with the button beside Send. Each is shown small above the
  text until it is sent, and its `×` leaves it out; a click shows it whole. A turn takes eight, a
  PNG, a JPEG, a GIF or a WebP of 8 MB at most, and an agent that takes no images is not sent
  the turn: the panel says so.
- **Its first line says what the agent is doing**, and under it is the conversation:
  each turn with what was asked and when, what the agent answered, and its plan when it keeps
  one.
- **Each thing the agent does is one line:** what it is, the command beside it where it ran one,
  the lines an edit added and removed, how long it took when that was a second or more, and
  whether it failed. A click opens it to the whole of it: the command, the files (a click shows
  one in the code), what it was called with, an edit as a diff, and what it gave back, each
  with a button that copies it. A run of more than three is folded to one line that counts
  them by kind once the agent goes on to say something, and opens again at a click. The agent's
  reasoning, where it shares it, is one line that opens the same way.
- **An image the agent looks at is shown in the conversation,** under the step that read it: a
  screen capture it took, a picture it opened. A click shows it whole.
- **The conversation stays where you are reading it.** While its end is in view it follows what
  arrives; scrolled back, it stays, and **Latest** returns to the end.
- **The picture shows where the agent is.** The box of a file it says it is reading is outlined,
  and a box it has been in stays marked for the turn. **What it changes is seen, not taken on its
  word:** while a turn runs, the viewer watches which of the project's files differ from where
  the turn began, and the box of a file that has just changed is outlined strongly, whether the
  agent edited it with its own tools, a shell command or a script. With **Follow** on, the
  picture opens the layer the agent is working in when that is not in view, and from the first
  change of a turn it marks [what has changed](#what-has-changed---diff) since the turn began, as
  it happens, with the code at the change.
- **What the agent asks to do waits for an answer.** A request is a card with the command or the
  file, and the answers the agent offers, which are sent back as they are; the panel comes
  forward when one arrives. The list beside Follow holds the agent's own modes of asking; neojac adds none and answers nothing by itself.
  **Stop** ends a turn, and answers what is open with a refusal.
- **What is asked while a turn runs waits.** Send is then **Queue**, and the message is shown
  above the form. An agent that takes a message while it works (the Claude adapter does) is given
  it at once: the message then says **Sent**, and it enters the conversation where the agent
  takes it up, between two steps of its work. For any other agent the message says **Queued**,
  with a `×` that takes it back, and is asked as the next turn when this one ends, several of
  them as one. After **Stop**, what was waiting is asked next, sent or not.
- **Plan first asks for the change as architecture before any of it is built.** With it on, the
  agent is asked to change only `archwire.jac` and the declarations in the modules' files, with
  no bodies, and to stop. What it proposes is then on the picture as any change is: a new layer
  or module, a new arrow, the names a wire gained or lost. **Build it** starts the turn that
  writes the bodies; **Discard** puts the files back; another message with Plan first on changes
  the plan. Nothing holds an agent to a plan but what is checked afterwards, and the viewer says
  what it finds: a plan turn that changed other files names them, and a build says whether it
  kept to the wiring the plan proposed or changed it.
- **Every turn is two checkpoints.** As a turn begins and as it ends, the project as it stands is
  kept as a commit under `refs/neojac/turns/`, which no branch holds and which changes neither
  the index nor a branch. The turn's line says what it changed; **Review** marks that on the picture and steps
  through it in the code, and **Undo** puts the files back as they stood before the turn. What is
  put back is kept too, under `refs/neojac/undone/`. An agent cannot be made to forget a turn, so
  after an undo the next turn starts the agent again and tells it what was said and what was
  undone.
- **The conversation is the project's.** It is kept in `.jac/arch/`, which git is told to ignore,
  and a viewer started again shows it and goes on from it.

An agent is given the project's directory, what was asked, one paragraph that says the
project is Jac, that `archwire.jac` is its wiring, and how neojac is run here, and neojac's own
tools ([below](#neojacs-tools-for-an-agent)). What it may do is
what it asks and is allowed, by its own rules: neojac starts it and relays, and runs none of its
tools.

## neojac's tools for an agent

`neojac mcp` serves an agent the project over the
[Model Context Protocol](https://modelcontextprotocol.io), on its standard input and output.
`neojac arch` hands it to the agent it works with; any other agent or editor that takes an MCP
server is given the command `neojac mcp`, started in the project (or with `--project <directory>`).

| Tool | Answers |
|---|---|
| `architecture` | The picture as `--json` prints it: the layers, or with `focus` a layer opened or a module with everything it takes and gives; with `view` `spaces`, the spaces and the apps |
| `find` | Where a layer, a module or a wired name is: what it is, the module that provides it, its file |
| `changes` | What has changed since a revision (`base`, or where the branch left its upstream): the modules and layers, and each file with its module and its lines |
| `check` | What `neojac check` prints for the project, and the status it ended with |
| `symbols` | What a Jac file declares, with each name's line and column |
| `docs` | A page of this documentation, what defines a word, or the list of pages |

Each call reads the project as it stands, so an answer is never of a file as it was.

## The project over time

A project in a git repository has a history: where the branch left its upstream (or the first
commit, with no upstream), each commit since, each turn of an agent after the commit it was made
on, what was changed by hand between two turns, and the project as it stands when that is not
committed. Once there is more than one step it is a slider along the foot of the picture and,
when asked for, a list on the picture.

- **The button at the left of the slider shows the history as a list,** a card over the
  picture's lower left, and puts it away again, as the `×` at the list's head does. The list is
  the history from its newest step down: what is not yet committed first, then each commit with
  the start of its hash and how long ago it was made, an agent's turns in the accent color, and
  where the branch began. A click on a step goes to it, and its changes are the code in the card
  at the right; a click on the step that is shown leaves the history. The list and the code are
  shown and put away each by itself.

- **The slider, and the arrows beside it, go to a step.** Each step is a dot on the slider, an
  agent's turns in the accent color. The picture is then the project's architecture as it stood
  there, marked with what that step changed from the one before, and the code is that step's,
  with its changes. The picture moves from one step to the next as it does between any two
  pictures, so sliding shows the project take shape.
- **Play** goes through the steps from where the slider is, one every two seconds or so.
- **Back to now** leaves the history.

## Running an app

A project whose archwire declares [apps](../apps/building.md) has **App** beside **Agent** in
the panel, with a button for each. Pressing one runs `neojac dev <app>` at a free port and shows
the app's page there, beside the picture; what the build says is shown until the page is up, and again when a build fails. The
page is loaded again each time the app starts again, so what an agent changes is seen running.
**Stop** ends it.

`--listen <address>` says where it serves (`127.0.0.1:8090` when not given; port 0 is any free
port). It serves until it is interrupted. It opens no browser: open the address in one, or have
[`neojac browse`](browse.md) do it.

## For editors

- **`neojac query arch <file>[:<line>]`** prints the JSON of the picture a document is in: a
  module's file gives its module, the line of a `layer` in `archwire.jac` that layer, and anywhere
  else in `archwire.jac` the project.
- **The language server** answers the request `neojac/architecture` the same way, with the text
  the editor holds, saved or not. See [The language server](lsp.md#architecture).

## What the picture does not show

- **The order things run in.** A module that reads what another recorded depends on it, and
  imports nothing from it. Wires are who may name whom, and that is all the picture says.
- **Plans.** A box for something not built has no source to be drawn from.
- **Imports that files in another language write**: a space's `.py`, `.js` and `.ts` files. A
  wire's consumer is a Jac or C module.
