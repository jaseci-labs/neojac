---
description: Building a tool on neojac - the commands an editor, an agent or a viewer of your own is made on; and neojac turns, the JSON-RPC protocol of sessions of work with coding agents, several at a time, with its methods, its events and its version.
keywords: turns, protocol, json-rpc, ide, extension, tooling, events, sessions, parallel
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
notification for each thing that happens, with the session it happened in.

```text
> {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":4}}
< {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":4,"server":{...},"project":{...},"sessions":[],...}}
> {"jsonrpc":"2.0","id":2,"method":"session/prompt","params":{"text":"Add a Clear done button"}}
< {"jsonrpc":"2.0","id":2,"result":{"session":"20260301-101500","turn":1}}
< {"jsonrpc":"2.0","method":"session/event","params":{"session":"20260301-101500","event":{"n":2,"kind":"turn","turn":1,...}}}
< {"jsonrpc":"2.0","method":"session/event","params":{"session":"20260301-101500","event":{"n":3,"kind":"message","turn":1,"id":"m1","text":"On it."}}}
< {"jsonrpc":"2.0","method":"session/event","params":{"session":"20260301-101500","event":{"n":5,"kind":"request","turn":1,"id":"ask5",...}}}
> {"jsonrpc":"2.0","id":3,"method":"session/answer","params":{"session":"20260301-101500","request":"ask5","option":"yes"}}
```

- **The protocol has a version,** now 4, which `initialize` answers with. `neojac turns --schema`
  prints the version, each method with its parameters and each event with its fields, as JSON; a
  name ending in `?` may be left out. Its `eventsSince` is the oldest version whose events are the
  ones this version declares ([below](#sessions)).
- **An error is JSON-RPC's:** `-32601` for a method there is none of, `-32602` for a parameter
  that is missing, and `-32000`, with the reason as its message, for what is refused (`a turn is
  running`, `no agent is added`, `there is no session 'x'`).
- **`neojac arch`'s page speaks the same protocol** to its own server, posted to `/rpc`, and asks
  `session/events` for what it has not seen in place of being sent notifications. What the page
  can do, a client of `neojac turns` can.

### Sessions

A session is one conversation with an agent: its turns, the agent's own process and context, and
its log. A project has as many as are begun, and any number of them work at the same time.

- **A `session/prompt` that names no session begins one,** and answers with its id. Every other
  `session/` method names the session it is for, and a `session/event` says which it is from. Each
  session counts its own turns and its own events from 1.
- **`sessions/list` says what each is doing:** its `session` id, its `title` (the first line of
  what it was first asked), whether it is `open`, its `state` (`idle`, `starting`, `working`), the
  `agent` of its last turn, its `turn`, when it last did something (`at`), the numbers of its
  `last` event and of the one that `ended` its last turn, how many requests wait for an answer
  (`asks`) and how many prompts wait for a turn (`waiting`), and under `doing` the tool calls it
  is in now, each with the `path` of its box in the picture, its `tool` kind and its `title`.
- **A session is kept in the project,** as its log, `.jac/arch/<session>.jsonl`. A server started
  again lists every one, and holds open the one worked in last. Another is opened by the first
  call that names it: its log is read, and an agent is started for it at its next turn and told
  what was said. `session/close` puts an idle one away again, and `session/remove` deletes its
  log and the images kept with it.
- **A log outlives the version that wrote it while its events are the same.** A session's first
  event says the version it was kept under, and a server reads one from `eventsSince` up to its
  own. Any other is listed with `reads` false, is refused by every method but `session/remove`,
  and is left as it is.
- **Sessions share the project's files.** There is one working tree, and each agent is told when
  another is at work in it. So a turn's checkpoints, its `changed` events and what
  `project/changes` counts between them are what changed in the project in that time, whoever
  changed it. A turn that begins while another session's runs says so in its checkpoint, which
  `project/steps` gives as a step of the kind `beside`.
- **`session/undo` puts the whole project back,** as it stood before that turn, so what any
  session changed since then is put back with it. It is refused while a turn runs in any session.
  Every open session that worked after that time is sent a `restored` event that names the session
  the undo was asked in (`by`) and the turn (`of`), and its agent is told at its next turn.

### Methods

| Method | Parameters | Does |
|---|---|---|
| `initialize` | `protocolVersion`, `clientInfo?` | Answers with the server's version of the protocol, the project, and what `sessions/list` answers |
| `sessions/list` | | Every session the project has kept, as [above](#sessions), with the agent `chosen` for a new turn and the project's `stamp`, which moves when a file the picture reads has changed |
| `session/state` | `session` | The session's state: its `title`, its `state` (`idle`, `starting`, `working`), its `turn`, the `agent`, the agent's `modes` and `options`, the revision the project `stands` at, the number of the `last` event, and the project's `stamp` |
| `session/events` | `session`, `since?` | The session's events numbered after `since`, with its state and what `sessions/list` answers: for a client that polls, and to replay a session |
| `session/prompt` | `text`, `session?`, `scope?`, `plan?`, `agent?`, `images?` | Starts a turn in the session, or with no `session` in a new one, and answers with the `session` and its `turn`. While a turn runs in that session, what is asked waits instead and the answer is its `queued` id. An agent that takes a prompt while a turn runs is handed it at once ([below](#what-is-asked-while-a-turn-runs)); otherwise what waits is asked as the next turn when this one ends, several plain messages of one agent as one. `scope` is ids of the picture's boxes (`layer:core`, `module:core.clock`) sent with what is asked; `plan` asks for the change as architecture first; `agent` names one in place of the one in use; `images` are sent with what is asked, each its `mime` (`image/png`, `image/jpeg`, `image/gif`, `image/webp`) and its `data` in base64, eight at most and 8 MB each, and are refused for an agent that takes none |
| `session/image` | `session`, `turn`, `index`, `tool?` | An image a turn was asked with, counted from 0: its `mime` and its `data` in base64. With `tool`, the id of a tool call of that turn, an image that call's result holds |
| `session/build` | `session`, `turn` | Starts the turn that builds what a plan turn proposed |
| `session/answer` | `session`, `request`, `option?` | Answers what the agent asked, with the id of one of the options it offered; with no option, refuses |
| `session/withdraw` | `session`, `id` | Takes back what waits by that id, so that it is not asked. What an agent has been handed is not taken back |
| `session/cancel` | `session` | Stops the turn that is running in it; what waits there is then the next turn |
| `session/undo` | `session`, `turn` | Puts the project's files back as they stood before that turn of the session, whatever changed them since |
| `session/setMode` | `session`, `mode` | Sets the agent's own mode of asking, by its id |
| `session/setOption` | `session`, `id`, `value` | Sets one of the agent's own options |
| `session/close` | `session` | Puts an idle session away: its agent is stopped, and its log is kept and listed |
| `session/remove` | `session` | Deletes an idle session's log and the images kept with it. Its checkpoints stay in git |
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
| `opened` | `protocol`, `session` | A session began, by this id, its events those of this version of the protocol |
| `turn` | `text`, `scope`, `before`, `agent`, `how`, `images`, `queued?` | A turn began: what was asked, the revision the project stood at, and `how` (`""`, `plan`, or `build:<turn>`). Each of its `images` is its `mime` and the `file` it is kept in, under `.jac/arch/<session>/`; [`session/image`](#methods) gives one back. `queued` is the ids of what had waited and is asked with it |
| `queued` | `id`, `text`, `scope`, `how`, `images` | What was asked while a turn ran, waiting by its `id`; its `images` are their `mime`s |
| `handed` | `id` | What waited by that id was given to the agent, which takes it up when it can; it can no longer be taken back |
| `withdrawn` | `id` | What waited by that id was taken back, or was left waiting when its server stopped |
| `message` | `id`, `text` | A piece of what the agent says; pieces with one `id` are one message |
| `thought` | `id`, `text` | A piece of the agent's reasoning, where it shares it |
| `tool` | `id`, `title`, `tool`, `status`, `files`, `input`, `said`, `diffs`, `images` | A tool call as it now stands, sent again each time it changes: its kind (`read`, `edit`, `execute`, ...), its status (`pending`, `in_progress`, `completed`, `failed`, `cancelled`), and the files it names, each with its box in the picture. `input` is what the agent called the tool with, as the agent names it (a command is its `command`); `said` is what the tool gave back, as Markdown; each of `diffs` is a change to one `file`: whether the file is `made` by it, the lines `added` and `removed`, and its `lines` as a unified diff's, with the number `left` out of a long one. A long text is cut in its middle, and says so there. Each of `images` is an image the tool's result holds (a picture the agent read), its `mime` and the `file` it is kept in beside the turn's; [`session/image`](#methods) gives one back by the call's id. One that is no PNG, JPEG, GIF or WebP, or is larger than 8 MB, is not kept, and `said` says so |
| `plan` | `entries` | The agent's own list of steps, each with its status |
| `request` | `id`, `call`, `options` | The agent asks to do something, and waits: the tool call, and the answers it offers |
| `answer` | `id`, `option` | A request was answered, with that option or, where it is empty, refused |
| `changed` | `files` | Files of the project were seen to differ from where the turn began, whatever changed them; each with its box in the picture |
| `usage` | `used`, `size`, `cost`, `currency` | What the agent says of its context and its cost |
| `end` | `stop`, `before`, `rev`, `how`, `outside?`, `plan?`, `drift?` | A turn ended: why, and the revisions it began and ended at. A plan turn names the files it changed `outside` the plan; a build names the `plan` it built and, as `drift`, the wiring it changed after it |
| `error` | `text` | Something failed: the agent stopped, or refused |
| `restored` | `rev`, `by?`, `of?` | The project's files were put back as they stood before the turn. In another session that worked since, `by` is the session the undo was asked in and `of` its turn |
| `configured` | | The agent's modes or options changed: ask `session/state` |

The revisions an event names are commits under `refs/neojac/turns/<session>/`, which any git
command reads: `git diff <before> <rev>` is what changed in the project while a turn ran. Each
says when it was made, to the millisecond, in a `Neojac-At` trailer, which is what orders the
steps of sessions that worked at the same time.

### What is asked while a turn runs

What is asked while a turn runs waits, by an id (`queued`). What happens to it next is the
agent's to say:

- **An agent that takes a prompt while a turn runs is handed it at once** (`handed`). It says so
  when it starts, as `agentCapabilities._meta.claudeCode.promptQueueing`, which the Claude
  adapter does. The agent takes the message up when it can, between two steps of its work. Where
  it does, the turn that was running ends, and what was handed begins the next turn (`turn`, with
  the id in its `queued`): so the events after it are that turn's, and a client shows the message
  where the agent took it up.
- **What has been handed cannot be taken back.** `session/withdraw` refuses it.
- **Any other agent is asked when the turn ends:** what waits is the next turn, several plain
  messages of one agent as one. A plan, a build and a message for another agent wait so with
  every agent.
- **`session/cancel` stops the running turn, and what waits is then asked.** An agent drops what
  it was handed and had not taken up, and it is asked again as the next turn.
