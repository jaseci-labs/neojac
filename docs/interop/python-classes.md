---
description: What a cpython space makes as Python does - a class with a Python base, a Python decorator or a run-time if or a try in its body, and a class in a code body, made where its statement runs; decorators that run as a function is made; annotations Python reads; doc strings; imports in a code body; the names a module's imports bind; generators and raise of any object - and what each is refused as elsewhere.
keywords: host-made class, class body try, Python base, NamedTuple, dataclass, total_ordering, class decorator, run-time decorator, staticmethod, classmethod, annotations, inspect.signature, __annotations__, Annotated, typing.Any, Python class in Jac, importlib.reload, __spec__, spec_from_file_location, module start order, cls static, __qualname__
grammar: members_try
---
# Classes and decorators in a cpython space

A space whose host is `cpython` is Jac lowered to Python and run on neojac's CPython
([Hosts](../apps/hosts.md#cpython)). There, Python's own machinery runs on Jac's declarations: a
class can be made by a Python base or a Python decorator, a function's decorators run as Python
runs them, and Python reads a function's annotations and doc string. This page says what Python
makes in such a space, and what the same program is in a space of another host.

The examples on this page are the module `main` of a project whose `archwire.jac` says

<!-- example: not checked: a project's archwire.jac, which names main.jac beside it -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space s: cpython { entry main; }

    app s { run s; }
}
```

and each prints what is shown under it with `neojac run s`.

## Classes Python makes

A class is made by Python, as its `class` statement runs, when it has any of these:

- **a base that is a Python name** (`NamedTuple`, `enum.Flag`, a SQLModel or pydantic model), or
  a base that is such a class;
- **keywords** after its bases (`class Item(Base, table=True)`);
- **a decorator that is not a compile-time function of the program**: a Python callable
  (`@dataclass`, `@functools.total_ordering`), or a function of the program's own
  (`@retry_on_failure()`, [below](#a-class-decorated-by-a-function-of-the-program));
- **an `if` among its members that is not `comptime`**, whose test is known only as the program
  runs, or **a `try` among its members** ([below](#a-class-bodys-try)).
- **a static field whose value reads a global its module's code makes** (`glob POSIX: any;`
  set in `with entry`, then `static has kinds: any = ["a"] if POSIX else [];`): made where its
  statement stands, after that code has run, as Python would. Natively, the class's statics are
  set before the module's code runs, and the read raises `NameError`
  ([Variables](../language/variables.md)).

Such a class is Python's, from its body:

- **Its `has` fields are the class body's annotated names**, with their values, evaluated once as
  the class is made, and its annotations as written (`any` is `typing.Any`).
- **Its static fields are the body's plain assignments**, and its keywords are the class
  statement's.
- **Its methods are as written.** Jac generates no constructor, `__eq__`, `__hash__` or
  `__repr__` for it: its base's or its decorator's machinery reads the fields. Its `init` is
  Python's `__init__`, its constructor, and `super.init(...)` calls the base's `__init__`: a
  class Python makes is constructed as Python constructs it.
- **It is made where its statement stands**, in order with the module's `with entry` code, as
  Python makes a class where its `class` statement runs.
- **Its comparisons, arithmetic and attributes are Python's.** A call of the class, and a member
  it does not declare (one its base gives it), are dynamic to the checker; an operator no Jac
  method of the class defines is too (`total_ordering`'s `>=`). An instance takes any attribute:
  `self.pid = pid` in an `__init__` adds one.

<!-- example: not checked: runs in a cpython space -->
```jac
import builtins;
import functools;
import from dataclasses { dataclass, field }
import from typing { NamedTuple }

@functools.total_ordering
@dataclass(frozen=True)
class Ver {
    has major: int;
    has minor: int = 0;
    has tags: list[str] = field(default_factory=builtins.list);

    def __lt__(other: any) -> bool {
        return (self.major, self.minor) < (other.major, other.minor);
    }
}

class Pair(NamedTuple) {
    has left: int;
    has right: str | None = None;

    def both -> str {
        return str(self.left) + "/" + str(self.right);
    }
}

with entry {
    print(Ver(1) < Ver(1, 2), Ver(2) >= Ver(1, 9), Ver(1, 2) == Ver(1, 2), Ver(3));
    p = Pair(1);
    print(p, p.both(), p._replace(left=2));
}
```

```text
True True True Ver(major=3, minor=0, tags=[])
Pair(left=1, right=None) 1/None Pair(left=2, right=None)
```

`Ver(1).major = 2` raises `dataclasses.FrozenInstanceError`, as Python's does.

An `init` of a class with a Python base:

<!-- example: not checked: runs in a cpython space -->
```jac
import from collections { UserList }

class Stack(UserList) {
    def init(first: int) {
        super.init([first]);
        self.top = first;
    }
}

class Pair(Stack) {
    def init(a: int, b: int) {
        super.init(a);
        self.append(b);
    }
}

with entry {
    p = Pair(1, 2);
    print(p, p.top, "__init__" in (Stack as any).__dict__);
}
```

```text
[1, 2] 1 True
```

### A class decorated by a function of the program

A decorator of the program's own that is not a compile-time function (a function that takes the
class and gives one back, a call that makes such a function, or a global of the project bound to
one, `skipif = pytest.mark.skipif;` then `@skipif(...)`) is Python's too: it runs as the
class is made, as `@retry_on_failure()` runs on a test class in Python. The class is then made by
Python, as with a Python decorator, so Jac generates no constructor for it.

<!-- example: not checked: runs in a cpython space -->
```jac
def tagged(label: str) -> any {
    def mark(cls: any) -> any {
        cls.label = label;
        return cls;
    }
    return mark;
}

@tagged("slow")
obj Probe {
    has n: int = 0;

    def twice -> int {
        return self.n * 2;
    }
}

with entry {
    p = Probe();
    p.n = 4;
    print(Probe.label, p.twice());
}
```

```text
slow 8
```

In a native or JavaScript space the same decorator is E1490: a decorator there is a
compile-time function.

### A class body's run-time `if`

An `if` among a class's members runs as the class is made, and the members of the arm it takes are
the class's. A member is declared once, but for a static declared again in another arm of the
same `if`, with the same annotation: it is one attribute, which the arm that runs sets. Any other
member declared twice is E0077.

<!-- example: not checked: runs in a cpython space -->
```jac
import math;

glob HAS_EXTRA: bool = math.pi > 3;

class Proc {
    def __init__(pid: int) -> None {
        self.pid = pid;
    }

    if HAS_EXTRA {
        def extra -> int {
            return self.pid * 2;
        }
    } else {
        static has kind: str = "none";
    }
}

with entry {
    print(Proc(3).extra(), hasattr(Proc, "kind"));
}
```

```text
6 False
```

An `if` that tests the platform is a `comptime if`, which every host decides as the program
compiles ([comptime if](../language/compile-time.md#among-declarations-and-members)).

A static's value in a class Python makes reads the class's statics declared above it by their bare
names, as a Python class body reads them: `static has big: int = small + 1;` after
`static has small: int = 1;` reads the class's `small` ahead of any global of that name.
Natively a class's statics are not names in its body (W2001).

### A class body's `try`

```ebnf
members_try ::= "try" members_block ("except" expression members_block)* ("else" members_block)? ("finally" members_block)?
```

A `try` among a class's members runs as the class is made, as a `try` in a Python class body does:
its block declares members until a statement raises, a handler whose class matches declares its
own, `else` declares its members where nothing raised, and `finally` always does. A static
declared in two arms of the `try`, with the same annotation, is one attribute, whose value is that
of the arm that ran last. A handler does not name the exception: `except E as e` would make `e` an
attribute of the class.

<!-- example: not checked: runs in a cpython space -->
```jac
import os;

class Limits {
    try {
        static has source: str = "env";
        static has limit: int = int(os.environ.get("LIMIT", "none"));
    } except ValueError {
        static has limit: int = 4;
    } else {
        static has parsed: bool = True;
    } finally {
        static has read: bool = True;
    }
}

with entry {
    print(Limits.limit, Limits.source, hasattr(Limits, "parsed"), Limits.read);
}
```

```text
4 env False True
```

### A class in a code body

A class declared in a function, a method or a `with entry` block is made by Python where its
statement runs, each time it runs, as a Python `class` statement in a function is: two calls make
two classes. An `obj` there with no Python base is a Jac `obj` still, whose fields are its
constructor's parameters (`Local(n=k)`); one over a Python base is a Python class.

<!-- example: not checked: runs in a cpython space -->
```jac
import reprlib;

def shower -> any {
    class Short(reprlib.Repr) {
        has kind: str = "short";

        def repr_str(x: any, level: any) -> str {
            return x[:3];
        }
    }
    return Short;
}

with entry {
    first = shower();
    print(first().repr("abcdef"), first.kind, first is shower());
}
```

```text
abc short False
```

A class there may read the names of the body it is in, a parameter or a local, as Python's
closure does: each read sees the name's binding when the read runs, so a name the body binds again
after the class statement is read with its new value.

<!-- example: not checked: runs in a cpython space -->
```jac
import reprlib;

def made(n: int) -> any {
    class Shown(reprlib.Repr) {
        def repr_int(x: any, level: any) -> str {
            return str(x + n);
        }
    }
    n = n * 10;
    return Shown;
}

with entry {
    print(made(2)().repr(1));
}
```

```text
21
```

Its bases and its attributes' values are evaluated where the statement runs, as Python evaluates
them, so they may read the body's names too: a base an import in the function gives
(`import ctypes;` then `class iovec(ctypes.Structure) { ... }`), or an attribute made from a local
(`static has wide: any = width;`). A base that names a class of the program is that class.

On a JavaScript host, which makes a class in a code body too, such a class is refused (E5177).

### In a space of another host

A native or JavaScript program's classes are known as it compiles, so these are not made there:

| Code | In a native or JavaScript space |
|---|---|
| E5174 | A class or a function decorated by a Python callable |
| E1490 | A class or a function decorated by a function of the program that is not compile-time |
| E5175 | An `if` among a class's members that is not `comptime` |
| E5220 | A `try` among a class's members |
| E5176 | Natively, a class in a code body: declare it at the module's top level. On a JavaScript host JavaScript makes it where its statement runs, a new class each time, as Python does ([Hosts](../apps/hosts.md)) |
| E2101 | Keywords after a class's bases |

A class whose base is a Python class is, natively, a subclass of it in the embedded interpreter
([Python](python.md)).

## Decorators

In a cpython space, a decorator that is not a compile-time function of the program
([Decorators](../language/decorators.md)) runs as Python runs it: on the function as it is made,
the nearest the `def` first, and its result is what the name holds. A function decorated so is
made where its `def` stands; a method, as its class is made.

<!-- example: not checked: runs in a cpython space -->
```jac
import functools;

def twice(f: any) -> any {
    @functools.wraps(f)
    def wrapper(*args: any) -> any {
        return f(*args) * 2;
    }
    return wrapper;
}

@twice
def area(w: int, h: int) -> int {
    return w * h;
}

obj Box {
    @functools.cache
    static def made(n: int) -> int {
        return n + 1;
    }
}

with entry {
    print(area(3, 4), area.__name__, Box.made(1), Box.made.cache_info().misses);
}
```

```text
24 area 2 1
```

A `static def` is Python's `staticmethod` and a `class def` its `classmethod`, made one after
its decorators run. Where Python would apply the wrapper among other decorators, the method names
it in its place: `@builtins.staticmethod` on a `static def`, `@builtins.classmethod` on a
`class def`. On any other method it is E2241.

## Annotations

Every function's annotations are Python's, as `inspect.signature` and `typing.get_type_hints`
read them, so a library that reads them (FastAPI's parameters and dependencies, pydantic's
fields) finds what the source said:

- a Jac class is the class, and a Python name is its value;
- `Annotated[T, ...]` is carried with its metadata, and to the checker it is `T`;
- a `type` alias over Python names is its value: `type SessionDep = Annotated[Session,
  Depends(get_db)];`;
- a sized number (`i64`, `f32`) is `int` or `float`, and `any` inside a type (`list[any]`) is
  `typing.Any`;
- a parameter written with no annotation, `def f(a, b: int)`, has none: `check` reads it as `any`,
  and `__annotations__` holds no entry for it, as Python's own `def f(a, b: int)` holds none. On
  every other host it is E0052;
- **a parameter or a result annotated with the bare type `any` has none either**: `any` is Jac's
  word for what Python leaves unannotated, so `-> any` puts no `return` in `__annotations__`, and
  a def `neojac port` wrote from an unannotated Python def has the annotations its source had. A
  `typing.Any` the source wrote stays `typing.Any`.

<!-- example: not checked: runs in a cpython space -->
```jac
import inspect;

def twice(x, y: int = 2) -> any {
    return x * y;
}

with entry {
    print(twice("ab"), twice(3, 3));
    print((twice as any).__annotations__);
    print(inspect.signature(twice));
}
```

```text
abab 9
{'y': <class 'int'>}
(x, y: int = 2)
```

A Python name used as a type (`EmailStr`, `uuid.UUID`, `Literal["a", "b"]`) is `any` to the
checker, on every host.

**An annotation may name a variable of the module, and may be a string**, as Python's may. A
`glob` named where a type stands (`Annotated[Kind, "which"]`, where module code binds
`Kind = typing.Literal["a", "b"]`) is `any` to the checker, which checks the name as a read of the
global, and Python is handed its value. A string literal (`n: "int"`) is the string, as Python
keeps a forward reference, and `any` to the checker. Natively and on a JavaScript host neither is
a type: E2018 for the variable, E1163 for the string.

<!-- example: not checked: runs in a cpython space -->
```jac
import typing;

glob Kind: any;

with entry {
    Kind = typing.Literal["a", "b"];
}

def picked(kind: typing.Annotated[Kind, "which"], n: "int" = 1) -> str {
    return kind * n;
}

with entry {
    print((picked as any).__annotations__);
    print(typing.get_type_hints(picked, include_extras=True)["n"], picked("b", 3));
}
```

```text
{'kind': typing.Annotated[typing.Literal['a', 'b'], 'which'], 'n': 'int', 'return': <class 'str'>}
<class 'int'> bbb
```

### A default made once

A parameter's default is made each time a call leaves the parameter out, on every host, so a
default that reads a global reads its value at the call. In a cpython space a module-level def's
default that reads a global bound once is instead Python's own default value, made when the def is
made, so `inspect.signature` and `__defaults__` show it and a library that reads the signature
(typer, click) passes it. A global is bound once where it is given a value at its declaration and
never again, or declared with none and stored once, by a top-level statement of a `with entry`
block of the def's own file above the def; no write of it anywhere in the program (an attribute
write of its name included) and no `del`. Any other default is made at each call, as natively.

<!-- example: not checked: runs in a cpython space -->
```jac
import inspect;

glob SHELF_DEFAULT: any;

with entry {
    SHELF_DEFAULT = [1];
}

def shelved(where: any = SHELF_DEFAULT) -> any {
    return where;
}

with entry {
    print(inspect.signature(shelved), shelved() is SHELF_DEFAULT);
}
```

```text
(where=[1]) True
```

Within the program nothing changes: the global holds that one value whenever a call reads it.
**The one difference** is for a Python file of the space that rebinds the module's attribute
after the def is made (`used.SHELF_DEFAULT = [2]`): the def's default is still the value it was
made with, `[1]`, as Python's own default would be, where a per-call default would read `[2]`.

`import from __future__ { annotations }` is Python's own future statement in a cpython space:
Python postpones the module's annotations, keeping each as its text, so a raw `__annotations__`
read gives strings and `typing.get_type_hints` gives the objects. It governs the whole module, its
classes too, and `neojac fmt --fix` keeps it there. In a program of any other host it does
nothing, and is W3009.

In such a module every annotation is the text written, a nested def's and an annotated local's
among them, and nothing more: `check` reads each as
`any` and resolves no name in it, as Python does not, so an annotation may name what only an
`if TYPE_CHECKING:` import would bind, or nothing at all. The module's program hands Python the
text as written:

<!-- example: not checked: runs in a cpython space -->
```jac
import from __future__ { annotations }

def f(x: int, ys: list[Undefined]) -> list[str] {
    return [str(x)];
}

with entry {
    print((f as any).__annotations__);
    print(f("a", []));
}
```

```text
{'x': 'int', 'ys': 'list[Undefined]', 'return': 'list[str]'}
['a']
```

## Doc strings

A doc string is the program's in a cpython space: a function's, a class's and a module's is its
`__doc__`, as in Python, and neither a lint rule nor `neojac fmt --fix` removes it there.

<!-- example: not checked: runs in a cpython space -->
```jac
import inspect;
import from typing { Annotated }

obj Point {
    has x: int = 0;
}

type Tag = Annotated[str, "a tag"];

"""Where a point is placed."""
def placed(p: Point | None, n: int, tag: Tag = "") -> list[Point] {
    return [];
}

with entry {
    print(inspect.signature(placed));
    print((placed as any).__doc__);
}
```

```text
(p: __main__.Point | None, n: int, tag: Annotated[str, 'a tag'] = '') -> list[__main__.Point]
Where a point is placed.
```

## An import in a code body

An `import` in a function loads its module where it runs, as on every host
([Modules](../language/modules.md#an-import-in-a-code-body)). In a cpython space it may also name
a Python module, which Python loads there; its names are `any` to the checker. What Python cannot
load as it runs, a path or an `include`, is E5173.

<!-- example: not checked: runs in a cpython space -->
```jac
def address(text: str) -> any {
    import ipaddress;
    import from os.path { basename as base }
    return [str(ipaddress.ip_address(text)), base("/a/b.txt")];
}

with entry {
    print(address("127.0.0.1"));
}
```

```text
['127.0.0.1', 'b.txt']
```

**In module code, an import binds the module's `glob` of the name it gives**, where it runs, as
Python's import at a module's top binds the module's name: under a `try` that falls back where a
module is not installed, or under an `if`. A name the module declares no `glob` of stays the
code's own. Natively the `glob` and the import are two declarations of one name, E2036.

<!-- example: not checked: runs in a cpython space -->
```jac
glob json: any,
     fast: any;

with entry {
    import json;
    try {
        import from not_installed_anywhere { loads as fast }
    } except ImportError {
        fast = None;
    }
}

def dumped -> any {
    return json.dumps([1, fast]);
}

with entry {
    print(dumped());
}
```

```text
[1, null]
```

## Properties

A field with a `getter` (and a `setter`) is Python's own property in a cpython space: `@property`
with the field's annotation as its result's and the field's doc string as its `__doc__`, and
`@x.setter` taking the setter's annotated value. Read off the class, `C.x` is the `property`
object, as Python's is.

## A module's imported names

A module holds the names its imports and wires bind as its attributes, as Python's import binds
them in the module's namespace: with `import from os.path { basename }` and `import math;` in
`kit/shapes.jac`, `shapes.basename` and `shapes.math` are those objects, to Python reading the
module and to a Jac module that takes it whole, and `dir()` of the module lists them. `dir()`
lists what the module's source gives, its declarations and the names its imports bind, and none of
the names the emission needs to run it.

<!-- example: not checked: runs in a cpython space whose module kit/shapes.jac is wired as shapes, `kit.shapes as shapes ++> main;` -->
```jac
with entry {
    b = shapes.Box(w=2.0);
    b.area = 9.0;
    prop = shapes.Box.area;
    print(b.w, type(prop).__name__, prop.__doc__);
    print(shapes.basename("/a/b.txt"), shapes.math.pi > 3);
    print((shapes.log as any).__annotations__);
}
```

with `kit/shapes.jac` holding

<!-- example: not checked: the module kit/shapes.jac of the space above -->
```jac
import from os.path { basename }
import math;

obj Box {
    has w: float = 1.0;

    """The box's area."""
    has area: float {
        getter {
            return self.w * self.w;
        }
        setter(value: float) {
            self.w = math.sqrt(value);
        }
    }
}

def log(msg: str) -> None {
    print(basename(msg));
}
```

```text
3.0 property The box's area.
b.txt True
{'msg': <class 'str'>, 'return': None}
```

`-> None` is the function's annotation there, which no lint rule removes in a cpython space
([Lint](../toolchain/lint.md)).

A function or a class an import names is the importer's own binding, as Python's
`from m import f` is: the import binds it where it runs, and a bare `f` reads the importer's
global. A patch of the home module (`mock.patch.object(used_mod, "twice", zero)`, a `setattr`)
changes what `used_mod.twice` is and leaves the importer's `twice` the function it took, as in
Python. The binding is made as soon as the home module has made the name, so a class body, a base,
a decorator or a default of the importer reads it while the importer is made. A global an import
names stays one place, its module's: Jac lets a program write a global through the name an import
gives it, and every name of it sees the write.

Every module of the space has its `__spec__` and `__loader__`, the module the program starts with
too, so `importlib.reload(m)` runs a module's code again, and an importer's reload takes the
current value of each name it imports.

<!-- example: not checked: runs in a cpython space whose module kit/used.jac is wired as `kit.used ++> main { count, counted, twice }` and `kit.used as used_mod ++> main;` -->
```jac
import importlib;

def zero(n: int) -> int {
    return 0;
}

def bump {
    count = 7;
}

with entry {
    m: any = used_mod;
    setattr(m, "twice", zero);
    print(twice(3), used_mod.twice(3));
    bump();
    print(count, used_mod.count, counted());
    print(used_mod.__spec__.name, importlib.reload(used_mod) is used_mod, used_mod.twice(3));
}
```

with `kit/used.jac` holding

<!-- example: not checked: the module kit/used.jac of the space above -->
```jac
glob count: int = 0;

def twice(n: int) -> int {
    return n * 2;
}

def counted -> int {
    return count;
}
```

```text
6 0
7 7 7
kit.used True 6
```

A Jac module starts where Python would start it: in the order of the space's imports, and before
the code of a Python file that imports it runs, so a Jac module that imports `helper.py` starts
after the Jac modules `helper.py` imports. Its defs and classes are made where they stand in its
code, so a reload whose code raises keeps what was made before the raise, as Python's does.

A module loaded by its path under another name (`importlib.util.spec_from_file_location("used",
path)` of a module the space emitted) is a module of its own, as in Python: its code runs there,
the names its imports give are bound in it, and `sys.modules` holds it only where the loader puts
it.

A submodule read through its package (`kit_pkg.drawer`, where `kit_pkg` is a package of the
space and `drawer` a module in it) is Python's read of the package's attribute, so it is the
module object itself: `kit_pkg.drawer is drawer`.

## A class's statics through a subclass

A class is Python's own class object in a cpython space, so a static read or written through a
class's name is Python's attribute of that class: written through a subclass's name or through
`cls` in a `class def`, it is the subclass's own, and the base keeps its value. A `class def`
calls another through `cls`, which dispatches on the class `cls` is.

<!-- example: not checked: runs in a cpython space -->
```jac
obj Tallied {
    static has total: int = 0;
}

obj Retallied(Tallied) {
    class def setup -> int {
        cls.total = cls.base() + 1;
        return cls.total;
    }

    class def base -> int {
        return 10;
    }
}

with entry {
    print(Retallied.setup(), Retallied.total, Tallied.total);
    Retallied.total = 20;
    print(Retallied.total, Tallied.total);
}
```

```text
11 11 0
20 0
```

Natively a static is one value, the declaring class's, shared by every subclass
([Static fields](../language/fields.md#static-fields)): `Retallied.total = 20` is E1640, a write
the program says through `Tallied.total`, and a write or a class-method call through `cls` is
E1030.

## A module's `__file__`

In a cpython space a module's `__file__` is its Jac source's whole path, as natively
([Modules](../language/modules.md#module-variables)): `os.path.basename(__file__)` is `main.jac`,
and a module that finds its files beside itself (`os.path.dirname(__file__)`) finds them there.

## Generators and `raise`

- **A function whose result is `any` and that yields is a generator**, as a Python `def` is: a
  function ported with `-> Generator[Session]` is one.
- **`raise` takes any object**, as Python's does: a Python exception class's instance
  (`raise HTTPException(status_code=404)`) is raised as it is, and an object that is no exception
  raises Python's `TypeError`.

## Other forms Python reads as it runs

- **`super()` in a `class def` of a class Python makes** is Python's: it reaches the base's
  classmethod, as `super().fromkeys(...)` does in Python.
- **`def __exit__(self, *args, **kwargs)`** is a context manager's exit, as Python takes it, with
  `*args` given the exception's type, value and traceback.
- **A name only another target's `comptime if` arm declares** (`GetProcessHeap` under an arm
  for Windows) is Python's lookup where it is read: a `NameError` where it runs on a target that
  declares none, as Python's is where the source's `if WINDOWS:` did not run.

## What is rejected

| Code | Condition |
|---|---|
| E2241 | `@builtins.staticmethod` or `@builtins.classmethod` on a method that is not a `static def` or a `class def` |
| E5173 | An import in a code body of what Python cannot load as it runs |
| E5174 | Outside a cpython space: a class or function decorated by a Python callable |
| E5175 | Outside a cpython space: an `if` among a class's members that is not `comptime` |
| E5220 | Outside a cpython space: a `try` among a class's members |
| E5176 | Outside a cpython space: a class in a code body |
| E5177 | On a JavaScript host: a class in a code body that reads a name of that body |
| E0077 | A member declared in two arms of a class body's `if` or `try`, but a static of one annotation |
