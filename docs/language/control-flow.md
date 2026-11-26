---
description: The statements that choose and repeat: if/elif/else, while, for over an iterable, the for-while-with loop, forever, switch with fallthrough, break and continue, the else clause of a loop, defer, named loops and switches left or continued by break:name and continue:name, and the do block, an expression that runs statements and gives a value.
keywords: control flow, if, elif, else, while, for, for loop, while loop, forever, switch, default, fallthrough, break, continue, loop else, for else, defer, cleanup, scope exit, named loop, labelled break, label, break:name, continue:name, do block, block expression, statement expression
grammar: if_stmt, elif_stmt, else_stmt, while_stmt, for_stmt, forever_stmt, switch_stmt, switch_case, defer_stmt, do_block, do_stmts
---
# Control flow

`if` chooses a block by a condition, `switch` and `match` choose one by a value, and `while`, `for`
and `forever` repeat one. Every body is a block in braces; no `:` introduces it and none ends with
`;`. A condition is any expression, taken by its truth value (see
[Operators](operators.md#and-or-not)).

## `if`, `elif`, `else`

```ebnf
if_stmt ::= "comptime"? "if" expression block (elif_stmt | else_stmt)?

elif_stmt ::= "elif" expression block (elif_stmt | else_stmt)?

else_stmt ::= "else" block
```

The conditions are evaluated in order, and the block of the first one that is true runs. The
`else` block runs when none is. The condition needs no parentheses.

A test in a condition narrows a variable's type in the block it guards: after
`if v is not None`, `v` is no longer optional there. See [Types](types.md#unions).

```jac
def grade(n: int) -> str {
    if n >= 90 {
        return "A";
    } elif n >= 80 {
        return "B";
    } else {
        return "C";
    }
}

with entry {
    print(grade(95), grade(85), grade(10));
    pending: list[int] = [];
    if pending {
        print("work to do");
    } else {
        print("nothing pending");
    }
}
```

```output
A B C
nothing pending
```

`comptime if` is decided while the program compiles; see `neojac docs comptime`.

## `while`

```ebnf
while_stmt ::= "while" (":" NAME)? expression block else_stmt?
```

The condition is evaluated before each pass, and the loop ends when it is false.

```jac
with entry {
    data = [1, 2, 3];
    while data {
        print(data.pop(), end=" ");
    }
    print();
}
```

```output
3 2 1 
```

## `for`

```ebnf
for_stmt ::= "comptime"? "async"? "flow"? "for" (":" NAME)? atomic_chain ("=" expression "while" expression "with" atomic_chain assignment? | "in" expression) block else_stmt?
```

The rule has two loops: `for x in iterable` and the counting loop `for x = a while c with step`.

### `for x in iterable`

The body runs once for each item of the iterable, with the target bound to the item.

- Anything iterable may follow `in`: a list, tuple, set, string (each character), dict (each key,
  in insertion order), `range(...)`, a generator, or an object with `__iter__`. Anything else is
  an error (E1021).
- The target is a name, or a parenthesized tuple of targets that unpacks each item:
  `for (k, v) in d.items()`. The parentheses are required.
- The target is a local of the enclosing function. After the loop it holds the last item. It may
  be a local declared before the loop (`d: int = 0; for d in shape`); each item is then stored as
  that local's type, so the items of an `any` are checked as they arrive (`TypeError: expected
  int, found str`).
- A list that grows while it is iterated yields the new items too. A dict or a set that changes
  size while it is iterated raises `RuntimeError`.
- A closure made in the body captures that pass's own variable; see [Functions](functions.md).

```jac
with entry {
    for ch in "ab" {
        print(ch, end=" ");
    }
    for k in {"x": 1, "y": 2} {
        print(k, end=" ");
    }
    for (i, w) in enumerate(["p", "q"]) {
        print(f"{i}:{w}", end=" ");
    }
    for n in range(10, 0, -3) {
        print(n, end=" ");
    }
    print(n);
}
```

```output
a b x y 0:p 1:q 10 7 4 1 1
```

### `for x = start while cond with step`

The counting loop of C, written with words. `x = start` runs once; `cond` is evaluated before each
pass, and the loop ends when it is false; `step`, an assignment such as `i += 2`, runs after each
pass, including one that `continue` ends.

```jac
with entry {
    acc: list[int] = [];
    for i = 0 while i < 10 with i += 3 {
        acc.append(i);
    }
    print(acc, i);
    for j = 10 while j > 0 with j //= 2 {
        if j == 5 {
            continue;
        }
        print(j, end=" ");
    }
    print();
}
```

```output
[0, 3, 6, 9] 12
10 2 1 
```

`async for` iterates an asynchronous iterator ([Async](async.md)); `flow for` runs its passes in
parallel on several threads ([Parallel loops](flow-for.md), `neojac docs flow for`); `comptime for`
is unrolled while the program compiles (`neojac docs comptime`).

## `forever`

```ebnf
forever_stmt ::= "forever" (":" NAME)? block
```

`forever { ... }` repeats its block until a `break`, a `return` or an exception leaves it. It is
`while True` without the condition.

```jac
with entry {
    n = 0;
    forever {
        n += 1;
        if n % 2 == 0 {
            continue;
        }
        if n > 5 {
            break;
        }
        print(n);
    }
}
```

```output
1
3
5
```

## `break` and `continue`

`break` leaves the innermost loop (or `switch`, below). `continue` ends the current pass of the
innermost loop and starts the next; in a `for ... while ... with` loop the step runs first.
`break` outside a loop or a switch, and `continue` outside a loop, are errors (E0058).

```jac
with entry {
    for i in range(3) {
        for j in range(3) {
            if j == 1 {
                break;
            }
            print(i, j);
        }
    }
}
```

```output
0 0
1 0
2 0
```

`break` is refused in a `flow for` body (E1313), whose passes run at once; `continue` is allowed
there ([Parallel loops](flow-for.md)).

## Named loops and switches

```ebnf
ctrl_stmt ::= ("break" (":" NAME expression?)? | "continue" (":" NAME)? | "skip" | "disengage") ";"
```

A loop or a switch is named by a tag after its keyword, as `def:pub` tags a function:
`for:rows`, `while:w`, `forever:f`, `switch:pick`, and `async for:x` and
`for:i i = 0 while ... with ...` too. A `break` or `continue` that names it reaches it from any
depth of loops, switches and `do` blocks inside it:

- **`break:name;`** leaves the named statement. A loop's `else` does not run.
- **`continue:name;`** starts the named loop's next pass, its step first in a
  `for ... while ... with` loop. It names a loop, never a switch or a `do` block (E0118).
- **The name is known in the statement's body**: not in its condition, its iterable or its `else`,
  and not in a function or lambda defined in the body. A name no statement around it has is an
  error (E0058), as is a named statement inside another of the same name (E2104).
- **A plain `break` or `continue` is as before**: the innermost loop's (or switch's, for `break`).
- **Every rule about leaving holds**: a named `break` or `continue` leaves each `try` between it and
  its statement through its `finally`, nothing leaves a `defer` block early (E0180), and no
  `break` leaves a `flow for` body (E1313).

```jac
def found_at(grid: list[list[int]], want: int) -> tuple[int, int] {
    at = (-1, -1);
    for:rows (i, row) in enumerate(grid) {
        for (j, cell) in enumerate(row) {
            if cell < 0 {
                continue:rows;
            }
            if cell == want {
                at = (i, j);
                break:rows;
            }
        }
    }
    return at;
}

with entry {
    print(found_at([[1, 2], [-1, 7], [3, 7]], 7));
    n = 0;
    while:outer n < 10 {
        n += 1;
        switch:pick n % 3 {
            case 0:
                continue:outer;
            case 1:
                break:pick;
            default:
                if n > 6 {
                    break:outer;
                }
        }
        print(n, end=" ");
    }
    print();
}
```

```output
(2, 1)
1 2 4 5 7 
```

A name on a `comptime for`, which is no loop as the program runs, is refused (E5090).

## The `else` of a loop

A `while` or `for` loop may end with an `else` block. It runs when the loop ends because its
condition is false or its items are exhausted, and not when a `break` ends it. A loop that runs no
pass runs its `else`.

```jac
def find(xs: list[int], target: int) -> str {
    for x in xs {
        if x == target {
            print("found", x);
            break;
        }
    } else {
        print("no", target);
    }
    return "done";
}

with entry {
    find([1, 2, 3], 2);
    find([1, 2, 3], 9);
    find([], 1);
}
```

```output
found 2
no 9
no 1
```

## `switch`

```ebnf
switch_stmt ::= "switch" (":" NAME)? expression "{" switch_case* "}"

switch_case ::= ("case" pattern | "default") ":" stmt*
```

`switch` evaluates its subject once and runs the statements from the first `case` whose pattern
matches it. It works as C's does:

- **Execution falls through.** After the matching case's statements, those of the next case run
  too, and the next, until a `break` or the end of the switch. End a case with `break` to stop.
- **`default`** is where execution starts when no case matches, wherever it is written, and it
  falls through like any case. A switch has at most one (E0152). With no match and no default,
  nothing runs.
- **A case takes a pattern**, as `match` does: literals, `1 | 2`, `Color.RED`, `[a, b]`,
  `Point(x=0)`. A bare name is a capture pattern, which matches every value and binds it, not a
  comparison with that variable. `case _:` is the wildcard, and binds nothing: in the case's
  statements, as everywhere outside a pattern, `_` is an ordinary variable, so after `_ = 2;` a
  `print(_)` in any case prints `2`. Patterns are in [Pattern matching](pattern-matching.md). A
  case takes no `if` guard.
- `break` leaves the switch. `continue` in a switch inside a loop goes on to the loop's next pass.
- The case bodies are statements after the `:`, not blocks.

```jac
def switched(x: int) -> list[str] {
    out: list[str] = [];
    switch x {
        case 1:
            out.append("one");
        case 2:
            out.append("two");
            break;
        case 3 | 4:
            out.append("three or four");
            break;
        default:
            out.append("default");
    }
    return out;
}

with entry {
    for x in [1, 2, 3, 5] {
        print(x, switched(x));
    }
}
```

```output
1 ['one', 'two']
2 ['two']
3 ['three or four']
5 ['default']
```

`match` is the form without fallthrough, with guards; use it unless the fallthrough is wanted.

## `defer`

```ebnf
defer_stmt ::= "defer" block (do_stmts | stmts)
```

`defer { ... }` runs its block when the block it is written in is left: at its end, at a
`return`, at a `break` or `continue` that leaves it, and as an exception passes out of it. Of
several, the last one written runs first. It is the cleanup that a `try` with a `finally` around
the rest of the block would be, written beside what it cleans up.

```jac
def steps(log: list[str], fail: bool) -> int {
    defer {
        log.append("first");
    }
    log.append("body");
    defer {
        log.append("second");
    }
    if fail {
        raise ValueError("failed");
    }
    return len(log);
}

with entry {
    log: list[str] = [];
    print(steps(log, False), log);
    again: list[str] = [];
    try {
        steps(again, True);
    } except ValueError as e {
        print(e, again);
    }
}
```

```output
1 ['body', 'second', 'first']
failed ['body', 'second', 'first']
```

- **A `return`'s value is computed before the deferred blocks run**: `steps` returns 1, the
  length of the log before they append to it.
- **A deferred block that is never reached does not run**: one written after a `return` is not
  registered.
- **Nothing in a deferred block leaves it early** (E0180): no `return`, `skip` or `disengage`, and
  no `break` or `continue` of a loop outside it. A loop inside it, and a function it defines,
  are their own.
- **`defer` is a word only where a statement starts with `defer {`**: a variable or a module named
  `defer` is a name as before.

## `do` blocks

```ebnf
do_block ::= "do" (":" NAME)? "{" do_stmts "}"

do_stmts ::= stmt* expression?
```

`do { ... }` is an expression that runs statements and gives a value. It runs its statements where
the expression is evaluated, in order, and its value is its final expression, the one with no `;`
before the closing brace; with none, its value is `None`. A `do` block named by a tag, `do:found`,
is also left by `break:found value;`, which gives it `value`.

```jac
def classify(n: int) -> str {
    size = do { half = n // 2; "big" if half > 10 else "small" };
    return f"{size} ({half})";
}

def first_even(xs: list[int]) -> int {
    return do:found {
        for x in xs {
            if x % 2 == 0 {
                break:found x;
            }
        }
        -1
    };
}

with entry {
    print(classify(30), classify(4));
    print(first_even([3, 5, 8, 10]), first_even([1]));
    log: list[str] = [];
    n = do {
        defer {
            log.append("left");
        }
        log.append("body");
        len(log)
    };
    print(n, log);
    total = 0;
    for v in [1, 2, 3, 4] {
        part = do {
            if v == 2 {
                continue;
            }
            if v == 4 {
                break;
            }
            v * 10
        };
        total += part;
    }
    print(total);
}
```

```output
big (15) small (2)
8 -1
1 ['body', 'left']
40
```

- **It is not a function.** `return`, `yield`, `await`, `raise`, and a plain `break` or `continue`,
  mean in it what they mean in the block around it: they act on the function and the loops around
  it, as the `continue` and `break` above act on the `for`. Its variables are the function's, as
  any block's are (`half` above). A `defer` in it runs as it is left, after its value is computed.
- **A plain `break` or `continue` never stops at a `do` block.** It is left early only by its name.
- **Its type** is the type of its final expression joined with that of every `break:name value`
  that leaves it, as the two branches of `a if c else b` are joined. It gives a value on every way
  it is left, or on none: one whose end can be reached, or that a `break:name;` leaves, while
  another way gives a value, is an error (E1171). A `break` gives a value only to a `do` block
  (E0119).
- **Where a statement starts with a `do` block, the block is the whole statement**, and it takes no
  `;`, as `if` takes none. To go on with an expression from it, parenthesize it.
- **`do` is a word only where an expression starts with `do {` or `do:name {`**: elsewhere it is an
  ordinary name.
- **Some places hold no block.** A `do` block among a generator expression's items leaves none of
  the loops around the expression, whose items are made apart from them (E0058), and one in a
  parameter's or a field's default is refused (E5090).
- **Where ownership is tracked**, a `do` block that uses an `own` local which the rest of its
  statement moves is refused (E5090): `f(take(x), do { x.n })`.

```jac
def scaled(n: int) -> float {
    return do:k {
        if n > 5 {
            break:k n * 1.5;
        }
        n
    };
}

with entry {
    print(scaled(8), scaled(2));
    x = (do { "a" + "b" }).upper();
    print(x);
}
```

```output
12.0 2.0
AB
```

On a JS host and in a cpython space, a `do` block runs before its statement where it is the
statement's first value: a statement of its own, the whole value of an assignment, a return or a
global, or a statement's condition, iterable or subject. On a JS host one elsewhere in an
expression runs as a function called in place, and is refused (E5090) when its statements return,
yield, await, or leave a statement around it; in a cpython space one elsewhere is refused (E5090).

## What is rejected

| Code | Condition |
|---|---|
| E0001 | A body that is not a block: `if c: x;` or `if c x;` |
| E0032 | An `elif` or `else` that follows no `if` |
| E0058 | `break` outside a loop or a switch; `continue` outside a loop; a `break:name` or `continue:name` that no statement around it is named |
| E0118 | `continue:name` of a switch or a `do` block |
| E0119 | `break:name value` of a loop or a switch |
| E0152 | A second `default` in a switch |
| E1021 | `for x in v` where `v` cannot be iterated |
| E0180 | A `return`, `skip`, `disengage`, `break` or `continue` that would leave a `defer` block early |
| E1171 | A `do` block that gives a value on some ways it is left and none on another |
| E2104 | A named statement inside another of the same name |
| W3024 | An `elif` whose condition repeats an earlier one of its chain, so its block never runs |
| W3025 | An `if` whose two blocks are the same |

```jac
# expect: E0058, E1021
def scan(n: int) {
    break;
    for x in n {
        print(x);
    }
}
```

```jac
# expect: E0058, E0118, E0119, E1171, E2104
def named(xs: list[int]) -> int {
    for:rows x in xs {
        for:rows y in xs {
            continue:cols;
        }
    }
    switch:pick len(xs) {
        case 1:
            continue:pick;
    }
    for:each x in xs {
        break:each x;
    }
    return do:d {
        if len(xs) > 1 {
            break:d 1;
        }
    };
}
```

```jac
# expect: E0152
def pick(n: int) {
    switch n {
        default:
            print("a");
        default:
            print("b");
    }
}
```

```jac
# expect: W3024, W3025
def sign(x: int) -> int {
    y = 0;
    if x > 0 {
        y = 1;
    } elif x > 0 {
        y = 2;
    }
    if x < 0 {
        y = -1;
    } else {
        y = -1;
    }
    return y;
}
```

The lint rules a project may select add more checks on these statements, such as an `else` after a
block that returns (W3021) and an `else` holding only an `if` (W3022); see
[Lint](../toolchain/lint.md).

## Differences from Python

- Blocks are braces; there is no `:` and no single-line body.
- `for k, v in items` is written `for (k, v) in items`.
- `forever`, `switch` and `for ... while ... with` have no Python counterpart. `switch` falls
  through; `match` does not.
- A closure made in a `for` body captures that pass's variable, where Python's closures all see the
  variable's last value.
