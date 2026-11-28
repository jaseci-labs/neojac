---
name: testing-and-formatting
description: Use when writing or running tests for Jac code, reading a failing neojac test run, formatting Jac source with neojac fmt, or satisfying the lint rules a project keeps: test blocks, neojac test with -k, fmt, fmt --check, fmt --fix, [fmt] notes, human_mode and [check.lint].
---
# Testing and formatting

## When to use this

Use it to add tests to Jac code, to run them and read what failed, to format what you changed, and to satisfy a project's lint rules. It assumes `writing-jac`; a project with no `jac.toml` yet starts in `starting-a-project`.

## Before you start

```sh
neojac docs language/tests       # the test declaration
neojac docs toolchain/test       # neojac test: finding modules, -k, -o, output, statuses
neojac docs toolchain/fmt        # the layout, --check, --fix
neojac docs toolchain/lint       # every lint rule, and which fmt --fix applies
```

## Steps

### 1. Write test blocks

A test is a top-level declaration: `test "name" { ... }` with `assert` statements. Put tests in the module, or in its test annex `<module>.test.jac` beside it or `test/<module>.test.jac`; an annex sees the module's names without importing them. A test passes when its body ends, and fails on a failed `assert` (shown with its message) or any other exception.

```jac
"""Prices in cents, and their text."""

def cents(text: str) -> int {
    (whole, _, frac) = text.partition(".");
    return int(whole) * 100 + int((frac + "00")[:2]);
}

def label(c: int) -> str {
    return f"{c // 100}.{c % 100:02d}";
}

with entry:__main__ {
    print(label(cents("12.5")));
}

test "whole numbers" {
    assert cents("3") == 300;
}

test "rounds to two places" {
    assert cents("1.239") == 123;
}

test "label pads cents" {
    got = label(705);
    print("label was", got);
    assert got == "7.5", f"got {got}";
}

test "parse then label is the same text" {
    for t in ["0.05", "12.50"] {
        assert label(cents(t)) == t;
    }
}

test "text that is no number" {
    cents("x");
}
```

- A test is checked like the rest of the module. Each test runs in a process of its own: the module's own code (globals and plain `with entry` blocks) runs first, then the one test, so a global one test changes is unchanged for every other, and a module's tests run at the same time. A test that writes files writes them under `os.environ["NEOJAC_TEST_DIR"]`, a directory `neojac test` gives each test.
- **A program's main code goes in `with entry:__main__`**, as above: it runs when the module is built and run as the program, and not under `neojac test` or when the module is imported. Keep a plain `with entry` for setup the tests rely on.
- To test that something raises, catch it: `try { cents("x"); assert False, "no error"; } except ValueError {}`.
- A walker is tested by building a small graph in the test, spawning, and asserting on the walker's fields (`modelling-with-graphs`).

### 2. Run the tests of what you changed

```sh
neojac test prices.jac             # one module; its annexes come with it
neojac test prices.jac -k label    # only tests whose names contain "label"
neojac test                        # the directories jac.toml's [test] lists
```

For the module above, where two tests are wrong on purpose:

```text
neojac test: 1 module with tests, 1 to build, on macos-aarch64
prices.jac:27:5: FAILED[rt AssertionError]: label pads cents: got 7.05
 27 |     assert got == "7.5", f"got {got}";
    |     ^
    in module 'prices.jac'
    Traceback (most recent call last):
      File "prices.jac", line 27, in test label pads cents
        assert got == "7.5", f"got {got}";
    output:
      label was 7.05

... the second failure, ERRORED[rt ValueError]: text that is no number: invalid literal for int() with base 10: 'x', with its traceback ...
prices.jac: 3 passed, 2 failed

3 passed, 2 failed; 0 of 1 module passed in 1.19s
FAILED prices.jac::label pads cents
FAILED prices.jac::text that is no number
```

Each failure is a diagnostic at the line the test stopped at: `FAILED[rt <exception>]` for an assertion that failed, `ERRORED[rt <exception>]` for another exception, then the test's name and the message, the source line, the traceback, and after `output:` what the test printed (shown only for a failure). Each module then has one line of totals, and the last lines name every failure as `FAILED <module>::<test>`. A module whose runner does not build is listed first with its diagnostics: resolve those as in `resolving-diagnostics`.

| Exit status | Meaning |
|---|---|
| 0 | Every test passed |
| 1 | A test failed, a runner did not build, or the command line was wrong |
| 5 | No tests found, or `-k` matched none |

`neojac test prices.jac -o runner` builds the runner without running it; `./runner -k label` runs it, for a debugger or another platform.

### 3. Format only the files you changed

```sh
neojac fmt prices.jac impl/prices.impl.jac
neojac fmt --check prices.jac      # lists files that would change, exit 1 if any
```

There are no layout options. `fmt` never changes meaning, keeps every comment, and refuses to write a file that does not parse (exit 1, with the diagnostics). Do not run it over a whole tree you did not change.

### 4. Satisfy the lint rules

**Never write `human_mode = true` under `[project]`.** If the project's `jac.toml` says it, switch the project over first:

1. Remove `human_mode`, and the `[check.lint]` `ignore` and `exclude` it allowed.
2. Run `neojac fmt --fix .` at the project's root.
3. Run `neojac check` on the project's programs, and fix by hand what it still reports.

From then on the project keeps the rules every project keeps. `human_mode` states that a person writes the project by hand, and only that person makes the statement. Never mark a project `kind = "fixtures"` to get out of the rules either: that is for a compiler's test programs.

Every project keeps the `"clean"` rules: the `"style"` rules, every body in an `impl` in `impl/`, and no comment and no docstring. `neojac check`, `build`, `run` and `test` all report them, so a comment stops a build. A program in no project (no `jac.toml` above it) is judged by none.

- What a comment would say goes in the commit message when it is why the code is as it is, and in the project's README or docs when it is what a reader must know; a docstring's content goes in the README or docs. Never write either in the source.
- Where the project's `jac.toml` says `notes = true` under `[fmt]`, what a comment or a docstring would say goes in the module's notes annex instead, `notes/<module>.md`, under a heading for the declaration it is about, in dotted form (`## Cart.add`, `## Cart.owner` for a field, `## test adds` for a test), with the module's own notes under its title line, `# <module>`.
- `[check.lint] select` only adds the two rules in no group: `select = ["no-print"]`. A name the project keeps already (`"style"`, `"clean"`) is E3058. Without `human_mode`, `[check.lint] ignore` and `exclude` are E3059.

```toml
[check.lint]
select = ["no-print"]
```

A finding names its rule in brackets:

```text
calc.jac:3:5: error[W3002]: a `has` after one with the same modifiers belongs in it: `has a: A, b: B;` [combine-has]
calc.jac:23:5: error[E3012]: print() is not allowed in this project [no-print]
```

`neojac fmt --fix <files>` rewrites every finding that has a fix (every rule of the `clean` group) and every old spelling the language rejects, then formats: it moves bodies into `impl/<module>.impl.jac`, and deletes comments and docstrings. Where `[fmt]` says `notes = true`, it moves what they said into `notes/<module>.md` under their declarations' headings, adding to what is there. `no-print` and `too-many-params` need you. `neojac fmt --fix --check <files>` lists what `--fix` would change, a notes annex among them, writing nothing.

## What a correct result looks like

```sh
neojac check prices.jac            # quiet, status 0: types, the module's tests, the lint rules
neojac test prices.jac             # "N passed", "1 of 1 module passed", status 0
neojac fmt --check prices.jac      # quiet, status 0
```

## Mistakes to expect

| Symptom | Cause | Fix |
|---|---|---|
| E0046 | A `test` inside an `obj` | Tests are top-level |
| E0013 | A `test` inside a function | Tests are top-level |
| Status 5, `no tests found` | No module under the paths has a test, or `-k` matched nothing | Name the module; check `[test] directories` |
| A test's print is missing | Output is shown only for a failing test | Assert on the value instead |
| The program's own work runs during `neojac test` | Its main code is in a plain `with entry` | Move it into `with entry:__main__` |
| W3050 `[strip-comments]`, W3051 `[strip-docstrings]` | A comment or a docstring in a project's source | Say what it said in the commit message or the docs, and run `neojac fmt --fix <files>`, which deletes it; where `[fmt]` says `notes = true`, the fix moves it into `notes/<module>.md` instead |
| E3057 | A name in `select` that is no rule | Use a rule name from `neojac docs toolchain/lint` |
| E3058 | `select` names a rule the project keeps already | Remove it |
| E3059 | `[check.lint]` has `ignore` or `exclude` | Remove the key and satisfy the rules; `human_mode` is not yours to write. Where the project says it, switch it over (step 4) |
| `internal error: neojac fmt would change the syntax tree` | A formatter defect; the file is left as it was | Report it with the file (`resolving-diagnostics`) |
| A test annex's errors not shown by `check main.jac` | Only the main module's tests are checked | `neojac check <module>.jac`, or `neojac test` |

## Where to look things up

| Question | Command |
|---|---|
| The test declaration | `neojac docs language/tests` |
| `neojac test`, `[test]` keys | `neojac docs toolchain/test`, `neojac docs test.directories` |
| `assert` | `neojac docs assert` |
| The layout `fmt` writes | `neojac docs toolchain/fmt` |
| Every lint rule and its fix, `human_mode`, the notes annex | `neojac docs toolchain/lint` |
| `[check.lint]` keys | `neojac docs check.lint.select` |
| `[fmt] notes` | `neojac docs fmt.notes` |
