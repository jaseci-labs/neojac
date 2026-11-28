---
description: neojac docs and neojac skills - the map of the pages, a section, a page, what a word names, search, the pages served to a browser with --serve, --json, --path and --check, where the pages are, and listing, printing and installing skills.
keywords: documentation, neojac docs, docs search, skill, skills install, SKILL.md, nav.json
---
# docs and skills

`neojac docs` prints this documentation. The pages ship with neojac, for its own version, so what they say is what the neojac you run does, and reading them needs no network. `neojac skills` prints playbooks for common tasks, written for agents, and installs them into a project.

```sh
neojac docs                     # the map: every section and its pages
neojac docs section basics      # a section's pages, each with what it covers
neojac docs language/walkers    # one page
neojac docs visit               # the page that defines a word
neojac docs E1307               # what an error code means, and the fix
neojac docs search edge filter  # the pages that mention a text
neojac docs --serve             # the pages, in a browser
neojac skills                   # the skills
```

An answer goes to stdout with exit status 0. A question with no answer goes to stderr with status 1, with the nearest word that has one.

## The map

`neojac docs` alone prints how to look things up, then every section of the pages under its heading, a section within another a level below it, and under each heading the section's pages, each by its path and title. It is Markdown, and small enough to read at once (about 10 KB):

```text
# neojac documentation

240 pages, in /Users/me/.neojac/0.3.2/docs. Under each section's heading below are its pages, each by its path and title.

- `neojac docs <page>` prints a page: `neojac docs start/primer`.
- `neojac docs section <heading>` prints a section's pages, each with what it covers: `neojac docs section basics`.
- `neojac docs <word>` prints what defines a word: a keyword or operator (`visit`, `++>`), a diagnostic code (`E1307`), a module (`os.path`), a `jac.toml` key (`check.lint.select`), a command (`build`), a rule of the grammar (`archetype`).
- `neojac docs search <text>` finds the pages and sections that mention a text.
- `neojac docs --path` prints the directory these files are in, for `grep`.
- `neojac skills` lists playbooks for common tasks.
- `--json` after any of them prints the same as data.

## Start here

- `start/index`: What neojac is
- `start/install`: Install
...

## Language

- `language/principles`: Principles

### Basics

- `language/lexical-structure`: Lexical structure
...
```

Two kinds of page have a lookup of their own, so the map says how to reach them instead of listing them: the pages of diagnostic codes, which it counts, since `neojac docs E1307` prints a code's entry, and the skills, which it names, since `neojac skills` lists them.

A page is named by its path under the documentation's directory, without `.md`: `start/index`, `language/walkers`, `toolchain/docs`.

## A section

`neojac docs section <heading>` prints a section of the map with what each page covers, its front matter's `description`: the section whose heading it is given, in upper or lower case, and the sections under it. Every page is in a section, so every page is in the map or one `section` away from it.

```sh
neojac docs section compile time
```

```text
# Compile time

- `language/compile-time`: The comptime keyword in every position it may appear (globals, locals, functions, if, for, assert, parameters, members, imports) and what each form does as the program compiles.
...

`neojac docs <page>` prints one of them.
```

Several words are one heading, so no quoting is needed. A heading no section has is an error, with the nearest that one has:

```text
neojac docs: there is no section 'basic' (did you mean 'basics'?)

Run `neojac docs` for the map, which heads each section with its title.
```

The sections are `nav.json`'s, in its order. A page it names outside every section heads a section of its own, and the pages it leaves out are in a last section, "Other pages".

## A page or a word

`neojac docs <word>` takes one word and prints what it names. The word may be:

| Word | Answered with | Example |
|---|---|---|
| A page's path | The page | `neojac docs toolchain/build` |
| A diagnostic code, in any case | The code's entry: the compiler's message, what it means, a program that raises it, the fix, and the page it is on | `neojac docs E1307`, `neojac docs e1307` |
| A keyword of a page | The page that defines it. Keywords are the language's keywords and operators, builtins, modules, `jac.toml` keys in dotted form, environment variables, lint rules and concepts | `neojac docs visit`, `neojac docs ++>`, `neojac docs print`, `neojac docs check.lint.select`, `neojac docs NO_COLOR` |
| A command | What `neojac help <command>` prints, which ends with the command's guide page | `neojac docs build` |
| A rule of the grammar | The rule in EBNF, and the pages that explain it | `neojac docs archetype` |
| The last part of a page's path, or a skill's name | That page | `neojac docs walkers`, `neojac docs first-program` |

A page is printed as its Markdown, without the lines of front matter at its top.

Several words are one name with spaces in it, so no quoting is needed: `neojac docs flow for` looks up `flow for`. An operator the shell would read is quoted: `neojac docs '-->'`.

When a word names several things, the first in the order of the table is printed, after a note of the others:

```sh
neojac docs install
```

```text
> `install` names more than one thing. What follows is the command `neojac install`. The others:
> - `neojac docs start/install`: Installing a neojac release with the installer, its options, where it puts things, checking that it works, and uninstalling.

Install the project's Python packages.

Usage: neojac install [--pypi <package>...] [--frozen]
...
Its guide: `neojac docs interop/python`.
```

A code no page has an entry for yet is still answered, with the compiler's message for it.

A word that names nothing is an error that offers the nearest word that does:

```text
neojac docs: nothing is named 'walkrs' (did you mean 'walkers'?)

Run `neojac docs search walkrs` to search the pages for it, or `neojac docs` for the map.
```

## Search

`neojac docs search <text>` finds the pages that mention the text's words, best first. Each word is matched on its own, ignoring case, anywhere in a word of the page: `search build cache` finds the pages that hold both `build` and `cache`, and when no page holds every word, those that hold any. A word weighs most in a page's title or path, then in its keywords, then in its description, then in its text.

```sh
neojac docs search build cache -n 3
```

```text
toolchain/cache: The build cache
    line 3: A build compiles each module on its own and keeps what it compiles in the build cache: a directory of your own, shared by every build you run. A rebuild compiles only what an edit changed, and a build with nothing changed does nothing at all.
toolchain/build: build
    line 24 (under "What a build does"): 3. Generates code, compiles each module on its own (reusing what the [build cache](cache.md) holds), and links.

`neojac docs <page>` prints one of them.
```

Each result is the page, its title, and the line that holds most of the words, with its number in the page and the heading it is under. `-n <count>` sets how many pages are shown (default 10). A search that finds nothing is an error (`no page mentions '<text>'`), and so is one with no text.

## In a browser

`neojac docs --serve` serves the same pages to a browser, and prints where:

```text
The documentation is at http://127.0.0.1:8091/
```

- **A page reads as it is written.** Its headings, tables, lists and code are HTML, and a link to another page, or to a heading of one, goes there.
- **Jac code is colored by neojac's own lexer.** A keyword, a string, a number and a comment are what the compiler takes them for. An example that shows a lexical error is left plain.
- **The map is beside the page**, by `nav.json`'s sections, with the page being read marked.
- **One box searches and looks up.** Typing shows the pages that mention the text, as `docs search` finds them, each at the heading it matched. When the text is a word `neojac docs <word>` answers with a page (a code, a keyword, a command's guide, a rule), what defines it is the first result. Enter goes to the first result, and Escape clears the box.
- **The page loads nothing from anywhere else.** Its code is a Jac program, compiled for the browser when neojac is built, and it is served from the same address as the pages.

`neojac docs <page | word> --serve` opens at that page, or at what defines the word: `neojac docs E1307 --serve` prints the address of that code's entry. A word that names nothing is the error it is without `--serve`.

`--listen <address>` says where it serves (`127.0.0.1:8091` when not given; port 0 is any free port). It serves until it is interrupted, and opens no browser: open the address in one, or have [`neojac browse`](browse.md) do it. The pages are read once, when it starts.

## --json

`--json`, after any form, prints the same answer as JSON, for a program to read:

| Form | JSON |
|---|---|
| `neojac docs --json` | `{"path", "sections": [{"title", "level", "pages": [{"page", "title"}]}]}`: the map's sections in order, `level` 1 for a section and 2 for one under it, each with all its pages, those the map counts too |
| `neojac docs section <heading> --json` | A list of `{"title", "level", "pages"}`, the section and those under it, each page as below without its text |
| `neojac docs <word> --json` | `{"word", "kind", "text", "also", "page", "title", "description", "keywords", "grammar"}`. `kind` is `page`, `code`, `keyword`, `command` or `rule`; `text` is what the plain form prints; `also` lists the other things the word names. The page's fields are absent for a command with no guide page |
| `neojac docs search <text> --json` | A list of `{"page", "title", "description", "heading", "line", "excerpt"}` |
| `neojac skills --json` | A list of `{"name", "description", "page"}` |
| `neojac skills <name> --json` | `{"page", "title", "description", "keywords", "grammar", "text", "name"}` |

```sh
neojac docs E1030 --json
```

```text
{
  "word": "E1030",
  "kind": "code",
  "text": "## E1030\n\n```text\n{owner} has no {kind} '{name}'\n```\n\n...",
  "also": [],
  "page": "reference/diagnostics/e10-1",
  "title": "E1001 to E1041: values and their types",
  "description": "Diagnostics E1001 to E1041, ...",
  "keywords": [],
  "grammar": []
}
```

## Where the pages are

The pages are Markdown files in a directory `docs/`, which neojac finds as it finds its runtime ([build](build.md#how-the-runtime-is-found)): a release carries them inside its one file, and a neojac built from source reads the `docs/` of the directory `NEOJAC_STORE` names.

| neojac | Its pages |
|---|---|
| A release | Inside it, and written out as `store/<id>/docs/` in its cache the first time a command reads them ([The build cache](cache.md#what-neojac-writes-out-of-itself)) |
| Built in a checkout, run with `NEOJAC_STORE=build/store` | The checkout's `docs/` |

`neojac docs --path` prints the directory, for tools that read the files themselves:

```sh
grep -rl "flow for" "$(neojac docs --path)"
```

A neojac with no `docs/` stops with:

```text
neojac: no documentation found: this neojac carries no docs/nav.json
```

`nav.json` in that directory gives the sections, their titles and their pages' order. Each page starts with front matter: `description` (the line `neojac docs section` shows for it), `keywords` (the words the page is the definition of) and `grammar` (the grammar's rules it explains). The same files are what the documentation's web reader shows.

## --check

`neojac docs --check` lists what is wrong with the pages, one problem to a line, on stderr, with exit status 1, then `N problems in <dir>`. With nothing wrong it prints nothing and exits 0. It is for people who write the pages. It reports:

- a page with no description or no `# ` title, or that `nav.json` leaves out, and a page `nav.json` names that is not there;
- a section of `nav.json` with no title, and two sections with one title, since `neojac docs section` takes a section by its title;
- a keyword two pages claim;
- a diagnostic code with no entry, an entry whose first `text` block is not the compiler's message for the code, and an entry for a code there is not;
- a rule of the grammar no page's `grammar:` names, and a name there that is no rule;
- a rule a page quotes in an `ebnf` block that the grammar does not have, or has otherwise: the page's text is shown beside the grammar's. Only spacing and line breaks may differ;
- a keyword of the language or a lint rule no page claims;
- a command whose guide page is not there;
- a link between pages that leads to no page, and a link to a heading its page does not have.

### Writing pages

A page is Markdown with front matter:

```text
---
description: One line saying what the page covers.
keywords: walker, spawn
grammar: archetype, archetype_member
---
# Walkers
```

- `description` is required; `keywords` and `grammar` are lists separated by commas. A keyword belongs to one page in the whole tree.
- The page has one `# ` title, and links to other pages by relative links to their `.md` files.
- Every `jac` block is a whole module that neojac takes as the page says, which neojac's own tests check: one whose first line is `# expect: <code>[ x<count>], ...` is refused by `neojac check` with exactly those errors; one followed by an `output` block is built and run, and prints exactly that; any other passes `neojac check`. A block after the line `<!-- example: not checked: <reason> -->` is left alone.
- An `ebnf` block quotes rules of the grammar, each whole and as `reference/grammar.md` has it, so a page's rule changes when the parser's does. Copy the rule from that page, or from `neojac docs <rule>`.
- Two pages are generated from the compiler: `reference/commands.md` by `neojac help --markdown`, and `reference/grammar.md` by `neojac grammar compiler/parsing/parser.jac --page` ([Inspect](inspect.md#grammar)).

## Skills

A skill is a playbook for one task, written for an agent: when to use it, the steps, the commands, and what a correct result looks like. Skills are pages too, each a directory under `docs/skills/` holding a `SKILL.md`, whose front matter names the skill (`name:`) and says when to use it (`description:`).

```sh
neojac skills                  # list them, each with when to use it
neojac skills writing-jac      # print one
neojac skills install          # copy every skill into .agents/skills/ here
```

`neojac skills <name>` prints the skill's `SKILL.md`, without its front matter. `neojac docs <name>` prints it too.

### skills install

`neojac skills install` copies skills where an agent loads them from: each skill's whole directory, `SKILL.md` and what is beside it, to `.agents/skills/<name>/` in the directory it is run in. It prints the path of each `SKILL.md` it wrote:

```sh
neojac skills install writing-jac
```

```text
.agents/skills/writing-jac/SKILL.md
```

- With no names it installs every skill; with names, those.
- `--to <dir>` writes to `<dir>/<name>/` instead of `.agents/skills/<name>/`.
- A skill already there is replaced whole, so installing again after upgrading neojac brings the skills to that release's.

A name that is no skill is an error (`there is no skill '<name>'`), with the nearest that is, and nothing is installed. `--to` with no directory after it is an error.

## What goes wrong

| Message | Cause |
|---|---|
| `nothing is named '<word>'` | No page, code, keyword, command or rule is that word. Try `neojac docs search <word>` |
| `search needs the text to look for` | `neojac docs search` with nothing after it |
| `no page mentions '<text>'` | No page holds any of the words |
| `section needs a section's heading, as the map has it: section basics` | `neojac docs section` with nothing after it |
| `there is no section '<heading>'` | No section of the map has that heading. `neojac docs` prints them |
| `it has no option '--jsn' (did you mean '--json'?)` | A mistyped option |
| `no documentation found: ...` | This neojac has no `docs/` beside its `bin/` or above it |
| `--json is an option of the pages printed, and --serve serves them` | `--serve` with `--json`, `--path`, `--check` or `-n` |
| `--serve opens at a page or a word: the page it serves has the search` | `neojac docs search <text> --serve` |
| `--listen is where --serve serves the pages` | `--listen` without `--serve` |
| `cannot serve at <address>: ...; name another with --listen` | The address is taken, or is not this machine's |
| `this neojac carries no page for the viewer (<bundle>)` | This neojac has no `lib/viewers/docs/`: it was built from source, and the directory `NEOJAC_STORE` names has none |
| `there is no skill '<name>'` | `neojac skills <name>` or `skills install <name>` with a name no skill has |
