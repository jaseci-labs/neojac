---
description: Functions and methods a language model (an LLM) or another value answers (def f(...) -> T by llm();), the tools that make one an agent (ByTool values, and @reads for the ones a round runs at once), a by function that streams its answer, the By, ByStreams and ByChooser interfaces such a value conforms to, llm() and the plugin that speaks to a model, its conversations and usage, and sem strings that describe declarations to them.
keywords: by, sem, semantic string, llm, language model, LLM, AI, agent, tool use, tools, By, ByCall, ByTool, ByError, ByStreams, ByEvent, ByEventKind, ByEnd, ByUsage, cost, rates, ByChooser, ByChoice, on_usage, latest_turns, IterationContext, ANTHROPIC_API_KEY, OPENAI_API_KEY, JAC_LLM_KEY, JAC_LLM_ADDRESS, Effort, Model, ModelRequest, ModelReply, anthropic, openai, Gemini, JAC_LLM_MODEL, media, image, PDF, pdf_part
grammar: sem_def, by_expr
---
# By and sem

A function declared with `by` in place of a body has its result computed by
the value it names, its **answerer**: `def triage(message: str) -> Ticket by llm();` asks a language
model for a `Ticket`. The compiler gives the answerer what it knows of the
function: its name, its arguments, the JSON schema of its result type and
the descriptions `sem` declarations attach to the function, its parameters
and the result's fields. The answerer's answer is decoded as the declared type
and checked, so the caller gets a `Ticket` or an exception, never text.

Two more forms hand work to an answerer. A `by` function declared to give
`Iterator[ByEvent]` is answered as the answerer goes, an event at a time
([below](#a-by-function-that-streams)). `visit <nodes> by <chooser>;` has a
answerer choose which of the nodes a walker goes to ([visit](visit.md#visit--by)).

## Syntax

```ebnf
sem_def ::= "sem" impl_target_name ("." impl_target_name)* "=" STRING+ ";"

by_expr ::= pipe ("by" by_expr)?
```

A `by` function is the `ability` production with `"by" expression` in place
of a block (see [Methods](methods.md)): `def name(params) -> T by e;`. A
method of an archetype may be one ([below](#a-method-answered-by)).

The `by` operator of an expression (`by_expr`) has its meaning in one
statement: `visit <nodes> by <chooser>;` ([visit](visit.md#visit--by)). In
any other expression it is E5090.

A `sem` names its target by a dotted path, as an [`impl`](impl.md) does,
and gives it a string; several adjacent strings are joined (`sem f = "One "
"sentence.";`). The statement ends with `;` (E0002) and the string follows
`=` (`sem x is "..."` is E0156).

| Target | Example |
|---|---|
| A function | `sem triage = "Turn a message into a ticket.";` |
| A function's parameter | `sem triage.message = "The message as written.";` |
| A class: an `obj`, `node`, `edge`, `walker` or `enum` | `sem Reviewer = "A reviewer of one repository.";` |
| An archetype's field | `sem Ticket.title = "A short title.";` |
| An enum's member | `sem Severity.CRITICAL = "Breaks production, loses data or leaks a secret.";` |
| A method | `sem Reviewer.read_file = "Read the start of a file.";` |
| A method's parameter | `sem Reviewer.read_file.path = "The file, from the repository's root.";` |

## What a `by` function does

`def f(a: A, b: B = d) -> R by e;` is a function whose body

1. evaluates `e`, which must give a value of a class conforming to the
   interface `By` (below), once per call. `e` is an expression of the
   module like any other: `llm` is built in, any other answerer is a
   name the module has, and a name it does not have is W2001;
2. encodes the arguments by their types, as `encode` (from `stdjac`) does,
   into a dict from parameter name to JSON value (an enum member by its name,
   an object as a dict of its fields). A parameter `e` hands the answerer whole
   is not among them ([below](#a-parameter-the-answerer-takes-whole));
3. calls that value's `invoke` with a `ByCall` holding the call's name, the
   function's `sem`, the arguments, the parameters' `sem`s, the JSON schema
   of `R` with each field's `sem` as its description, and a decoder for `R`;
4. returns what `invoke` returns, as an `R`.

### A method answered `by`

A method declared with `by` is answered the same way. Its object is among
the arguments, as `self`, encoded as any object is, and `e` is evaluated
inside the method, so it may name `self`: an object's own methods are its
tools.

```jac
obj Reviewer {
    has repo: str;

    def read_file(path: str) -> str {
        return f"{self.repo}/{path}";
    }

    def review(path: str) -> str by llm(tools=[self.read_file]);
}

sem Reviewer.review = "Review one file of the repository.";
```

An ability (`can ... with entry`) is not answered `by` (E5090).

## Tools

A tool is a `ByTool`: something an answerer may call while it answers, with
a name, a description, the JSON schema of its arguments, and a function
that calls it with arguments given as JSON and gives its result as JSON.
An answerer keeps the tools it is given (`llm(tools=[lookup])`).

**A function, or a method of an object, given where a `ByTool` is taken is
its tool.** The compiler makes the `ByTool` there: its `name` is the
function's, its `doc` the function's `sem`, and its schema the parameters'
types, each described by its `sem`.

| Tool | Written | Called as |
|---|---|---|
| A function | `lookup` | `lookup(...)` |
| A method of an object | `r.read_file`, `self.read_file` | `r.read_file(...)`, on the object it was taken from |

A method tool is described by the method's `sem` and its parameters'
(`sem Reviewer.read_file`, `sem Reviewer.read_file.path`), and is named for
the method (`read_file`). Its object is one that is there: a method of an
object that may be `None` (`r: Reviewer | None`, not narrowed) is E5090.

A `ByTool` is a value like any other. A module keeps a list of them, a
function takes one, and lists of them are joined:

```jac
import from stdjac { ByTool }

def lookup(word: str) -> str {
    return word.upper();
}

sem lookup = "Look a word up.";

obj Shelf {
    has books: list[str] = [];

    def find(title: str) -> bool {
        return title in self.books;
    }
}

sem Shelf.find = "Whether the shelf holds a book.";

glob READING: list[ByTool] = [lookup];

def describe(tools: list[ByTool]) -> list[str] {
    return [f"{t.name}: {t.doc}" for t in tools];
}

with entry {
    shelf = Shelf(books=["Dune"]);
    tools = READING + [shelf.find];
    print(describe(tools));
    print(tools[0].call({"word": "day"}), tools[1].call({"title": "Dune"}));
    print(tools[1].schema);
}
```

```output
['lookup: Look a word up.', 'find: Whether the shelf holds a book.']
DAY True
{'type': 'object', 'properties': {'title': {'type': 'string'}}, 'required': ['title']}
```

What is a tool is a function with a body or a method called on its object,
whose parameters and result have a JSON schema. A generic function, an
`async` one, a generator, a static method or a C function is not (E1229,
where it is given).

### Tools that only read: `@reads`

A model may ask for several tool calls in one reply, a **round**. An
answerer runs a round's calls one at a time, in the order the model asked,
unless it is told that running them at the same time changes nothing:
`@reads` (from `jaclang.comptime`, a [decorator](decorators.md#the-facts))
declares that of a function, and its `ByTool` says so (`alone` is `False`).
`llm` runs consecutive `@reads` calls of a round at once
([below](#rounds-of-tool-calls)).

```jac
import subprocess;
import from jaclang.comptime { reads }
import from stdjac { ByTool }

glob posted: list[str] = [];

@reads
def read_file(path: str) -> str {
    shown = subprocess.run(["git", "show", "HEAD:" + path], capture_output=True, text=True);
    return shown.stdout;
}

def post_comment(body: str) -> str {
    posted.append(body);
    return "posted";
}

with entry {
    tools: list[ByTool] = [read_file, post_comment];
    print([(t.name, t.alone) for t in tools]);
}
```

```output
[('read_file', False), ('post_comment', True)]
```

The compiler holds the declaration to what it can see. A `@reads` function
is E1643, reported at the statement, when in the program's own code it or
what it calls

- assigns a name outside the call: a module's global, a captured name;
- changes an object the call did not make: an argument, a global's value,
  its own object (`self.n += 1`), a cache it fills;
- changes or walks a graph: `++>`, `del`, `spawn`, `visit`;
- reads stdin, or prints to a file it is given.

An object is the call's own when every value bound to its local is made
there: a display (`[]`, `{}`), a comprehension, a constructor call,
`list()`, `set()`, `sorted()`, or a list joined, repeated or sliced. What a
function returned and an item read back out of a container are not, even a
container the call made.

A destructor (`__del__`) is the call's where the call makes an object of
its class: that object ends with the call, so what its `__del__` changes,
the call changes. The destructor of an object the call is given is not the
call's.

What it reaches in the runtime's modules and in C (a file read, a
subprocess, a request) the compiler does not follow: that it changes
nothing is the declaration's word. So is what a value whose class the
compiler does not know (an `any`, what the runtime returned) does when it
is called, compared, printed or iterated. A function that is not declared
is never run alongside another, so leaving `@reads` off is always safe.

### A parameter the answerer takes whole

A parameter that `e` passes whole as a keyword argument
(`by llm(conversation=history)`, `history` a parameter) is the answerer's. It
is not among the call's arguments (`ByCall.args`), and its `sem` is not among
`arg_docs`: the answerer is given the value itself, the same object the caller
passed. A parameter used inside a larger expression (`tools=[r.read_file]`)
is still an argument.

Here `r` is an argument and the owner of a tool, and `notes` is the
answerer's, which adds to the caller's list:

```jac
import from stdjac { By, ByCall, ByTool }

"""An answerer without a model: it calls its tool, and notes what
the tool gave."""
obj Canned(By) {
    has tools: list[ByTool] = [],
        notes: list[str] = [];

    def invoke(call: ByCall) -> any {
        print("args:", call.args);
        print("arg docs:", call.arg_docs);
        tool = self.tools[0];
        print("tool:", tool.name, "|", tool.doc);
        print("schema:", tool.schema);
        self.notes.append(tool.call({"path": "a.py"}));
        return call.decode(self.notes[-1]);
    }
}

obj Reviewer {
    has repo: str;

    def read_file(path: str, lines: int = 3) -> str {
        return f"{self.repo}/{path}: {lines} lines";
    }
}

sem Reviewer = "A reviewer of one repository.";
sem Reviewer.repo = "Where the repository is.";
sem Reviewer.read_file = "Read the start of a file.";
sem Reviewer.read_file.path = "The file, from the repository's root.";

def review(r: Reviewer, path: str, notes: list[str]) -> str by Canned(
    tools=[r.read_file], notes=notes
);

sem review = "Review one file.";
sem review.r = "The reviewer.";
sem review.notes = "What was read.";

with entry {
    notes: list[str] = [];
    print(review(Reviewer(repo="/src"), "a.py", notes));
    print(notes);
}
```

```output
args: {'r': {'repo': '/src'}, 'path': 'a.py'}
arg docs: {'r': 'The reviewer.'}
tool: read_file | Read the start of a file.
schema: {'type': 'object', 'properties': {'path': {'type': 'string', 'description': "The file, from the repository's root."}, 'lines': {'type': 'integer'}}, 'required': ['path']}
/src/a.py: 3 lines
['/src/a.py: 3 lines']
```

### The result type

The result type is required, and must have a JSON schema: `int`, `float`,
`str`, `bool`, `None`, an enum (by its members' names), a `list` or `set`, a
`dict` with `str` keys, a union of one type and `None`, and an `obj`, `node`
or `struct` whose fields have one (a field without a default is required).
Another type (`any`, `bytes`, a `tuple`, a `walker`, a function value or a
type holding one) is refused at compile time, once, where the function is
declared. `Iterator[ByEvent]` is not a result's type: it asks for the answer
as a stream.

## A `by` function that streams

`def f(a: A) -> Iterator[ByEvent] by e;` asks the answerer for its answer as it
goes. `e` gives a value of a class conforming to `ByStreams` (below), whose
`stream` is called with the `ByCall` and gives the events. The call has no
result type: its answer is text, and the `ByCall` carries no `result_schema`
and no `decode`. The arguments and the `sem`s are as for any `by`
function.

The function returns the iterator at once, and the answerer works as the
caller reads it:

```jac
import from stdjac { ByCall, ByEvent, ByEventKind, ByStreams, ByUsage }

"""An answerer that answers as it goes, without a model: a word at a time."""
obj Echo(ByStreams) {
    def stream(call: ByCall) -> Iterator[ByEvent] {
        words = str(call.args["message"]).split();
        for w in words {
            yield ByEvent(kind=ByEventKind.TEXT, text=w.upper() + " ");
        }
        yield ByEvent(kind=ByEventKind.USAGE, usage=ByUsage(requests=1, output_tokens=len(words)));
        yield ByEvent(kind=ByEventKind.DONE, text=" ".join(words).upper());
    }
}

def shout(message: str) -> Iterator[ByEvent] by Echo();

sem shout = "Say the message again, louder.";

with entry {
    used = ByUsage();
    for event in shout("what a day") {
        if event.kind == ByEventKind.TEXT {
            print("text:", repr(event.text));
        } elif event.kind == ByEventKind.USAGE and event.usage is not None {
            used.add(event.usage);
        } elif event.kind == ByEventKind.DONE {
            print("done:", event.text);
        }
    }
    print(used.requests, used.output_tokens);
}
```

```output
text: 'WHAT '
text: 'A '
text: 'DAY '
done: WHAT A DAY
1 3
```

An event is a `ByEvent`. Its `kind`, a `ByEventKind`, says which of its
fields it carries:

| `kind` | Says | Fields |
|---|---|---|
| `TEXT` | The next piece of the answer | `text` |
| `TOOL_CALL` | The answerer calls a tool | `tool` (its name), `args` (its arguments, by name), `call_id` (a name for this call) |
| `TOOL_RESULT` | What that call gave | `tool`, `call_id`, `result` (a `str`) |
| `USAGE` | What one request took | `usage` (a `ByUsage`) |
| `DONE` | The call is answered | `text` (the whole answer), `ended` (a `ByEnd`: why it ended) |

`ByEnd` says why a call ended:

| `ByEnd` | The call ended because |
|---|---|
| `ANSWERED` | The answerer had its answer |
| `STOPPED` | The program told it to answer now (`llm`'s `on_iteration`) |
| `ROUNDS` | It had used the rounds of tool calls it may make (`llm`'s `max_react_iterations`) |
| `CUT` | The answer ran past the most tokens a reply may have: it is what was written of it |

A `ByEvent` holds `any`s (a tool's arguments), so it is not sendable and
does not cross between spaces. A server's endpoint that passes an answer on
as it comes is a stream of a type of its own
([Serving a space](../apps/server.md#streams)), here of the answer's pieces:

```jac
import from stdjac { ByEvent, ByEventKind }

def answer(question: str) -> Iterator[ByEvent] by llm();

sem answer = "Answer the question.";

def:pub ask(question: str) -> Iterator[str] {
    for event in answer(question) {
        if event.kind == ByEventKind.TEXT {
            yield event.text;
        }
    }
}
```

## Writing an answerer: `By`

An answerer is a class that conforms to `By`, an
[interface](interfaces.md) with one method. A program imports the interfaces,
`ByCall`, `ByTool`, `ByChoice`, `ByEvent`, `ByEventKind`, `ByEnd`, `ByUsage`
and `ByError` from `stdjac` (`import from stdjac { By, ByCall }`):

| Name | What it is |
|---|---|
| `By` | The interface of an answerer that gives a result: `def invoke(call: ByCall) -> any abst;` |
| `ByStreams` | The interface of one that answers as it goes: `def stream(call: ByCall) -> Iterator[ByEvent] abst;` |
| `ByChooser` | The interface of one that chooses a walker's way: `def choose(choice: ByChoice) -> list[int] abst;` ([visit](visit.md#visit--by)) |
| `ByCall` | One call: `name: str`, `doc: str`, `args: dict[str, any]`, `arg_docs: dict[str, str]`, `result_schema: dict[str, any]`, `decode: Callable[[any], any] \| None` |
| `ByTool` | A tool ([above](#tools)): `name: str`, `doc: str`, `schema: dict[str, any]`, `call: Callable[[dict[str, any]], any]`, `alone: bool` (`False` for a `@reads` function's) |
| `ByEvent`, `ByEventKind`, `ByEnd` | One event of a streamed call, what it says, and why the call ended ([above](#a-by-function-that-streams)) |
| `ByUsage` | What an answerer used to answer (below) |
| `ByChoice` | The choice a chooser is asked to make: `name: str`, `asker: dict[str, any]`, `at: dict[str, any]`, `options: list[dict[str, any]]` ([visit](visit.md#visit--by)) |
| `ByError` | The exception an answerer raises when it cannot produce the result |
| `schema[T]()` | The JSON schema of type `T`, as `result_schema` is made |

`invoke` returns the result through `call.decode`, which decodes a JSON value
as the declared type and raises `CodecError` (from `stdjac`) when it
does not fit. An answerer that takes tools declares a field for them
(`has tools: list[ByTool] = [];`), and what `by Canned(tools=[lookup])` gives
it are `ByTool`s. One class may conform to several of the interfaces, as
`llm`'s does.

`ByUsage` counts what an answerer used, a model's requests for one:

| Field | Counts |
|---|---|
| `requests: int` | The requests made |
| `input_tokens: int`, `output_tokens: int` | The tokens they read and wrote |
| `cache_read_tokens: int`, `cache_write_tokens: int` | The input tokens read from the model's cache, and written to it |
| `seconds: float` | The time the requests took |
| `model: str` | The model that answered |
| `cost: float \| None` | What the requests cost, in dollars, where the plugin was told what its model charges ([below](#the-model-plugins)); `None` where it was not |

Every count starts at 0 (`model` at `""`, `cost` at `None`). `total.add(more)`
adds `more`'s counts to `total`'s, and takes its `model` when it names one.
The `cost` of the two is their sum, and `None` when either has requests that
were not priced.

This answerer has no model, and prints what the call carries:

```jac
import from stdjac { By, ByCall, ByTool }

enum Mood {
    HAPPY,
    SAD,
}

obj Verdict {
    has mood: Mood,
        score: int = 0;
}

sem Verdict.mood = "How the writer feels.";
sem Verdict.score = "0 to 10: how strongly.";

"""An answerer without a model, printing what a call carries."""
obj Canned(By) {
    has tools: list[ByTool] = [];

    def invoke(call: ByCall) -> any {
        print("name:", call.name);
        print("doc:", call.doc);
        print("args:", call.args);
        print("arg docs:", call.arg_docs);
        print("schema:", call.result_schema);
        tool = self.tools[0];
        print("tool:", tool.name, "|", tool.doc, "|", tool.call({"word": "day"}));
        return call.decode({"mood": "HAPPY", "score": 7});
    }
}

def lookup(word: str) -> str {
    return word.upper();
}

sem lookup = "Look a word up.";

def judge(text: str, strict: bool = False) -> Verdict by Canned(tools=[lookup]);

sem judge = "Judge the mood of a text.";
sem judge.text = "The text to judge.";

with entry {
    v = judge("what a day");
    print(v, v.mood.name);
}
```

```output
name: judge
doc: Judge the mood of a text.
args: {'text': 'what a day', 'strict': False}
arg docs: {'text': 'The text to judge.'}
schema: {'type': 'object', 'properties': {'mood': {'enum': ['HAPPY', 'SAD'], 'description': 'How the writer feels.'}, 'score': {'type': 'integer', 'description': '0 to 10: how strongly.'}}, 'required': ['mood']}
tool: lookup | Look a word up. | DAY
Verdict(mood=<Mood.HAPPY: 1>, score=7) HAPPY
```

A reply that does not fit the result type is refused when it is decoded:

```jac
import from stdjac { By, ByCall, CodecError }

obj Wrong(By) {
    def invoke(call: ByCall) -> any {
        return call.decode({"n": "seven"});
    }
}

obj Count {
    has n: int;
}

def count(text: str) -> Count by Wrong();

with entry {
    try {
        print(count("a b c"));
    } except CodecError as e {
        print("CodecError:", e);
    }
}
```

```output
CodecError: .n: expected an int, got 'seven'
```

## Asking a model: `llm`

`llm(...)` asks a language model. `llm` is built in: a program says it
without importing it. It sends the function's
`sem` and its parameters' as the instructions and the arguments as JSON, asks
for a reply in the result's schema, runs the tools the model calls and gives
it their results, and decodes the final reply as the result type. It conforms
to `By`, to `ByStreams` and to `ByChooser`, so it gives a typed result,
streams an answer, and chooses a walker's way. What a program names beside
it is imported from `stdjac`: `Effort`, `Message`, `IterationAction`,
`IterationContext`, `on_usage`, `latest_turns`, and `LLM`, the class of what
`llm(...)` gives.

Which model answers is not said in source. `llm` is an abstraction, and what
speaks to a model is the project's `llm` [plugin](../apps/plugins.md), named
in `jac.toml`: a function written `by llm()` is the same function under each.

```jac
import from stdjac { ByError }

obj Ticket {
    has title: str,
        urgent: bool = False,
        tags: list[str] = [];
}

sem Ticket.title = "A short title for the support ticket.";
sem Ticket.tags = "Lowercase words naming the product areas involved.";

def triage(message: str) -> Ticket by llm(max_tokens=500, max_output_retries=2);

sem triage = "Turn a customer's message into a support ticket.";
sem triage.message = "The message as the customer wrote it.";

with entry {
    try {
        print(triage("The app crashes when I upload a photo."));
    } except ByError as e {
        print("could not triage:", e);
    }
}
```

`llm` takes these keyword arguments:

| Argument | Default | Meaning |
|---|---|---|
| `max_tokens` | 4000 | The most tokens one reply may have |
| `effort` | `Effort.DEFAULT` | How hard the model works at it, where its provider has such a setting: `Effort.LOW`, `Effort.MEDIUM`, `Effort.HIGH`, or the provider's own choice |
| `tools` | `[]` | A `list[ByTool]`: what the model may call ([Tools](#tools)), each described by its `sem` and its parameters' |
| `max_react_iterations` | 8 | Rounds of tool calls before the model must answer |
| `on_iteration` | `None` | A `Callable[[IterationContext], IterationAction]` called after each round of tool calls; returning `IterationAction.ABORT_WITH_SUMMARY` makes the model answer now |
| `max_output_retries` | 1 | How many times a reply that does not fit the result type is sent back to be corrected |
| `system_prompt` | `""` | Instructions said to the model before the function's `sem` |
| `conversation` | `None` | A `list[Message]`: the turns before this call ([below](#conversations)) |
| `select` | 1 | For `visit ... by`: how many of the nodes to choose, a number or a `(least, most)` pair |
| `intent` | `""` | For `visit ... by`: what the choice is for, said to the model |
| `media` | `None` | Pictures and PDFs the model reads with the arguments: a `File` or `bytes`, or a list of them ([below](#pictures-and-pdfs)) |

A call raises `ByError` when the model's provider cannot be reached or
answers with an error, when every model declines the request, and when the
reply still does not fit the result type after the retries. A streamed call
raises it where its events are read.

### Rounds of tool calls

A reply that calls tools is a round. `llm` runs the round's calls, sends the
model all of their results together, in the order it asked, and asks again:
no tool is still running when the model is next asked.

- **A tool runs alone,** after the calls before it and before the calls
  after it, unless its function is declared [`@reads`](#tools-that-only-read-reads).
- **Consecutive `@reads` calls of a round run at once,** each as a task
  with the context variables of the thread that made the call. A round of
  two reads, a write and two more reads is the first two at once, then the
  write, then the last two at once.
- **A tool that raises** gives the model its failure as that call's result.
  The round's other calls are not stopped.
- **`on_iteration` is called after each round,** and `max_react_iterations`
  counts them.

### Pictures and PDFs

`media` gives the model pictures and PDFs with the arguments. A parameter
passed to it is [the answerer's](#a-parameter-the-answerer-takes-whole), so
its bytes go to the model as a file, not inside the arguments' JSON:

<!-- example: not checked: it asks a model, which needs a key and the network -->
```jac
obj Receipt {
    has shop: str,
        total: float;
}

def read_receipt(scan: bytes) -> Receipt by llm(media=scan);

def compare(photos: list[File]) -> str by llm(media=photos);
```

- **A `File` is sent as its `ctype` says, and `bytes` as what they begin
  as.** PNG, JPEG, GIF, WebP and PDF are taken; anything else raises
  `ByError`.
- **The model has to read that type.** A model that reads only pictures
  refuses a PDF, and its API's error is the call's `ByError`.
- **`openai` sends a PDF as OpenAI's `file` part.** Gemini's API takes a PDF
  as an image part instead: set `pdf_part = "image_url"`.

### The model plugins

neojac ships two `llm` plugins. `anthropic`, the standard one, speaks
Anthropic's Messages API. `openai` speaks the OpenAI-compatible Chat
Completions API, which most other providers serve too. A project names
`openai` and points it at its provider:

```toml
[llm]
plugin = "openai"

[llm.openai]
address = "https://generativelanguage.googleapis.com/v1beta/openai"
model = "gemini-3-flash-preview"
pdf_part = "image_url"
```

OpenAI's own API needs only a `model`. Another provider or local server with
an OpenAI-compatible API (Together, Groq, OpenRouter, Ollama, vLLM) is set up
as Gemini is here: its address and a model it serves.

Both take these settings, in `[llm.anthropic]` or `[llm.openai]`, and `pdf_part` is `openai`'s alone:

| Setting | Type | `anthropic`'s default | `openai`'s default | Meaning |
|---|---|---|---|---|
| `model` | `str` | `claude-sonnet-5-5` | `gpt-5-mini` | The model that answers, as its provider names it. `JAC_LLM_MODEL` where the program runs |
| `address` | `str` | `https://api.anthropic.com` | `https://api.openai.com/v1` | Where the API is, or a gateway to it: requests go to `<address>/v1/messages` for `anthropic` and `<address>/chat/completions` for `openai`. `JAC_LLM_ADDRESS` |
| `timeout` | `int` | 60 | 60 | Seconds one request may take |
| `retries` | `int` | 0 | 0 | How many times a request the API refuses for load (408, 409, 429, 5xx) or cannot be reached with is made again, after 2, 4, 8 ... seconds |
| `rates` | `dict[str, list[float]]` | `{}` | `{}` | What each model charges, by its name: four numbers, the dollars for a million tokens of input, of output, read from the cache and written to it |
| `pdf_part` | `str` | | `file` | How `openai` sends a PDF: as OpenAI's `file` part, or as an `image_url` part, which Gemini's API needs |
| `key` | `Secret` | `ANTHROPIC_API_KEY` | `OPENAI_API_KEY` | The API key, read from that variable of the environment where the program runs, or from `JAC_LLM_KEY`, and never written in `jac.toml`. Without one, `anthropic` raises `ByError`, and `openai` sends none, for a local server |

```toml
[llm.anthropic]
model = "claude-sonnet-5-5"
timeout = 30
rates = { claude-sonnet-5-5 = [2.0, 10.0, 0.1, 2.5] }
```

`rates` is what gives a `ByUsage` its `cost`: a request's tokens at the rate
of the model that answered it. The plugin holds no prices of its own, since
what a model charges is the project's to know: it differs by provider, by
platform and by date. A request whose model `rates` does not name has no
cost (`None`), and a rate that is not four numbers ends the first call with
`ByError`. A rate is flat: where a provider charges by a prompt's size or by
how long the cache keeps what is written, give the rate the program's
requests are charged.

What each does of its own:

- **`anthropic`** sends the instructions (the `system_prompt`, the `sem`s)
  marked for the API's prompt cache, so the requests of one call, and calls
  with the same instructions, read them from it: `ByUsage` counts those
  tokens apart. A request the model's safety classifiers decline re-runs on
  the API's default fallback model.
- **`openai`** asks for a reply that fits a schema in the API's strict mode,
  so the model fills in fields that have a default too. `effort` is sent as
  `reasoning_effort`, which only a reasoning model takes. Gemini 2.5 refuses
  tools and a schema in one request; Gemini 3 takes them.

### Writing a model plugin

A plugin for another provider conforms to `llm.contract`'s `Model`
([Plugins](../apps/plugins.md#what-a-plugin-imports)):
`def ask(request: ModelRequest) -> Iterator[ByEvent] abst;`, after
`def open(host: dyn Host) abst;`, the first thing asked of it. `ask` makes one
request and gives its events: each piece of the answer's text as a `TEXT`
event, for a `live` request, and last a `DONE` whose `value` is the
`ModelReply`. The rounds of tool calls, the retries of a reply that does not
fit and conversations are stdjac's, the same for every plugin.

| Type | Holds |
|---|---|
| `ModelRequest` | `system`, the instructions; `messages: list[Message]`; `tools: list[ModelTool]` (each a `name`, a `doc` and a JSON `schema`); `result_schema`, which the answer must fit (`None` for text); `max_tokens`; `effort`; `answer_now`, when the model may call no more tools; `live`, when the answer is wanted as it is written |
| `ModelReply` | `message`, the model's (`TEXT` parts, `TOOL_CALL` parts, and `KEPT` parts for what only the provider reads back); `stop`, a `Stop` (`END`, `TOOLS`, `MAX_TOKENS`, `REFUSED`); `usage`, a `ByUsage` |

The text of a reply asked to fit a schema is the JSON value itself.

### Streaming

`def chat(...) -> Iterator[ByEvent] by llm(...);` asks the API for its reply
as it is written. The events of one call, in order:

- for each request it makes: a `TEXT` for each piece of text as the model
  writes it, then a `USAGE`; when the model called tools, a `TOOL_CALL` for
  each, the tools run, and a `TOOL_RESULT` for each, and the next request
  follows;
- then one `DONE`, whose `text` is everything the model said in the call
  and whose `ended` says why it ended.

### Conversations

`conversation` is the turns before the call, a `list[Message]`
(`Message` is imported from `stdjac`). The model is sent them before the call's arguments, and when
the call has answered, its own messages are appended to the list: the
arguments, each round of tool calls and their results, and the answer. The
caller that keeps the list keeps the conversation.

| Name | Fields |
|---|---|
| `Message` | `role: str` (`"user"` or `"assistant"`), `parts: list[Part]` |
| `Part` | `kind: PartKind`, and by its kind: `text` for `TEXT`; `name`, `input` (the arguments, as the JSON text the model wrote) and `id` for `TOOL_CALL`; `id`, `text` (what the tool gave) and `failed` for `TOOL_RESULT`; `data` (the bytes) and `ctype` for `MEDIA` |
| `PartKind` | `TEXT`, `TOOL_CALL`, `TOOL_RESULT`, `MEDIA` |

A `Message` is an `obj` of sendable fields: a program may keep a
conversation in a node's field, and send it across a crossing.

A conversation grows with every call. `latest_turns(history, most)` (from
`stdjac`) gives the most recent of its turns that fit in `most` characters
of text and tool input: whole turns only, each from what the caller said to
the model's last word on it, so no tool call is parted from its result, and
never fewer than the latest turn. A program that keeps a long conversation
gives a call `latest_turns` of it, and keeps what the call adds.

<!-- example: not checked: it asks a model, which needs a key and the network -->
```jac
import from stdjac { ByEvent, ByEventKind, ByUsage, Message, on_usage }

def lookup(word: str) -> str {
    return word.upper();
}

sem lookup = "Look a word up.";

def chat(message: str, history: list[Message]) -> Iterator[ByEvent] by llm(
    conversation=history, tools=[lookup], system_prompt="Answer in one sentence."
);

sem chat = "Talk with the user.";

glob spent: ByUsage = ByUsage();

with entry {
    on_usage(lambda (used: ByUsage) { spent.add(used) });
    history: list[Message] = [];
    for turn in ["hello", "and again"] {
        for event in chat(turn, history) {
            if event.kind == ByEventKind.TEXT {
                print(event.text, end="");
            } elif event.kind == ByEventKind.TOOL_CALL {
                print(f"[{event.tool} {event.args}]");
            } elif event.kind == ByEventKind.DONE {
                print();
            }
        }
    }
    print(len(history), "messages kept,", spent.requests, "requests");
}
```

With a model that answers the first turn in one request and calls `lookup`
in the second, it prints the answers as they are written, and ends:

```text
Hi there
Looking. [lookup {'word': 'again'}]
It is AGAIN.
6 messages kept, 3 requests
```

`history` is passed whole to the answerer, so it is the answerer's and not an
argument the model is sent as JSON
([above](#a-parameter-the-answerer-takes-whole)): the model is sent `message`.

### What a call used

- **`on_usage(f)`** registers `f`, a `Callable[[ByUsage], None]`, for the
  whole program. It is called after each request any `llm()` makes, with
  what that request used, on the thread that made it. Its `cost` is what
  the request cost, where the plugin was told its model's rates
  ([above](#the-model-plugins)).
- **A streamed call** gives the same `ByUsage` in its `USAGE` events.
- **`on_iteration`** is given an `IterationContext`: `iteration`, the rounds
  of tool calls the call has made, and `usage`, what its requests have used
  so far, their `cost` among it: a program stops a call that has spent
  enough by answering `IterationAction.ABORT_WITH_SUMMARY`.

## What `sem` strings are read by

A `sem` is a description for whatever reads declarations: it does not change
what the program computes. `sem Doc.title = "The document's title.";` gives
`title` no value: `Doc().title` is still its default.

- A `by` call reads the function's `sem` (as `ByCall.doc`), its parameters'
  (`arg_docs`), the `sem`s of the result type's fields (the schema's
  `description`s) and each tool's and its parameters': a function's, or a
  method's for a tool that is a method. An enum's schema says what each
  member with a `sem` means (`CRITICAL: Breaks production, ...; LOW: ...`),
  after the `sem` of the field or parameter that holds it.
- `visit ... by` reads the `sem`s of the classes it shows the chooser, the
  walker's, the nodes' and the edges', and of their fields
  ([visit](visit.md#visit--by)).
- [Compile-time reflection](reflection.md) reads them as the `doc` of
  `fields(T)`, `params(f)` and each of `members(T)`.

A `sem` is written in the module that declares its target, and names
something that module declares: one that names no class, function, method,
parameter, field or enum member is E2018, and one for a name imported from another module is E2198
(it would be read by nothing, since a target's `sem`s are looked for where
the target is declared). A docstring is not a `sem`: it documents the code
for its reader, and a `sem` describes the declaration to an answerer.

## What is rejected

| Code | When |
|---|---|
| E0033 | A `by` function with no return type |
| E1229, E0109 | A `by` function whose result type has no JSON schema |
| E5090 | `by` on an ability, an `impl` with a `by` body, the `by` operator in an expression (`a by b`) anywhere but a `visit` statement, a tool that is a method of an object that may be `None` |
| E1229 | A function given as a tool that is not one: a generic function, an `async` one, a generator, a static method |
| E1001 | Something given as a tool that is no function or method: `tools=["lookup"]` |
| E1643 | A `@reads` function that changes what it did not make ([above](#tools-that-only-read-reads)) |
| E1053 | An answerer that does not conform to the interface its use asks for: `By` for a result, `ByStreams` for `Iterator[ByEvent]`, `ByChooser` for `visit ... by` |
| W2001 | A `by` expression that names what the module does not import |
| E0156 | `sem x is "..."` |
| E2018 | A `sem` whose target is no class, function, method, parameter, field or enum member: a member the enum does not have, for one |
| E2198 | A `sem` for something another module declares |
| E0002 | A `sem` without its `;` |

```jac
# expect: E0033
def summarize(text: str) by llm();
```

```jac
# expect: E5090 x2
walker Tour {
    can go with Root entry by llm();
}

def plain(q: str) -> str;

impl plain(q: str) -> str by llm();
```

```jac
# expect: E1229 x2, E0109 x2
def pair(text: str) -> tuple[int, int] by llm();

def scorer(text: str) -> Callable[[int], int] by llm();
```

```jac
# expect: E2018 x2, E2198
import from os { getcwd }

obj Doc {
    has title: str = "";
}

sem Doc.heading = "Doc declares no field or method of this name.";
sem Article.title = "Nothing here is named Article.";
sem getcwd = "Declared in another module.";
```

```jac
# expect: E2018 x2
enum Mood {
    HAPPY,
    SAD,
}

obj Desk {
    def look(word: str) -> str {
        return word;
    }
}

sem Mood.CALM = "Mood has no member of this name.";
sem Desk.look.page = "look has no parameter of this name.";
```

```jac
# expect: E5090, E1001
obj Desk {
    def look(word: str) -> str {
        return word;
    }
}

def ask(d: Desk | None, word: str) -> str by llm(tools=[d.look]);

def name(word: str) -> str by llm(tools=["look"]);
```

```jac
# expect: E1643 x2
import from jaclang.comptime { reads }

glob asked: int = 0;

obj Shelf {
    has taken: list[str] = [];

    @reads
    def take(title: str) -> bool {
        self.taken.append(title);
        return True;
    }
}

@reads
def count(word: str) -> int {
    asked += 1;
    return asked;
}
```

```jac
# expect: E1053
import from stdjac { By, ByCall, ByEvent }

obj Plain(By) {
    def invoke(call: ByCall) -> any {
        return call.decode("done");
    }
}

def chat(message: str) -> Iterator[ByEvent] by Plain();
```

```jac
# expect: E0156
obj Doc {
    has title: str = "";
}

sem Doc.title is "The document's title.";
```

```jac
# expect: W2001, E5090
def title(text: str) -> str by Plain();

with entry {
    y = 3 by 4;
}
```

## Differences from Python and from the reference design

- **Python has no counterpart in the language**; a library call does this
  there, and its result is whatever the library returns. Here the result is
  decoded and checked as the declared type.
- **Here `llm` is built in**, and any class conforming to
  `By` may answer a `by` function. Which model `llm()` asks is the project's
  `llm` plugin, in `jac.toml`, where the reference design's byllm names a model in source.
- **In the reference design a tool is a function named in `tools=[...]`, and
  byllm's `mark_serialize` and `parallelize` say how a round's calls run;
  here a tool is a `ByTool` value** made of a function or a method wherever
  one is given, and a function declared `@reads`, which the compiler holds
  to it, is what a round runs at once.
- **In the reference design byllm reports what a call cost, and compacts a long
  conversation; here a plugin prices a request by the rates `jac.toml`
  gives it,** and `latest_turns` cuts a conversation at its turns.
- **In the reference design `visit [-->] by llm();` takes whatever byllm returns; here the
  chooser conforms to `ByChooser`**, the nodes are a list of one node type,
  and the walker visits those chosen, in the order chosen.
- **In the reference design `sem x is "..."` is accepted; here the one spelling is `sem x =
  "...";`** (E0156).

## See also

- [visit](visit.md#visit--by): `visit <nodes> by <chooser>;`.
- [Reflection](reflection.md): `fields`, `params` and their `doc`.
- [Interfaces](interfaces.md): `By` is an interface.
- [Impl blocks](impl.md): the dotted paths a `sem` shares with `impl`.
