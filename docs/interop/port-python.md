---
description: What neojac port makes of each Python construct - the Jac it becomes, and what it refuses.
keywords: port python, porting Python, Python to Jac
---
# Porting Python

`neojac port` translates a Python source file into a Jac module that behaves as the file does,
or refuses it ([port](../toolchain/port.md)). This page is the mapping: each Python construct
port translates and the Jac it becomes. It is printed from the table the translation itself
reads (`neojac port --mapping python`).

Every name is `any`, which is what a name in Python is: its operations are resolved as the
program runs, and raise `TypeError` where Python does. An annotation is carried as the Python
object the source names (`skip: builtins.int = 0`, a class by its name; on a cpython space a
variable of the module by its name, and a string as the string), which `check` reads as
`any` and a cpython space hands Python as written. In a module that postpones its annotations
(`from __future__ import annotations`), each annotation is the source's text, as written
(`int`, `Decimal | None`), which `check` reads as `any` and Python keeps as that text. The port is a program of a cpython space
(outside a project, it is checked on that host), where an int is Python's.
Scaffolding keeps Python's meaning where Jac's would differ: a name the module's code binds is a
`glob` the code assigns, a local a nested function takes is declared at the top of its
function, each unbound until it is bound, as Python's, and a default that is not a constant is
held in a variable made where the `def` runs, which a cpython space hands Python as the
default's value (`inspect.signature` shows it).

| Python | Jac |
|---|---|
| A module's docstring | The module's docstring |
| `import m`, `import m as n`; in a function; in the module's code (under a `try`, a run-time `if`); under `if TYPE_CHECKING:` | `import m;`, `import m as n;`; in a function, the same import in its body, which binds its names there; in the module's code, `import m as m_; m = m_;`, which binds the module's `glob m` where it runs; under `if TYPE_CHECKING:` at a module's top, nothing (its `else` is the module's code). In a cpython space the names a module's imports and wires bind are its attributes, as Python's module holds them (`dir(m)`, `m.name`) |
| `from m import a, b as c`, `from .m import a`, `from .. import a`; `from m import *` of a module of the project; a re-export: `from .m import a as a`, or a name `__all__` lists | `import from m { a, b as c }`, `import from .m { a }`, `import from .. { a }`; `import from m { ... }` of the names `m`'s `__all__` lists, or else of every name `m` binds that does not begin with `_`; a re-export, `include from .m { a }` (in a project, an `include` wire) |
| `x = v` at module level: of a literal before any module code, or bound by the module's code; `x: T` declared only under `if TYPE_CHECKING:` | `glob x: any = v;`; or `glob x: any;`, unbound until `x = v;` in the module's code binds it (a read before is Python's NameError); a name only declared under `if TYPE_CHECKING:` is `glob x: any;`, which the module's code makes (through `globals()`, say) |
| Any other statement at module level | A statement of a `with entry { }`, one for each stretch of the module's code between its defs and classes, where the stretch stands: in a cpython space a module's declarations are made in file order, so a def below code that raises is not made again by a reload |
| `if __name__ == "__main__":` at module level; an `if` whose every test is the platform (`sys.platform == "win32"`, `sys.platform.startswith("linux")`, `os.name == "nt"`, a module's name bound once to one, whether the module is Python or the Jac an earlier port made of it, `not`, `and`, `or`), at module level, in a class body or in code; an `if` whose test joins such a platform test to run-time tests, the platform test guarding the operands after it (`if not (WINDOWS and err.winerror == 6):`, `if POSIX or os.getuid() == 0:`) | `with entry:__main__ { }`; `comptime if target().os == "windows" { }` (`target` from `jaclang.comptime`): at module level, among the declarations for its defs, classes and imports and in the module's code for its statements; in a class body, among the members; a name a def binds under one test and a value under another, a `glob` of the branches that bind the value. A class body's `if` on anything else is the same `if` among the members, of a class Python makes where its statement runs (a cpython space); a class attribute a list display gives, grown only by `x += [...]` under `if`s that do not name it, is one value, `operator.iadd` of the list and each arm's additions in Python's order. A test that joins a platform test to run-time ones is a `comptime if` on the platform test, each arm's `if` the run-time test as the platform test leaves it there (`if not (WINDOWS and err.winerror == 6): raise` is `comptime if target().os == "windows" { if not (err.winerror == 6) { raise; } } else { raise; }`); a platform test after a run-time operand (`x and WINDOWS`) stays in the run-time test, so nothing Python evaluates is dropped |
| `def f(a, b=1):` with a docstring, at module level or in a function; a `def` in the module's code (under an `if`, in a loop or a `try`); `@d` on a `def` at module level, in a function or in a class, with `@staticmethod` or `@classmethod` among them; `@property` alone, and its `@f.setter` | The docstring, then `def f(a, b=1) -> any { }` (a parameter the source leaves unannotated is written so); a local a nested function takes is declared at the top of the function; in the module's code, `def f(...) { }` where the `def` runs, which binds the module's `glob f`; `@d` on the `def`, which a cpython space makes where it stands with its decorators applied (a `static def` or a `class def`, with `@builtins.staticmethod` or `@builtins.classmethod` where the source has it under another decorator; `@builtins.property` under another decorator); a field with a `getter` and a `setter`, which a cpython space gives Python as `@property def x(self) -> T` with the field's doc and `@x.setter` |
| `def f(a, /, b, *args, c, d=1, **kw):` | `def f(a, /, b, *args_, c, d=1, **kw) -> any { args: any = tuple(args_); }`: `*args` is a tuple; each parameter is `a: any` in a native program's module |
| `class C(B):` with `__init__` binding `self.x`; a method whose first parameter has another name, `def bump(me, k): me.n += k` | `obj C(B) { has x: any; def init(...) { } }`, with an `__eq__` and a `__hash__` of identity when the class defines no `__eq__`, and a `__repr__` that is Python's `super().__repr__()` when it defines none. A class Python makes, in a cpython space, where its statement runs, is written `class C(...) { }`, its annotated names `has` fields and its plain assignments `static has`: one with a base Python makes (an import's class, a builtin class as `builtins.str`, a call such as `namedtuple(...)`, a glob), with keywords, with an annotation without a value, or a method binding an attribute `__init__` does not always bind (`(builtins.object)`), decorated (`@dataclass`, or a function of the module or of an import), with an `if` in its body on what only the running program knows, or in a function or under the module code's `if`; its `__new__(cls, ...)` is a `static def __new__`, its `super()` and `Base.__init__(self, ...)` Python's `super`. A method named `init` or `postinit` is a method of that name, `` def `init ``, called as `` x.`init() ``. A method's first parameter is its object whatever the source calls it: `self` in the Jac, `def bump(k) { self.n += k; }`, and a variable of the body named `self` another name (`self_`) |
| `x = v`, `x: T = v` (a first binding) | `x: any = v;` |
| `x += v`, and the other augmented assignments | `x += v;` |
| `a, b = v`, `(a, b)`, `return a, b`; `first, *rest = v`, `a, (b, c) = v`; `a = b = v` | `(a, b) = v as any;` (Jac unpacks only a tuple or a list it knows, and an `any` holding any iterable, as Python unpacks it), `(a, b)`, `return (a, b);`; a starred or nested target takes the items of `list(v)` one at a time, raising Python's `ValueError` when they do not fit; `v` is held in a variable and assigned to each target in turn |
| `if`/`elif`/`else`, `while`, a loop's `else` | The same, with braces |
| `for x in xs:`, `for k, v in d.items():` | `for x in xs { }`, `for (k, v) in d.items() { }` |
| `return`, `break`, `continue`, `assert c`, `assert c, m` | The same, each with its `;`; `assert c, m` whose message is no str literal or f-string is `if not c { raise AssertionError(m); }`, as Jac's `assert` takes a str |
| `pass` | Nothing: an empty block is `{}` |
| `raise E(...)`, `raise E`, `raise E(...) from c`, `raise` | `raise E(...);`, `raise E();` for a class, `raise E(...) from c;`, `raise;` |
| `with a() as x, b():`, a tuple of targets after `as` | `with a() as x, b() { }`, each name bound by `as` declared before it |
| `try:` with `except E as e:`, `except (A, B):`, `except:`, `else:` and `finally:` | `try { } except E as e { } except (A, B) { } except BaseException { } else { } finally { }` |
| `global x`, `nonlocal x` | Nothing: assigning a global's name, or an enclosing function's local, assigns it |
| `lambda x, y=1: x + y` | `lambda (x: any, y: any = 1) -> any { x + y }` |
| `f(*xs, **kw)`, `[*xs, y]`, `{**d, k: v}` | The same |
| `(x := v)` | `(x := v)` |
| `yield v`, `x = yield v`, `yield from xs` | `yield v;`, `x = (yield v);`, `yield from xs;`, in a function that returns `Generator[any, any, any]`: a `yield` gives what `send` sent |
| `async def`, `await`, `async with`, `async for` | The same |
| `del x, xs[i], d[k]`; `del o.a` | `del x, xs[i], d[k];`; `delattr(o, "a");` |
| An int, a float, a str, bytes, `True`, `False`, `None`, `...` | The same literal |
| A name that is a Jac keyword, such as `by`; a Python builtin function used as a value (`key=min`); a builtin type used as a value (`defaultdict(tuple)`); in a cpython space, a name only Python's builtins have (`compile`, `exec`, `__builtins__`) | The name behind a backtick, `` `by ``; the builtin through `builtins` (`key=builtins.min`); `int`, `float`, `str`, `bytes` and `bool` as they are, `list`, `set` and `dict` as `list[any]`, `set[any]` and `dict[any, any]`, and the others through `builtins` (`defaultdict(builtins.tuple)`); the same name, which a cpython space reads as Python's |
| `+ - * / // % ** @ << >> & \| ^`, `- + ~ not`, `and`, `or` | The same operators |
| `== != < <= > >= in`, `not in`, `is`, `is not`, chained | The same comparisons, where only their truth is used (an `if`, a `while`, `assert`, `not`, a test's `and` and `or`); one whose value is kept (assigned, returned, an argument) is Python's operator, `operator.eq(a, b)`, and a kept chain one after another, `operator.lt(a, b) and operator.lt(b, c)`, a middle operand that is computed held where it is computed, `operator.lt(a, (b_ := f())) and operator.lt(b_, c)` |
| `f(a, k=v)`, `o.m(a)`, `C(a)`; a builtin's call that spreads its arguments (`zip(*rows)`) | The same call; `builtins.zip(*rows)` |
| `o.a`, `xs[i]`, `xs[a:b:c]`; `f.a` of a function `f` declared by `def` with no decorator, read, assigned or augmented | The same; `getattr(f as any, "a")`, `setattr(f as any, "a", v);`, which a Jac function value has on a cpython space |
| `[a, b]`, `{k: v}`, `{a, b}` | The same displays |
| `a if c else b` | `a if c else b` |
| `f"{x!r:>4} and {y}"` | The same f-string |
| `[e for x in xs if c]`, and the set, dict and generator forms | The same comprehension, a tuple of targets in parentheses |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file. So is a
construct in the table whose Jac would mean something else (E4005, or E4001 where marked):

- **A default value that is not a constant, of a function made in a loop.** Python makes one
  for each function it makes; the variable port holds it in would be shared.
- **A comprehension whose variable a function made in it takes.** Python's comprehension has
  one variable, and Jac's a variable for each pass.
- **`global x` in a function inside one whose local `x` is.** Assigning `x` in Jac assigns the
  enclosing function's local.
- **A member declared in two arms of a class body's `if` whose test only the running program
  knows** (E4001). A Jac class declares each member once.
- **A module-level function, class or import that the module's code binds again.** Its Jac
  name is bound once, as the program starts.
- **`from m import *` whose names port cannot know:** of a module not of the project, or of
  one whose `__all__` is not one list of names written out, that imports `*` itself, reaches
  its names through `globals()`, binds one only in a function or deletes one in a block; and
  one that binds a name the importing module also binds.
- **A variable or a parameter of two leading underscores in a class's code** (`__x`, E4001), which
  Python renames with the class's name; an attribute, a field or a method so named is written
  as Python renames it (`self.__x` in `class C` is `self._C__x`).
- **A read of a name nothing in the module binds, nor Python's builtins** (`left_out()`): Python
  raises NameError where it runs.
- **`x is 1`, an int literal past 64 bits.**
- **A string holding a surrogate pair** (`"\ud83d\udc4d"`) in a module of a JS host, whose strings
  are UTF-16 text, in which the pair is the character it stands for. Elsewhere, and a lone surrogate
  everywhere, it is written with its surrogates as escapes, which a Jac string holds apart, as Python's does.
- **A module the source imports that neojac cannot find** (E4016): port checks the Jac it
  writes against it, so the module is installed first, or ported in the same run.
