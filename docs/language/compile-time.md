---
description: The comptime keyword in every position it may appear (globals, locals, functions, if, for, assert, parameters, members, imports) and what each form does as the program compiles.
keywords: comptime, compile-time, compile time, comptime def, comptime if, comptime for, comptime assert, comptime global, comptime local, unrolled loop
grammar: comptime_element, comptime_global, comptime_stmt, comptime_decls, decls_block, members_if, members_block
---
# Compile-time evaluation

`comptime` marks code the compiler evaluates while it compiles the program.
A compile-time value is known before the program runs: it can size a type,
pick which branch is compiled, unroll a loop, or fail the build with an
assertion. Nothing marked `comptime` costs anything when the program runs.

```jac
comptime def fib(n: int) -> int {
    a = 0;
    b = 1;
    for _ in range(n) {
        (a, b) = (b, a + b);
    }
    return a;
}

comptime FIB20: int = fib(20);
comptime TAGS: list[str] = ["alpha", "beta", "gamma"];
comptime VERBOSE: bool = False;

comptime assert FIB20 == 6765, "fib(20) is 6765";

def mode -> str {
    comptime if VERBOSE {
        return "verbose";
    } else {
        return "quiet";
    }
}

def total_len -> int {
    total = 0;
    comptime for tag in TAGS {
        total += len(tag);
    }
    return total;
}

with entry {
    print(FIB20, mode(), total_len());
}
```

```output
6765 quiet 14
```

`mode` compiles to `return "quiet";` and `total_len` to three additions:
the `comptime if` kept one branch and the `comptime for` was unrolled.

## Where comptime appears

At module level, and inside an archetype's body for a global:

```ebnf
comptime_element ::=
    comptime_decls
    | ability
    | import_stmt
    | assert_stmt
    | comptime_global

comptime_global ::= "comptime" access_tag global_var ("," global_var)* ";"
```

As a statement in a function or in module code:

```ebnf
comptime_stmt ::=
    if_stmt
    | for_stmt
    | assert_stmt
    | import_stmt
    | ability
    | "comptime" NAME assignment
```

In each alternative but the last, `comptime` is the optional first word of
the production named (`if_stmt ::= "comptime"? "if" ...`).

| Form | Where | Meaning |
|---|---|---|
| `comptime NAME: T = expr;` | module level, archetype body | A compile-time global (in an archetype, a compile-time member). |
| `comptime name: T = expr;` | a statement | A compile-time local. |
| `comptime def f(...) { ... }` | module level | A function the compiler runs. |
| `comptime if c { } elif d { } else { }` | a statement | Compiles only the branch its condition picks. |
| `comptime for x in xs { }` | a statement | Compiles its body once for each item. |
| `comptime assert c, "message";` | module level, a statement | Fails the build when `c` is false. |
| `comptime n: int` in a parameter list | a function's parameters | A parameter whose argument is a compile-time value. |
| `[comptime N: int]` | a declaration's brackets | A compile-time value parameter. See [Compile-time parameters](comptime-parameters.md). |
| `comptime import ...;` | module level | An import, see below. |

What a compile-time expression may hold and compute is on
[Compile-time values](compile-time-values.md).

## Globals and locals

`comptime NAME = expr;` evaluates `expr` as the program compiles. The type
is optional (`comptime STRIDE: int = stride(4);`), several may be declared
in one statement (`comptime A = 1, B = A + 1;`), and an access tag goes
after the word (`comptime:pub LIMIT = 8;`).

A compile-time global or local can be used

- in other compile-time code: a later `comptime` global, a `comptime if`
  condition, a `comptime for`, a `comptime assert`, a `comptime def`'s body;
- in a type's arguments: `tensor[f32, LAYOUT.rows, 2]`, `Vec[N + 1]`;
- where code runs, where it is the value's literal.

An initializer that reads something known only as the program runs is an
error (E0033): a `glob`, a parameter, a local. A compile-time name is fixed:
code that runs cannot assign it (E2197), by `=`, an augmented assignment, a
walrus or a loop's target.

```jac
comptime LIMITS: dict[str, int] = {"low": 1, "high": 9};

def spread(n: int) -> str {
    comptime cutoff: int = LIMITS["high"] - LIMITS["low"];
    return "wide" if n > cutoff else "narrow";
}

with entry {
    print(spread(9), spread(3), LIMITS);
}
```

```output
wide narrow {'low': 1, 'high': 9}
```

## comptime def

A `comptime def` is a function the compiler interprets. It is called from
compile-time code, or from ordinary code with arguments that are all known
at compile time; the call is then replaced by its result. Calling one with
a value known only as the program runs is an error (E0033). A comptime
function is not part of the compiled program.

A `comptime def` is declared at module level. One written inside a
function, or as a method, is not supported (E5090).

Its body is ordinary Jac restricted to what the compiler evaluates:
assignments, `if`, `while`, `for`, `break`, `continue`, `return` and calls
of other comptime functions, itself included. See
[Compile-time values](compile-time-values.md) for the expressions.

```jac
comptime def stride(n: int) -> int {
    return n * 2 + 1;
}

comptime def fact(n: int) -> int {
    if n <= 1 {
        return 1;
    }
    return n * fact(n - 1);
}

comptime STRIDE: int = stride(4);

with entry {
    print(STRIDE, stride(10), fact(20));
}
```

```output
9 21 2432902008176640000
```

An error raised while a `comptime def` runs (a failed `comptime assert`,
a value it cannot evaluate) is reported at the call that ran it, in the
compile-time value or the [decorator](decorators.md) that called it. The report carries the lines of the comptime functions the call passed
through as its frames, outermost first, as a traceback does. In
`--diagnostics json` they are the record's `frames`.

```jac
# expect: E0109
comptime def positive(n: int) -> int {
    comptime assert n > 0, "n is positive";
    return n;
}

comptime def doubled(n: int) -> int {
    return positive(n) * 2;
}

comptime NEG = doubled(-1);
```

```text
main.jac:11:16: error[E0109]: comptime assertion failed: n is positive
 11 | comptime NEG = doubled(-1);
    |                ^^^^^^^^^^^
    Traceback (most recent call last):
      File "main.jac", line 8, in doubled
        return positive(n) * 2;
               ^^^^^^^^^^^
      File "main.jac", line 3, in positive
        comptime assert n > 0, "n is positive";
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

## comptime if

`comptime if` evaluates its condition as the program compiles and compiles
only the branch it picks. The other branches are parsed and nothing more:
they may name things that do not exist, or that this target does not have.
An `elif` and `else` of a `comptime if` are compile-time too.

```jac
comptime WIDTH = 64;

def mask -> int {
    comptime if WIDTH == 64 {
        return -1;
    } elif WIDTH == 32 {
        return defined_nowhere(WIDTH);
    } else {
        return "not" + 1;
    }
}

with entry {
    print(mask());
}
```

```output
-1
```

### Among declarations and members

```ebnf
comptime_decls ::= "comptime" "if" expression decls_block ("elif" expression decls_block)* ("else" decls_block)?

decls_block ::= "{" element* "}"

members_if ::= "comptime"? "if" expression members_block ("elif" expression members_block)* ("else" members_block)?

members_block ::= "{" archetype_member* "}"
```

A `comptime if` also stands among a module's declarations, and among an
archetype's members, where it picks the declarations a target has. A branch
holds anything its place may: at module level imports, functions, classes,
`glob`s, `with entry` blocks and nested `comptime if`s; in an archetype
fields, methods, nested archetypes and nested `comptime if`s.

An import in a branch is the target's alone: a target whose branch does not import a module does
not load it. Under an `archwire.jac` an import of a project module stays in its branch, and the
wire into the module admits it, as a wire admits [an import in a code
body](modules.md#an-import-in-a-code-body): `plat.linux ++> main { name }` and
`plat.darwin ++> main { name }` for a module whose branches import `name` from each. A module
that only another target's branch imports is not loaded for this target, even where a space's
pattern holds it (`plat.*`) and the wire names it: it is not checked or built there, so it may
use what only its own target has.

That holds whatever the import names: a Jac module, a Python file of the project, a C module, or
an `include`'s names. In a `cpython` space a branch not taken makes no import as the module
starts, so `import from kit.plat_py { WHERE }` under `comptime if target().os == "plan9"`, of a
Python file that raises `ImportError` anywhere else, is never run on macOS. An item the taken
branch imports too is this target's. The wire is still judged for every target: an item it names
that no branch of any target uses is E1146, and one only another target's branch uses is no
error.

```jac
import from jaclang.comptime { target }

comptime if target().os == "windows" {
    import from ntpath { join }

    def sep -> str {
        return "\\";
    }
} else {
    import from posixpath { join }

    def sep -> str {
        return "/";
    }
}

obj Probe {
    has name: str = "probe";

    comptime if target().os in ["linux", "darwin"] {
        has posix: bool = True;

        def kind -> str {
            return "posix";
        }
    } else {
        has posix: bool = False;

        def kind -> str {
            return "other";
        }
    }
}

with entry {
    print(sep(), join("a", "b"), Probe().kind(), Probe().posix);
}
```

```output
/ a/b posix True
```

The output is a Linux or macOS build's.

- **It is decided as the module is read**, before any name is bound, so its
  condition tests what the build targets and nothing of the program:
  `target()`'s fields (`os`, `arch`, `device`, `cpu`, `vector_bits`, from
  [Compile-time values](compile-time-values.md#target)), literals (a bool, a
  str, an int, a list or tuple of them), `==`, `!=`, `<`, `<=`, `>`, `>=`,
  `in`, `not in`, `and`, `or` and `not`, and `hasattr(M, "name")` of a
  module `M` this module imports ([below](#hasattr-of-a-module)). `target` is
  imported from `jaclang.comptime` at the module's top, under any name. A
  condition naming anything else (a `glob`, a compile-time global, another
  call) is E2290, and one that is not a bool is E0108.
- **Only the branch taken is declared.** The others are parsed and nothing
  more: not bound, not checked, their imports not loaded, and no wire is
  needed for them, so a branch may name a module or a function no other
  target has.
- **A name each branch declares is one declaration** on every target. A name
  only one branch declares exists only on the targets that take it, and a use
  of it on another is an unknown name there.
- **Every host takes the branch the build's target picks**, a `cpython` or a
  JavaScript space's as a native program's.

This is the form for a few declarations that differ by target; a module that
differs throughout may instead have a file per target (variants, in
[Modules](modules.md#how-a-module-is-found)).

Without `comptime`, an `if` among an archetype's members tests what only the
running program knows. That is a class Python makes as its statement runs,
which a `cpython` space has
([Classes and decorators in a cpython space](../interop/python-classes.md#classes-python-makes)); in any
other space it is E5175.

### hasattr of a module

`hasattr(M, "name")`, where `M` is a module of the program, is a compile-time `bool`: whether
`M`, compiled for this target, binds `name`: its declarations (those of the `comptime if`
branches its target takes), its imports and the names its wires give it, and `__name__`,
`__file__` and `__doc__`, which every module has. A function made in `M`'s
`with entry` code is no attribute of it, and is not counted. The value is folded wherever it
stands, so a `comptime if` tests it in a body and among declarations, and the branch not taken may
use what `M` lacks on this target: this is how a module asks what a module that differs by target
gives, rather than repeating the other module's test of the target.

```jac
import os;

comptime if hasattr(os, "getcwd") {
    def where -> str {
        return "getcwd";
    }
} else {
    def where -> str {
        return os.cwd_by_another_name();
    }
}

def described -> str {
    comptime if hasattr(os, "nothing_here") {
        return os.nothing_here();
    } else {
        return "no nothing_here";
    }
}

with entry {
    print(where(), described(), hasattr(os, "getcwd"));
}
```

```output
getcwd no nothing_here True
```

- **Among declarations it is decided when the module is linked**, after `M` is loaded, where
  a test of the target alone is decided as the module is read. Two modules whose `comptime if`s
  among declarations each ask `hasattr` of the other wait on each other, and that is E2301.
- **In a cpython space, where `M` is a Python module that stays**, `hasattr` is Python's own,
  asked when the program runs.
- **In a cpython space, a module the target chooses is read as Python reads it.** Where each
  branch of a `comptime if` imports a module under one name (`import plat.osx as plat;` in one,
  `import plat.linux as plat;` in another), `plat.x` of a name the chosen module lacks is
  Python's read of the module object: `any`, an `AttributeError` where it runs, as Python's own
  program would raise. A module bound by one name on every target keeps E1145 for a name it
  lacks, and on every other host so does this one.
- `hasattr` of a value that is not a module is Python's as everywhere: asked when the program
  runs.

## comptime for

`comptime for x in xs` compiles its body once for each item of a
compile-time collection, with `x` a compile-time value in each copy. `xs`
is a list, a tuple, a set, a dict (its keys), a str (its characters) or
`range(...)` of compile-time ints. The target is a name or a tuple of
names.

The body is ordinary code that runs when the program does. It may nest
`comptime if` and `comptime for`.

```jac
comptime TAGS: list[str] = ["alpha", "beta", "gamma"];

def pick_long -> list[str] {
    out: list[str] = [];
    comptime for tag in TAGS {
        comptime if len(tag) > 4 {
            out.append(tag);
        }
    }
    comptime for (i, mark) in [(1, "x"), (2, "y")] {
        out.append(mark * i);
    }
    return out;
}

def repeat(comptime n: int, msg: str) -> str {
    out = "";
    comptime for _ in range(n) {
        out += msg;
    }
    return out;
}

with entry {
    print(pick_long(), repeat(3, "ab"));
}
```

```output
['alpha', 'gamma', 'x', 'yy'] ababab
```

## comptime assert

`comptime assert cond, "message";` fails the build when `cond` is false
(E0109, with the message when one is given). The condition is a
compile-time bool. It stands at module level or as a statement. One that
fails in a `comptime def`'s body stops the function there: the call has no
value, and nothing more is reported of what the value was for.

A docstring before a module-level `comptime assert` documents nothing and
is warned of (W0060), which fails nothing.

## comptime parameters

A parameter marked `comptime` in a function's parameter list takes a
compile-time value: an int, a bool, a str, a float or a struct of plain
data. The function is compiled once for each value it is called with, and
in each copy the parameter is that value: usable in `comptime if`,
`comptime for` and types.

```jac
def scaled(comptime k: int, x: int) -> int {
    comptime if k == 1 {
        return x;
    }
    return x * k;
}

def scaled_f(comptime k: float, x: float) -> float {
    return x * k;
}

with entry {
    print(scaled(5, 4), scaled(1, 4), scaled_f(2.5, 2.0));
}
```

```output
20 4 5.0
```

The argument must be known at compile time (E0033 otherwise). A function
may have a `comptime` parameter beside type parameters in brackets
(`def scaled_all[T](comptime k: int, xs: list[T]) -> list[T]`).

## Compile-time members

`comptime NAME: T = expr;` in an archetype's body is a compile-time member,
read as `Archetype.NAME`. An interface may require one of the classes that
conform to it; see [Interfaces](interfaces.md).

```jac
obj Grid {
    comptime ROWS: int = 3;
    has cells: list[int] = [];

    def size -> int {
        comptime twice: int = Grid.ROWS * 2;
        return twice;
    }
}

with entry {
    print(Grid.ROWS, Grid().size());
}
```

```output
3 6
```

## comptime import

The grammar takes `comptime` before a module-level import
(`comptime import from jaclang.comptime { target }`). The module is
imported as by a plain import: every imported module's compile-time
globals and functions are available to compile-time code already, so the
word is not needed. An import inside a function is not supported, with or
without it (E5090).

## What is rejected

```jac
# expect: E0108 x2, E0033 x2, E0109 x2, E1001, E1030, E1126, E2197 x2, E5090
glob runtime_n: int = 3;

enum Mode {
    FAST,
    SAFE,
}

comptime def half(n: int) -> int {
    return n // 2;
}

comptime def positive(n: int) -> int {
    comptime assert n > 0, "n is positive";
    return n;
}

comptime NEGATIVE = positive(-1);

comptime HALF: float = 1.0 / 0;
comptime SQUARES: list[int] = [i * i for i in [1, 2, 3]];
comptime R: int = runtime_n + 1;
comptime COUNT: int = 2.5;
comptime M = 2 ** 100;
comptime PICKED = Mode.TURBO;
comptime assert half(4) == 3, "half is wrong";

def f(n: int) -> int {
    return half(n);
}

def g -> int {
    comptime step: int = 2;
    step += 1;
    M = 0;
    return step;
}

def h -> int {
    comptime def twice(n: int) -> int {
        return n * 2;
    }
    comptime assert twice(4) == 8;
    return twice(21);
}
```

| Code | Meaning |
|---|---|
| E0108 | The compiler cannot evaluate this at compile time. The message says why: a division by zero, a construct the evaluator does not run (a comprehension, an f-string), a value that is no compile-time value. |
| E0033 | Something must be known at compile time and is not: a run-time name in a compile-time expression, a run-time argument to a `comptime` parameter or a comptime function. |
| E0109 | A `comptime assert` failed. |
| E1001 | A compile-time global's value is not of its declared type. |
| E1030 | A member its owner does not have, as anywhere else: an enum member that does not exist. |
| E1126 | A compile-time int does not fit the type it is read as (a global is an `int`). |
| E2197 | Code that runs assigns a compile-time name. |
| E5090 | A `comptime def` inside a function, or as a method. |
| E2290 | A `comptime if` among declarations whose condition names something other than `target()`'s fields and literals. |
| E5175 | An `if` among an archetype's members, outside a `cpython` space. |
| W0060 | A docstring stands before a `comptime assert`: a warning, which fails nothing. |

## Differences from Python and the reference design

- Python has no compile time: a module-level constant is computed when the
  module is imported. Here a `comptime` value is computed by the compiler,
  and an error in it stops the build.
- A `comptime if` is not an `if` on a constant. The branches it does not
  pick are never checked, so they may use names and types that do not
  exist on this target. Among declarations it stands where Python writes
  `if sys.platform == "win32":` at module level or in a class body.
- A compile-time int is exact, of any size, as Python's is, although a
  run-time `int` is 64 bits. See
  [Compile-time values](compile-time-values.md).
