---
name: using-c-and-rust
description: Use when Jac code must call C or Rust - binding a system C library (libc, libm, zlib, sqlite3) with import from <lib> { ... } declarations, compiling C source into the program as a C module (cmodule.toml), a Rust crate as a module, a project's own shared library, pointers and buffers, and building C or Rust alone with neojac cc and neojac cargo.
---
# Calling C and Rust

## When to use this

Use it when native Jac code calls code compiled from C, C++ or Rust. Pick the form first:

| You have | Use | neojac builds it? |
|---|---|---|
| A library already on the system (`c`, `m`, `z`, `sqlite3`) | Declarations in `import from <lib> { ... }` | No: you state its interface |
| C or C++ source and headers | A C module: a directory with `cmodule.toml` | Yes, headers read by Clang |
| A Rust crate | A Rust module: a directory with `Cargo.toml` | Yes, with cargo and rustc |
| A `.so` / `.dylib` the project builds or vendors | `import from vendor.<name> { ... }` declarations | No |

Load `writing-jac` first. A Python extension or Node addon is `using-python-packages` or
`using-npm-packages`.

## Before you start

```sh
neojac docs C library        # declarations, the type table, naming the library
neojac docs C module         # cmodule.toml, what Jac binds from headers
neojac docs Rust module      # what a crate's interface gives Jac
neojac docs ptr              # pointers, views, pin, addressof
```

C's `int` is `i32`; Jac's `int` is 64-bit (`int64_t`). An `int` given to a C function's `i32`
parameter or stored in a C record's `i32` field narrows by itself, checked as it runs: one that
does not fit raises `OverflowError` there. A `float` narrows to a C `f32` the same way. A Jac
function's `i32` parameter takes no `int` but by `i32(n)`.

## Steps

1. **Bind a system library** by declaring what you call. Nothing checks a declaration against
   the library: get each type right from its C prototype.

```jac
import from c {
    def strlen(s: str) -> u64;
    def abs(x: i32) -> i32;
    def snprintf(buf: bytearray, n: int, fmt: str, *args: VaList) -> i32;
    def calloc(n: int, size: int) -> ptr[i32];
    def free(p: ptr[i32]) -> None;
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
}

import from m {
    def modff(x: f32, whole: &mut f32) -> f32;
}

def descending(a: ptr[i32], b: ptr[i32]) -> i32 {
    return b[0] - a[0];
}

with entry {
    n = -5;
    print(strlen("héllo"), abs(n));
    whole = f32(0.0);
    frac = modff(f32(2.75), &mut whole);
    print(whole, frac);
    buf = bytearray(32);
    k = snprintf(buf, len(buf), "%s=%d", "x", 42);
    print(buf[:k].decode());
    nums = calloc(3, 4);
    for (i, v) in enumerate([5, 30, 10]) {
        nums[i] = i32(v);
    }
    qsort(nums, 3, 4, descending);
    view = nums.view(3);
    print([view[i] for i in range(len(view))]);
    free(nums);
}
```

```output
6 5
2.0 0.75
x=42
[30, 10, 5]
```

Buffers and pointers, as above: a `bytearray` argument lets C write in place; `&mut x` lends a
variable's address for one call; memory from `calloc` is a `ptr[T]`, indexed unchecked, freed by
C's `free`, its size `sizeof(T)` (`import from jaclang.comptime { sizeof }`); `p.view(n)` is a bounds-checked view, indexed (never iterated) with
`range(len(v))`. A Jac `list` is not a C array: copy into C memory. Where C keeps an address
after the call, use `pin(x)` (`neojac docs pin`); to give C a Jac object as a callback's user
data, `hold(obj)`, taken back in the callback by `held[T](p)` (a `TypeError` for an address C
does not hold) and given up by `release(p)`. A C record field of an `obj` is kept in the object
(a read of it copies; `addressof(t.f)` is its address), and `held[T](f=p)` is the `T` C holds whose
field `f` is at `p` (E1638 where `f` or `p`'s type does not fit).
Only a named function is a callback as it is; a function value (a variable, a parameter, a
record's field) is passed converted, `Callable[[ptr, ptr], i32](cmp)` or `ptr(cmp)`, and one with
no C address (a closure that captures) raises `TypeError` there. A function pointer C may give
as `NULL` is `Callable[...] | None`, `None` where C's is null: test it before calling it.
`ptr[u16]("text")` and `ptr[u32]("text")` are C's `u"text"` and `U"text"`, of a literal only.
A C++ library's pointer to a function of C++ types (`int (*f)(Counter &, int)`), a member's
parameter or a free function's, takes a def or a static method by its name, of exactly its Jac
form (`def bump_by(c: Counter, step: i32) -> i32`); a lambda, a bound method or another
signature is E1639. A pointer to a member function of the class a Jac class derives
(`int (T::*m)(int)`) takes a method by its class (`Drop.plus_size`), E1623 otherwise. C++ must
call it on the thread that called into C++: from a thread of the library's own the program ends,
naming the function. In an extension module or a Node addon, a thread of the loading process that
enters through the module's exports (Node's main thread, a worker's) is made known to the Jac
runtime and may be called back on. A C++ member's `const char *` result (`s.c_str()`) is a `ptr[i8]` into the
object, a loan of it (as C++ declares of `std`'s accessors and of a `[[clang::lifetimebound]]`
member): the object is kept while the pointer is used, a member that changes it may leave the
pointer dangling, and `str(p)` copies its text. A member C++ declares no loan of gives a pointer
under C++'s contract alone: keep its object while the pointer is used.

2. **Compile C source in as a C module.** A directory `stats/` beside the program:

```toml
# stats/cmodule.toml
headers = ["stats.h"]
sources = ["stats.c"]
libs = ["m"]
```

`stats/stats.h` declares `typedef struct { double mean; double stdev; } summary;`,
`summary summarize(const double *xs, int64_t n);` and `#define STATS_MAX 1024`. Jac imports the
names; the types come from the header (`const double *` is `ptr[float]`, the struct a record,
the `#define` an `int`):

<!-- example: not checked: needs the C module stats beside the program -->
```jac
import from c {
    def calloc(n: int, size: int) -> ptr[f64];
    def free(p: ptr[f64]) -> None;
}

import from stats { STATS_MAX, summarize }

with entry {
    xs = calloc(4, 8);
    for (i, v) in enumerate([2.0, 4.0, 4.0, 6.0]) {
        xs[i] = v;
    }
    s = summarize(xs, 4);
    print(STATS_MAX, s.mean, s.stdev);
    free(xs);
}
```

`neojac build main.jac -o main && ./main` prints `1024 4.0 1.4142135623730951`. In a project
with an `archwire.jac`, wire a C module in (`stats ++> main { summarize }`) instead of importing
it (E1144).

3. **Link a Rust crate as a module.** A directory `adder/` with a plain `Cargo.toml`
   (`[package] name = "adder"`, `edition = "2024"`) and `src/lib.rs` exporting C-ABI items:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn add(a: i64, b: i64) -> i64 {
    a + b
}
```

`import from adder { add }` then `print(add(2, 3))` prints `5` after `neojac build`. Rust's own
API needs no `extern "C"`: `import from std.collections { HashSet }`, and a crate's ordinary
`pub` items through its wire, are used natively, generics by their arguments
(`HashSet[u32].new()`), a generic method or function by its argument where a type parameter is
the type of one (`e.label("title")` of an `impl Into<String>`) and by its instance at the call
where none is (`o.zip[u32](p)`), a lambda for a closure, one Rust keeps included
(`Hook.new(lambda (x: int) -> int { return x + 1; })`), a
slice of numbers as `Slice[u32]` (`import from rust { Slice }`, `v.as_slice().sub(a, b)`,
`bytes(s)` of a `Slice[u8]`), a slice's methods on a `Vec` (`v.sort()`, `v.contains(&x)`), an
iterator stepped by `next()`, a panic as `RustPanic` (`import from rust { RustPanic }`). A value
whose drop runs code is dropped where an `own` local's scope ends; a local or a field with no
ownership annotation holds one as a managed place, from which no `own` binding takes it (E1637). A call that waits in C or Rust is written as a task, `wait flow gate.pass(ms)` or
`flow nap(ms)`, so that the program's other threads run meanwhile: called with no `flow`, foreign
code keeps the program's lock. `neojac docs Rust module` has what crosses.

4. **Call Jac from C.** A wire gives a C module a Jac function by name
   (`jhelp --> shapes.shapes { jhelp_scale }` for the project's own C file), and the C includes
   `jac/jhelp.h`, which neojac writes. Such a function takes and gives integers, floats,
   pointers and C records by value (E1249). A C++ class is an `obj` Jac uses, and derives with `super.init(...)` as
   the first statement of its `init` (E2335 elsewhere); a class template's instance is named by its template form, `Box[i32]`,
   and a member template's or a header library's function template's by its type arguments,
   `c.to[float]()`, `kept_[Counter](c)` (`neojac docs C module`).

5. **Bind a project library** you build yourself:

```sh
neojac cc -shared -fPIC vendor/tally.c -o vendor/libtally.dylib   # libtally.so on Linux
```

and declare it with its dotted path: `import from vendor.tally { def tally_add(n: int) -> int; }`.
The program finds it relative to itself, so keep both where they are.

6. **Build C or Rust alone** with the toolchain neojac carries (no system compiler needed):

```sh
neojac cc hello.c -o hello                          # this machine
neojac cc -target x86_64-linux-musl hello.c -o hello-linux
neojac cargo build                                  # in a crate's directory
neojac build app/Cargo.toml -o app                  # a Rust program, through neojac's cache
```

## What a correct result looks like

- `neojac check main.jac` prints nothing; `neojac build main.jac -o main && ./main` prints the
  values above. A C module's or crate's first build compiles it; later builds reuse the cache.

## Mistakes to expect

```jac
# expect: E1053, E1195
import from c {
    def abs(x: i32) -> i32;
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
}

def magnitude(x: i32) -> i32 {
    return abs(x);
}

with entry {
    n = 5;
    print(magnitude(n));
    qsort(ptr[i32](), 0, 4, lambda (a: ptr[i32], b: ptr[i32]) -> i32 { return a[0] - b[0]; });
}
```

| Code | Means | Fix |
|---|---|---|
| E1053 `expects i32, found int` | An `int` to a Jac function's `i32` parameter: only C's parameters and fields narrow one | Declare the parameter `int`, which narrows where it reaches C, or pass `i32(n)` |
| E1053 `expects ptr[float], found list[float]` | A list passed as a C array | Copy into `calloc`'d memory, pass the pointer |
| E1195 | A lambda or bound method as a callback | A named `def` |
| E1639 | A lambda, a bound method or another signature for a C++ library's function pointer | A `def` of the module, of the pointer's exact signature |
| E5090 `... as a C type` | A list, dict or Jac object in a declaration | Use the C types (`neojac docs C library`) |
| E1021 `cannot iterate PtrView` | A view in a `for` | `for i in range(len(v))` |
| E1145 | The header or crate has no such name | Check spelling; for Rust, `pub` and `#[unsafe(no_mangle)]` |
| E5138 | A Rust item or method Jac cannot bind; the message says why (a type that borrows, a type parameter the call must name) | Use what it returns instead, name the type (`c.first_as[u64]()`), or give it a C signature |
| E1625 | No instance of a generic Rust function or method for these types | Give an argument of a type the bounds hold for (`u32(3)`, not `"three"`) |
| E1308 | A task of a foreign call is given what another thread could change, or a Rust value that is not `Send` | Give it numbers, a `str`, `bytes` or a `ptr`; or call it with no `flow`, inside a Jac function |
| E1637 | An `own` binding takes a Rust value whose drop runs code from a managed local or field | Bind it `own` where it is made (`s: own HashSet[u32] = HashSet[u32].new();`), or keep the binding managed |
| E5134, E5135, E5140 | The headers, a C source, or a crate fail to compile | Read Clang's or rustc's errors printed above |
| E5149, W5021 | A library name that is no file, or absent on the target | `neojac docs C library` (naming the library) |
| Crash or garbage at run time | A declaration that disagrees with C, or a bad pointer | Recheck the prototype; nothing checks it for you |

## Where to look things up

- `neojac docs C library`: types, records, opaque types, callbacks, globals, variadics.
- `neojac docs C module`: every `cmodule.toml` key, inline modules, C++ sources, wiring.
- `neojac docs Rust module`: crate interface, calling Jac from Rust, the build and cache.
- `neojac docs Rust` and `neojac docs neojac cc`: the toolchains on their own, cross-targets.
- `neojac docs ptr`: views, `pin`, `addressof`, `load`/`store`.
