---
description: Building a tool on neojac - the commands an editor, an agent or a viewer of your own is made on; and neojac turns, the JSON-RPC protocol of a session of work with a coding agent, with its methods, its events and its version.
keywords: turns, protocol, json-rpc, ide, extension, tooling, events
---
# turns: building a tool on neojac

`neojac arch` is one tool made on neojac, and everything it is made on is a command another tool
can use. An editor, a viewer of your own or an agent host starts the commands below and speaks a
protocol to each; none of them needs `neojac arch` running.

| To | Start | It speaks |
|---|---|---|
| Know what a name is, where it is used, what a file declares | [`neojac lsp`](lsp.md) | The Language Server Protocol |
| Give an agent the project's architecture, its check and the docs | [`neojac mcp`](arch.md#neojacs-tools-for-an-agent) | The Model Context Protocol |
| Run turns of a coding agent, with their checkpoints | `neojac turns` | The protocol on this page |
| Draw the architecture, or read it as data | [`neojac arch --json`](arch.md#what-it-takes), with `--diff`, `--base`, `--at` | JSON, once |
| List the steps of the project's history | `neojac arch --steps --json` | JSON, once |
| List the agents, or the registry | [`neojac agent --json`](arch.md#working-with-an-agent), `neojac agent registry --json` | JSON, once |
| Run an app while it is worked on | [`neojac dev <app>`](../apps/building.md) | The app's own address |

## The protocol

`neojac turns`, started in a project (or with `--project <directory>`), speaks JSON-RPC 2.0 on its
standard input and output: one message a line, as the Agent Client Protocol and the Model Context
Protocol do. The client sends requests; the server answers each, and sends a `session/event`
notification for each thing that happens.

```text
> {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":2}}
< {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":2,"server":{...},"project":{...},"state":{...}}}
> {"jsonrpc":"2.0","id":2,"method":"session/prompt","params":{"text":"Add a Clear done button"}}
< {"jsonrpc":"2.0","id":2,"result":{"turn":1}}
< {"jsonrpc":"2.0","method":"session/event","params":{"event":{"n":2,"kind":"turn","turn":1,...}}}
< {"jsonrpc":"2.0","method":"session/event","params":{"event":{"n":3,"kind":"message","turn":1,"id":"m1","text":"On it."}}}
< {"jsonrpc":"2.0","method":"session/event","params":{"event":{"n":5,"kind":"request","turn":1,"id":"ask5",...}}}
> {"jsonrpc":"2.0","id":3,"method":"session/answer","params":{"request":"ask5","option":"yes"}}
```

- **The protocol has a version,** now 2, which `initialize` answers with. `neojac turns --schema`
  prints the version, each method with its parameters and each event with its fields, as JSON; a
  name ending in `?` may be left out.
- **An error is JSON-RPC's:** `-32601` for a method there is none of, `-32602` for a parameter
  that is missing, and `-32000`, with the reason as its message, for what is refused (`a turn is
  running`, `no agent is added`).
- **`neojac arch`'s page speaks the same protocol** to its own server, posted to `/rpc`, and asks
  `session/events` for what it has not seen in place of being sent notifications. What the page
  can do, a client of `neojac turns` can.

### Methods

| Method | Parameters | Does |
|---|---|---|
| `initialize` | `protocolVersion`, `clientInfo?` | Answers with the server's version of the protocol, the project and the session's state |
| `session/state` | | The session's state: its `state` (`idle`, `starting`, `working`), its `turn`, the `agent`, the agent's `modes` and `options`, the revision the project `stands` at, the number of the `last` event, and the project's `stamp`, which moves when a file the picture reads has changed |
| `session/events` | `since?` | The events numbered after `since`, with the state: for a client that polls, and to replay a session |
| `session/prompt` | `text`, `scope?`, `plan?`, `agent?`, `images?` | Starts a turn. `scope` is ids of the picture's boxes (`layer:core`, `module:core.clock`) sent with what is asked; `plan` asks for the change as architecture first; `agent` names one in place of the one in use; `images` are sent with what is asked, each its `mime` (`image/png`, `image/jpeg`, `image/gif`, `image/webp`) and its `data` in base64, eight at most and 8 MB each, and are refused for an agent that takes none |
| `session/image` | `turn`, `index` | An image a turn was asked with, counted from 0: its `mime` and its `data` in base64 |
| `session/build` | `turn` | Starts the turn that builds what a plan turn proposed |
| `session/answer` | `request`, `option?` | Answers what the agent asked, with the id of one of the options it offered; with no option, refuses |
| `session/cancel` | | Stops the turn that is running |
| `session/undo` | `turn` | Puts the project's files back as they stood before that turn |
| `session/setMode` | `mode` | Sets the agent's own mode of asking, by its id |
| `session/setOption` | `id`, `value` | Sets one of the agent's own options |
| `session/clear` | | Ends the session and starts none: the next turn is the first of a new one |
| `project/picture` | `focus?`, `view?`, `profile?`, `diff?`, `base?`, `at?` | The architecture as [`--json`](arch.md#what-it-takes) prints it, as it stands or `at` a revision, marked with what changed since `base` when `diff` is true |
| `project/changes` | `base?`, `at?` | What changed from `base` to `at`, or to the project as it stands: the files, lines, modules and layers, and each file with its module |
| `project/steps` | | The steps of the project's history, as `neojac arch --steps --json` prints them |
| `agents/list` | | The agents added, and the one in use; a variable by its name, never its value |
| `agents/registry` | `word?` | What the ACP registry has, and how each is run on this machine |
| `agents/add` | `name`, `command?` | Adds an agent from the registry by its name, or a command of your own |
| `agents/use` | `name` | Makes it the one in use |
| `agents/remove` | `name` | Removes it |
| `agents/setVariable` | `name`, `key`, `value?` | Sets a variable of the agent's environment, or with no value forgets it |

### Events

Every event has its number `n`, counted from 1 in a session, its `kind`, the `turn` it belongs
to, and the time it was made `at`, in seconds since 1970. A session's log, `.jac/arch/<session>.jsonl` in the project, is its events as they
were sent, one a line, the first of them `opened`.

| Kind | Fields | Says |
|---|---|---|
| `opened` | `protocol`, `session` | A session began, under this version of the protocol |
| `turn` | `text`, `scope`, `before`, `agent`, `how`, `images` | A turn began: what was asked, the revision the project stood at, and `how` (`""`, `plan`, or `build:<turn>`). Each of its `images` is its `mime` and the `file` it is kept in, under `.jac/arch/<session>/`; [`session/image`](#methods) gives one back |
| `message` | `id`, `text` | A piece of what the agent says; pieces with one `id` are one message |
| `thought` | `id`, `text` | A piece of the agent's reasoning, where it shares it |
| `tool` | `id`, `title`, `tool`, `status`, `files`, `input`, `said`, `diffs` | A tool call as it now stands, sent again each time it changes: its kind (`read`, `edit`, `execute`, ...), its status (`pending`, `in_progress`, `completed`, `failed`, `cancelled`), and the files it names, each with its box in the picture. `input` is what the agent called the tool with, as the agent names it (a command is its `command`); `said` is what the tool gave back, as Markdown; each of `diffs` is a change to one `file`: whether the file is `made` by it, the lines `added` and `removed`, and its `lines` as a unified diff's, with the number `left` out of a long one. A long text is cut in its middle, and says so there |
| `plan` | `entries` | The agent's own list of steps, each with its status |
| `request` | `id`, `call`, `options` | The agent asks to do something, and waits: the tool call, and the answers it offers |
| `answer` | `id`, `option` | A request was answered, with that option or, where it is empty, refused |
| `changed` | `files` | Files of the project were seen to differ from where the turn began, whatever changed them; each with its box in the picture |
| `usage` | `used`, `size`, `cost`, `currency` | What the agent says of its context and its cost |
| `end` | `stop`, `before`, `rev`, `how`, `outside?`, `plan?`, `drift?` | A turn ended: why, and the revisions it began and ended at. A plan turn names the files it changed `outside` the plan; a build names the `plan` it built and, as `drift`, the wiring it changed after it |
| `error` | `text` | Something failed: the agent stopped, or refused |
| `restored` | `rev` | The project's files were put back as they stood before the turn |
| `configured` | | The agent's modes or options changed: ask `session/state` |
| `cleared` | | The session ended |

The revisions an event names are commits under `refs/neojac/turns/`, which any git command reads:
`git diff <before> <rev>` is what a turn changed.
