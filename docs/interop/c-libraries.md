---
description: Binding a C library from Jac with an import block of declarations - functions, records, globals, callbacks and variadics - how the library is named and found on each platform, and how a program links.
keywords: C library, import from c, C record, opaque C type, C global, C callback, C variadic, library import, FFI
---
# C libraries

A Jac module calls a C library by declaring what it uses of it. The declarations go in the braces
of an `import from <library>` statement; nothing else is needed: no header, no wrapper, no build
step.

```jac
import from c {
    obj div_t {
        has quot: i32,
            rem: i32;
    }

    def labs(x: int) -> int;
    def strlen(s: str) -> u64;
    def div(num: i32, den: i32) -> div_t;
}

import from m {
    def sqrt(x: f64) -> f64;
    def modff(x: f32, whole: &mut f32) -> f32;
}

with entry {
    print(labs(-7), strlen("héllo"), sqrt(2.0));
    d = div(17, 5);
    print(d.quot, d.rem);
    whole = f32(0.0);
    frac = modff(f32(2.75), &mut whole);
    print(whole, frac);
}
```

```output
7 6 1.4142135623730951
3 2
2.0 0.75
```

`c` is the C library and `m` its mathematics. The block declares C functions (`def` with no
body), C records (`obj`), and C globals (`glob`). Each is a name of the importing module, used
like any other. Native code calls C: a program, or a native or wasm space of an app; code of a
cpython, node, browser or hermes space that uses a C function, record or global is refused
(E1540, "needs C code").

The declarations are the program's statement of the C interface. Nothing checks them against
the library: a declaration that disagrees with the C function it names is undefined behavior, as
a wrong prototype is in C. To have Clang read the real headers instead, make the code a
[C module](c-modules.md).

Related pages: [pointers and native memory](pointers-and-native-memory.md) for `ptr[T]`, views
and `pin`; [opening a library as the program runs](dl.md) for libraries that may be absent;
[C modules](c-modules.md) for C source compiled into the program; [C and C++](c-and-cpp.md) for
building a library with `neojac cc`. The other direction, a Jac module built as a C library, is
`neojac build --lib`: see [Building programs](../toolchain/build.md) (`neojac docs build`).

## Types in a declaration

A parameter, a result and a record field are written in these types. Anything else is refused
(E5090).

| Jac type in the declaration | C type |
|---|---|
| `int` | A 64-bit signed integer: `int64_t`, `long long`, `long` on Linux and macOS |
| `i64`, `u64` | `int64_t`, `uint64_t` (`size_t` on 64-bit targets) |
| `i32`, `u32`, `i16`, `u16`, `i8`, `u8` | The integer of that width and sign (C's `int` is `i32`) |
| `bool` | C's one-byte `bool` |
| `float`, `f64` | `double` |
| `f32`, `f16`, `bf16` | `float`, `_Float16`, `__bf16` |
| `str` | `const char *`, NUL-terminated, UTF-8; `None` is `NULL` |
| `bytes`, `bytearray` | A pointer to the first byte; C is not told the length; `None` is `NULL` |
| `str \| bytes \| bytearray` (parameters only) | A pointer to the first byte of whichever it is given |
| `ptr` | `void *` |
| `ptr[T]` | `T *` |
| A C record declared in an import block | That `struct`, by value |
| `Callable[[P, ...], R]` | A pointer to a function of that signature; `None` is `NULL` |
| `None`, or no result type | `void` |
| `&T`, `&mut T` (parameters only) | `const T *`, `T *`: the address of the caller's variable |

A C or Rust 64-bit signed integer is an `int`, the integer Jac code computes with, and an
unsigned one is a `u64`. The sized types are described in [Numbers](../language/numbers.md)
(`neojac docs numbers`). A sized result widens to `int` where one is wanted.

The other way, the width is the library's, not the program's: an `int` given to a C function's
sized-int parameter, or stored in a C record's sized-int field, narrows to that type, and a
`float` to an `f32`. The int is checked as the program runs, as `i32(n)` checks it: a value the
type cannot hold raises `OverflowError` where the call or the store is, and a compile-time int
that does not fit is refused when the program compiles (E1126). A `float` rounds as `f32(x)`
rounds it, never raising: past `f32`'s range it is an infinity, and a NaN stays a NaN. Nothing
else narrows: an `i64` given where an `i32` is declared is still E1053, and a Jac function's
`i32` parameter takes an `int` only converted by name, `i32(n)`.

```jac
import from c {
    def strtol(s: str, end: ptr[ptr[u8]], base: i32) -> int;
    def toupper(c: i32) -> i32;
    def atof(s: str) -> float;
    def abs(x: i32) -> i32;
}

with entry {
    rest = ptr[u8]();
    print(strtol("42abc", &mut rest, 10), chr(rest[0]));
    n = -5;
    total: int = abs(n) + 1;
    print(total, chr(toupper(ord("a"))), atof("2.5") * 2);
    try {
        abs(n * 1000000000);
    } except OverflowError as e {
        print("abs:", e);
    }
}
```

```output
42 a
6 A 5.0
abs: integer overflow
```

### Strings

A `str` argument reaches C as a pointer to its UTF-8 bytes, NUL-terminated, valid for the call.
A `str` result is copied into a new Jac `str` up to the first NUL; C keeps ownership of its
buffer. `None` is C's `NULL` both ways: a `None` argument passes `NULL`, and a result C returns
as `NULL` is `None`. Write `str | None` where C documents either, as the type says so to a
reader; a `str` is the same type to the compiler. A parameter declared as a union of `str`,
`bytes` and `bytearray` takes any of them, for a C function that reads bytes of a given length
through a `const char *`:

```jac
import from c {
    def getenv(name: str) -> str | None;
    def strlen(s: str | bytes | bytearray) -> int;
}

with entry {
    print(getenv("NEOJAC_DOCS_NO_SUCH_VARIABLE"));
    print(strlen("four"), strlen(b"abc\x00zz"), strlen(bytearray(b"hello\x00")));
}
```

```output
None
4 3 5
```

Declare a result as a pointer where the address itself is wanted, and test it:

```jac
import from c {
    def strchr(s: str, c: i32) -> ptr[u8];
    def strlen(s: ptr[u8]) -> u64;
}

with entry {
    at = strchr("key=value", ord("="));
    if not at.is_null() {
        n = int(strlen(at + 1));
        print(bytes((at + 1).view(n)).decode());
    }
    print(strchr("key", ord("=")).is_null());
}
```

```output
value
True
```

`bytes` and `bytearray` arguments pass the address of their first byte. C writes into a
`bytearray` in place:

```jac
import from c {
    def snprintf(buf: bytearray, n: int, fmt: str, *args: VaList) -> i32;
}

with entry {
    buf = bytearray(32);
    n = snprintf(buf, len(buf), "%s=%d %.1f", "x", 42, 2.5);
    print(n, buf[:n].decode());
}
```

```output
8 x=42 2.5
```

A string literal is C's static text where a pointer is wanted: `ptr[i8]("text")` is C's
`"text"`, its UTF-8 bytes NUL-ended, and `ptr[u16]("text")` and `ptr[u32]("text")` are C's
`u"text"` and `U"text"`, UTF-16 and UTF-32, NUL-ended. Each is data of the program, made where it
is compiled and never freed. Wide text is made of a literal alone (E1619):

```jac
import from c {
    def memcmp(a: bytes, b: ptr[u16], n: u64) -> i32;
}

with entry {
    wide = ptr[u16]("héllo");
    four = ptr[u32]("ok");
    print(wide[0], wide[1], wide[5], four[0], four[1], four[2]);
    made = ("abc" + str(3) + "\0").encode("utf-16-le");
    print(memcmp(made, ptr[u16]("abc3"), u64(10)));
}
```

```output
104 233 0 111 107 0
0
```

### Variadic functions

`*args: VaList` as the last parameter makes the declaration variadic: C's `...`, which it is
the one way to write. Each extra argument is passed
as C's default promotions pass it: an integer as a 64-bit word, a float as a `double`, a `str`,
`bytes`, `bytearray` or pointer as an address. A function is passed through `...` as C passes a
function pointer there, as the pointer it is: `ptr(f)` (see [Callbacks](#callbacks)). Any other
argument is refused (E1157), a function value as it is among them. A C function takes no
`**kwargs` (E1158).

A parameter typed `VaList` without the star is C's `va_list`: `def vsnprintf(buf: ptr[i8], n: int,
fmt: ptr[i8], ap: VaList) -> i32;` takes the list a function of C's `...` is given.

### Functions of C's variadic arguments

A Jac function defined with `*args: VaList` last takes C's variadic arguments by the C ABI: it
is compiled once, as the C function `int32_t say(const char *fmt, ...)` is, so C calls it through
its module's face ([Calling Jac from C](c-modules.md#calling-jac-from-c)) and Jac calls it as an
imported variadic function, with the same promotions (E1157). In its body `args` is the list:

- `args.next[T]()` reads the next argument as `T`, as C's `va_arg` does. `T` is what C's `...`
  carries after its promotions: `i32`, `u32`, `i64`, `u64`, `int` (C's word), `float` (a
  `double`) or a `ptr`; another type is refused (E1644).
- `args.copy()` is a list at the same place, which reads on apart from `args` (C's `va_copy`).
- `args` given to a parameter typed `VaList`, of a C function or of a Jac one, is C's `va_list`
  passed on.
- The list ends where its scope does, as C's `va_end` ends it.

```jac
import from c {
    def vsnprintf(buf: ptr[i8], n: int, fmt: ptr[i8], ap: VaList) -> i32;
    def calloc(n: int, size: int) -> ptr[i8];
}

def total(n: i32, *args: VaList) -> i64 {
    t = i64(0);
    for i in range(n) {
        t += i64(args.next[i32]());
    }
    return t;
}

def say(buf: ptr[i8], fmt: ptr[i8], *args: VaList) -> i32 {
    return vsnprintf(buf, 64, fmt, args);
}

with entry {
    buf = calloc(64, 1);
    print(total(i32(3), i32(1), i32(2), i32(3)), say(buf, ptr[i8]("%d-%.1f"), i32(7), 1.5));
}
```

```output
6 5
```

Such a function is C's: what it raises reaches no Jac caller, and is reported where it returns
to its caller, as an exception of any Jac function C calls is. A `VaList` is a parameter or a
local of the function that holds it, never a field, a global, a result or an item of a
collection (E1169). Native and wasm; refused on any other host (E5090). This is how `neojac
port` writes a C function defined with `...` ([Porting C](port-c.md)).

C's `printf` writes through the C library's own buffer, which Jac's `print` does not share:
mixing the two can reorder a program's output. Format into a buffer with `snprintf`, as above,
or use `print`.

## Records

An `obj` with fields in an import block is a C `struct`. Its fields are laid out as C lays them
out (same sizes, alignment and padding), and it passes to and from C functions by value with the
platform's C ABI. It is constructed and read as any object is: `div_t(quot=1, rem=2)`,
`d.quot`. Fields left out are zero.

A record's fields are of the types in the table above, other records included. A record has no
bases, methods, static fields or properties (E5090), and cannot contain itself (E1150): link
records through `ptr[T]` fields.

A field of an `obj` or a struct whose type is a C record keeps the record in the object's own
memory, as a C member is, and has a record's value semantics there: reading the field as a value
copies it, a field of it is read and written in place, and assigning the field copies the record
in. `addressof(t.pair)` is the field's own address, good while the object lives, and
`held[T](pair=p)` finds the object back from it
([An object found by a record it keeps](pointers-and-native-memory.md#an-object-found-by-a-record-it-keeps)).
A field typed `Pair | None` holds a reference to a record, not the record.

```jac
import from c {
    obj Pair {
        has a: i32,
            b: f32;
    }
}

obj Tally {
    has n: int,
        pair: Pair,
        last: Pair | None = None;
}

with entry {
    t = Tally(n=1, pair=Pair(a=i32(3)));
    w = t.pair;
    w.a = i32(9);
    t.pair.b = f32(1.5);
    o = Pair(a=i32(5));
    t.last = o;
    o.a = i32(6);
    print(t.pair.a, t.pair.b, w.a, t.last.a if t.last is not None else 0);
    t.pair = o;
    o.a = i32(7);
    print(t.pair.a, o.a);
}
```

```output
3 1.5 9 6
6 7
```

A record C declares packed or aligned is declared so: `@packed`, `@packed(n)` and `@align(n)`
(from `jaclang.comptime`) lay it out as C's `__attribute__((packed))`, `#pragma pack(n)` and
`__attribute__((aligned(n)))` do, as they do a struct's ([Decorators](../language/decorators.md#packed)):

```jac
import from jaclang.comptime { align, packed, sizeof }

import from c {
    @packed
    obj Header {
        has tag: u8,
            size: u32;
    }

    @align(16)
    obj Slot {
        has n: i32;
    }
}

with entry {
    h = Header(tag=u8(7), size=u32(300));
    print(sizeof(Header), sizeof(Slot), h.tag, h.size);
}
```

```output
5 16 7 300
```

An `obj` with no body is an **opaque type**: C knows its layout, the program does not. It has no
size, so it cannot be constructed or held by value (E1151). The program handles it as
`ptr[Name]`:

```jac
import from c {
    obj FILE;

    def tmpfile -> ptr[FILE];
    def fputs(s: str, f: ptr[FILE]) -> i32;
    def rewind(f: ptr[FILE]) -> None;
    def fgetc(f: ptr[FILE]) -> i32;
    def fclose(f: ptr[FILE]) -> i32;
}

with entry {
    f = tmpfile();
    if f.is_null() {
        raise OSError("no temporary file");
    }
    fputs("jac", f);
    rewind(f);
    print(chr(fgetc(f)), chr(fgetc(f)), chr(fgetc(f)), fgetc(f));
    fclose(f);
}
```

```output
j a c -1
```

### Bit-fields and arrays

A width after a field's type makes it a **bit-field**, as C's `unsigned ready : 1;`. Its type is
an integer type, or `bool`, at least that wide (E2263), and its width an integer literal (E0181).
A run of bit-fields packs into units of their type, and one that would cross its unit's end starts
the next, as the Itanium and AAPCS layouts place it. Reading one gives its bits as its type,
sign-extended for a signed type; writing one writes its bits and keeps the rest of its unit,
truncating the value as C does. Only a C record has bit-fields (E2262): a Jac struct's layout is
not C's.

A field of type `array[T, N]`, `T` a number, a pointer, a C record or an array of them, is a C
array in the record, laid out as C lays it out: C's `const char *names[3];` is `names: array[ptr[i8], 3]`. `r.name` is the array in place, so `r.name[0] = v` writes the record's
memory, and assigning the field copies a whole array in.

```jac
import from c {
    obj Flags {
        has ready: u32: 1,
            level: i32: 3,
            code: u32: 30,
            after: u8;
    }

    obj Label {
        has name: array[i8, 16],
            flags: i16,
            extra: array[u32, 2];
    }
}

with entry {
    f = Flags(ready=u32(1), level=i32(-2), code=u32(5));
    f.level = i32(9);
    print(f.ready, f.level, f.code, f.after);
    buf = Label(name=array[i8, 16](), flags=i16(3), extra=array[u32, 2](u32(0), u32(7)));
    buf.name[0] = i8(65);
    print(buf.name[0], buf.extra[1]);
}
```

```output
1 1 5 0
65 7
```

`f.level = i32(9)` keeps 9's low three bits, 1.

An array of pointers holds a machine word for each, as C's does, and one made with no values
holds null pointers:

```jac
import from c {
    obj Names {
        has names: array[ptr[i8], 3],
            count: i32;
    }
}

with entry {
    n = Names(names=array[ptr[i8], 3](), count=i32(1));
    n.names[0] = ptr[i8]("tea");
    print(n.names[0] == ptr[i8](), n.names[2] == ptr[i8](), n.count);
}
```

```output
False True 1
```

An array of C records holds each record in place, laid out as C lays it out, its item's size and
alignment the record's. An item is the record where it lies, as a nested record field is:
`ps.items[2].weight = 4.0` writes the item in the outer record, and `held = ps.items[1]` holds
that item, so writing `held.key` writes it there. A record declared opaque has no size, and an
array of one is refused.

```jac
import from c {
    obj Pair {
        has key: i32,
            weight: f64;
    }

    obj Pairs {
        has count: i16,
            items: array[Pair, 3];
    }
}

with entry {
    ps = Pairs(count=i16(2), items=array[Pair, 3]());
    ps.items[2].weight = 4.0;
    held = ps.items[1];
    held.key = i32(7);
    print(ps.items[2].weight, ps.items[1].key, ps.items[0].key);
}
```

```output
4.0 7 0
```

A C `union` is a Jac `union` ([Structs](../language/structs.md#unions)), declared in an import
block as a record is, and held by value as one is. A union or a record a system header declares
is declared the same way, with the fields of the header's layout:

```jac
import from c {
    union sigval {
        has sival_int: i32,
            sival_ptr: ptr;
    }

    obj lldiv_t {
        has quot: int,
            rem: int;
    }

    def lldiv(a: int, b: int) -> lldiv_t;
}

with entry {
    v = sigval(sival_int=i32(9));
    q = lldiv(47, 5);
    print(v.sival_int, q.quot, q.rem);
}
```

```output
9 9 2
```

### One record across the program

A C record's identity is C's own (C11 6.2.7). Declarations of one tag whose members agree, the
same fields with the same names, widths and types in the same order and the same decorators, are
one type across the program: two modules' `import from c` blocks that declare `stamp` alike name
the same type, and a `stamp` one module's function returns is the `stamp` the other's takes. A
record a [C module](c-modules.md)'s headers declare is the same type as a block's that agrees with
it.

Declarations of one tag that disagree are each their own module's type, as two C files may each
include a header that gives the tag other members (a kernel's header and the C library's, say).
Each module uses its own with its own layout, and the program compiles while the two never meet.
One given where the other is expected is E1001, which names each by its module:

```text
main.jac:25:19: error[E1001]: expected main.stamp, found clock.stamp
```

A declaration with no fields, opaque, agrees with every complete one of its tag behind a pointer,
as an incomplete type does in C: a `ptr[stamp]` of a module that declares `obj stamp;` takes and
gives either module's.

### A record named in Jac other than by its tag

C keeps a record's tag apart from its other names, so a header may declare `struct stat` and the
function `stat` both. In Jac they would be one name. `obj <tag> as <name>` declares the C record
`<tag>` under the Jac name `<name>`: `obj stat as struct_stat { ... }` beside
`def stat(path: str, buf: ptr[struct_stat]) -> i32;`. The record is C's `struct <tag>` in every
way a record is (its layout, one type across the program by its tag), and the program names it
`<name>` alone. Only a C record has a tag: `as` on any other archetype is E2325.

```jac
import from c {
    obj tm as struct_tm {
        has tm_sec: i32,
            tm_min: i32,
            tm_hour: i32,
            tm_mday: i32,
            tm_mon: i32,
            tm_year: i32,
            tm_wday: i32,
            tm_yday: i32,
            tm_isdst: i32,
            tm_gmtoff: int,
            tm_zone: ptr[i8];
    }

    def timegm(t: ptr[struct_tm]) -> int;
}

with entry {
    t = struct_tm();
    t.tm_year = i32(70);
    t.tm_mday = i32(2);
    print(timegm(addressof(t)));
}
```

```output
86400
```

## Passing addresses

A parameter declared `&T` or `&mut T` takes the address of a variable or field of the caller:
the call site writes `&x` or `&mut x`. `T` is C plain data, that is a number, a bool, a pointer
or a C record (E1152). The address is valid for the call only. `modff` and `strtol` above each
write a result through one.

A `ptr[T]` parameter takes a pointer, or `&x` / `&mut x` of a `T` variable, which is its address
for the call. `ptr[T]()` is the null pointer.

Where C keeps the address after the call returns, the storage must not move: use `pin`, or
memory from C's allocator. See [pointers and native memory](pointers-and-native-memory.md).

## Callbacks

A `Callable[[P, ...], R]` parameter or record field is a C function pointer. A named Jac
function of that signature is passed as it is, and C calls it:

```jac
import from c {
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
    def calloc(n: int, size: int) -> ptr[i32];
    def free(p: ptr[i32]) -> None;
}

def descending(a: ptr[i32], b: ptr[i32]) -> i32 {
    return b[0] - a[0];
}

with entry {
    nums = calloc(4, 4);
    nums[0] = 5;
    nums[1] = 30;
    nums[2] = 10;
    nums[3] = 20;
    qsort(nums, 4, 4, descending);
    print(nums[0], nums[1], nums[2], nums[3]);
    free(nums);
}
```

```output
30 20 10 5
```

Only a named function can be a callback as it is, or a static method whose parameters are all
positional with no default, which is the function itself ([Methods](../language/methods.md));
a lambda or a bound method cannot (E1195), and
a `Callable` record field is assigned a named function, `None` or a conversion of a function value
(below). `None` passes `NULL`, which removes a callback where C says so. A `str`
parameter of a callback receives C's `const char *` as a `str`. A callback's signature cannot
take `bytes` or a `bytearray` (C passes no length) (E5090). A function pointer's signature may
take and give a C record by value, passed as C's calling convention passes it: a C function
called through one ([dl](dl.md#calling-an-address)) gets and gives the record as a direct call
does, and so does a Jac function C calls through one. It may take
another callback: a `Callable` parameter inside a function pointer's signature is passed as its C
address, and a Jac function C calls through such a pointer takes it as a function value made from
that address ([below](#a-callback-that-takes-a-callback)). An exception a callback raises does not unwind through C's frames: the callback returns
to C, which runs on, and the exception is raised in the Jac code that called the C function, once
that returns.

A record field of a `Callable` type holds a function pointer, called as a method is:

```jac
import from c {
    obj Measure {
        has scale: i32,
            measure: Callable[[str], int];
    }
}

def tenfold(s: str) -> int {
    return len(s) * 10;
}

with entry {
    m = Measure(scale=2, measure=tenfold);
    print(m.measure("abc") * m.scale);
}
```

```output
60
```

### A callback that takes a callback

A function pointer's signature may hold another: `Callable[[Callable[[int], int], int], int]` is
C's `long (*)(long (*)(long), long)`. A Jac function of that signature given to C takes the inner
callback as a value made from the address C passed, and calls it as C does; a function value passed
the other way goes as its C address.

```jac
import from c {
    obj Table {
        has apply: Callable[[Callable[[int], int], int], int];
    }
}

def negated(n: int) -> int {
    return -n;
}

def twice(f: Callable[[int], int], x: int) -> int {
    return f(f(x)) + 1;
}

with entry {
    t = Table(apply=twice);
    print(t.apply(negated, 5));
}
```

```output
6
```

### A function pointer C gives

A C function's result, or a record's field, may be a function pointer: a `Callable` result is a
function value made from the address C gave, which the program calls, passes back to C and
compares by `ptr(f)`. `signal` gives the handler it replaces:

```jac
import from c {
    def signal(sig: i32, handler: Callable[[i32], None]) -> Callable[[i32], None];
}

def on_term(sig: i32) -> None {
    print("handled", sig);
}

def on_term_again(sig: i32) -> None {
    print("again", sig);
}

with entry {
    signal(i32(15), on_term);
    before = signal(i32(15), on_term_again);
    print(ptr(before) == ptr(on_term));
    before(i32(15));
}
```

```output
True
handled 15
```

### A function pointer that may be null

C's function pointer may be `NULL`, and `Callable[[P], R] | None` says so: a parameter, a result,
a record's field or a variable of that type holds `None` where C's holds `NULL`. Each place C gives
one is tested as it crosses: a result C returns as `NULL`, a field that holds it, a parameter C
passes it to a Jac function as, and `Callable[[P], R](p)` of a null address given to a place of
the `| None` type, are `None`. `ptr(f)` of an `f` that is `None` is the null address, and a call of one that holds `None` raises
`TypeError` (`'NoneType' object is not callable`), as Python's call of `None` does, where a call of
`NULL` stops C's program. Nothing makes a program test it first, though `if f is not None` narrows
it, as for any `T | None`. A
`Callable[[P], R]` place (no `| None`) holds a function value made from the address whatever it
is; calling one made from the null address is undefined, as in C. This is how `neojac port` writes
every C function pointer ([Porting C](port-c.md)): `f != NULL` is `f is not None`.

```jac
import from c {
    obj Duo {
        has a: i32,
            b: i32;
    }

    obj Steps {
        has run: Callable[[Duo], Duo] | None,
            total: Callable[[Duo], i32] | None;
    }

    def signal(sig: i32, handler: Callable[[i32], None] | None) -> Callable[[i32], None] | None;
}

def swapped(p: Duo) -> Duo {
    return Duo(a=p.b, b=p.a);
}

def total(p: Duo) -> i32 {
    return p.a + p.b;
}

with entry {
    op = Steps(run=swapped);
    print(op.total is None);
    try {
        op.total(Duo(a=i32(1), b=i32(1)));
    } except TypeError as e {
        print("TypeError:", e);
    }
    if op.run is not None {
        s = op.run(Duo(a=i32(1), b=i32(2)));
        print(s.a, s.b);
    }
    t: Callable[[Duo], i32] | None = Callable[[Duo], i32](ptr(total));
    if t is not None {
        print(t(Duo(a=i32(3), b=i32(4))));
    }
    gone: Callable[[Duo], i32] | None = Callable[[Duo], i32](ptr());
    print(gone is None, ptr(gone).is_null());
    print(signal(i32(15), None) is None);
}
```

```output
True
TypeError: 'NoneType' object is not callable
2 1
7
True True
True
```

### A pointer to a function pointer

C's `void (**out)(int)`, a place in C memory that holds a function pointer, is
`ptr[Callable[[i32], None] | None]`. Its item, `p[0]`, is read and written as a record's
function-pointer field is: a read gives the function C holds there, or `None` where it holds
`NULL`; a write takes a named function, `None` (C's `NULL`) or `Callable[[P], R](a)` of an
address. The item's type must admit `None`, since C memory may hold `NULL`, and its signature must
be one C has: `ptr[Callable[[i32], i32]]` or `ptr[Callable[[list[int]], int] | None]` indexed is
E1152.

```jac
import from c {
    def malloc(n: u64) -> ptr;
    def free(p: ptr) -> None;
}

import from jaclang.comptime { sizeof }

def tripled(n: i32) -> i32 {
    return n * i32(3);
}

with entry {
    slot = ptr[Callable[[i32], i32] | None](malloc(u64(sizeof(ptr))));
    slot[0] = tripled;
    f = slot[0];
    if f is not None {
        print(f(i32(4)));
    }
    slot[0] = None;
    print(slot[0] is None);
    free(slot);
}
```

```output
12
True
```

`swapped` and `total` take and give the C record `Duo` by value, as C passes it through a
function pointer; `signal` gives `None` for the default handler it replaces, C's `SIG_DFL`.

### Converting a function value

A function converts to another function pointer type, or to a pointer, by calling the type, as a
data pointer converts by `ptr[T](p)`: `Callable[[int], int](f)` of a function `f` is its C
address as a function pointer of that type, and `ptr(f)` (or `ptr[T](f)`) the same address as a
pointer. `Callable[[P], R](p)` of a `ptr` calls the address by the new type, as C's cast does: a
signature that disagrees with the function's is undefined, as in C. Two function pointers are
the same function where their addresses are: `ptr(f) == ptr(g)`.

```jac
import from c {
    obj Op {
        has run: Callable[[int], int];
    }
}

def negated(n: int) -> int {
    return -n;
}

with entry {
    slot = ptr(negated);
    back = Callable[[int], int](slot);
    m = Op(run=Callable[[int], int](negated));
    print(back(4), m.run(5), slot.is_null());
}
```

```output
-4 -5 False
```

`f` may be a named function or a value of a `Callable` type: a variable, a parameter or a record's
field. A value made from a C address (what C passed, what a C record's field holds,
`Callable[[P], R](p)`) gives that address; a named function's value gives the address `ptr(f)` of
its name gives. That is how a function value reaches C, which takes no value as it is (E1195):
its conversion is passed.

```jac
import from c {
    obj Op {
        has run: Callable[[int], int];
    }

    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
    def calloc(n: int, size: int) -> ptr[i32];
    def free(p: ptr[i32]) -> None;
}

def negated(n: int) -> int {
    return -n;
}

def descending(a: ptr[i32], b: ptr[i32]) -> i32 {
    return b[0] - a[0];
}

def sort_by(xs: ptr[i32], n: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) {
    qsort(xs, n, 4, Callable[[ptr[i32], ptr[i32]], i32](cmp));
}

with entry {
    m = Op(run=negated);
    copied = Op(run=Callable[[int], int](m.run));
    nums = calloc(3, 4);
    nums[0] = 5;
    nums[1] = 30;
    nums[2] = 10;
    sort_by(nums, 3, descending);
    print(copied.run(2), nums[0], nums[1], nums[2], ptr(copied.run) == ptr(negated));
    free(nums);
}
```

```output
-2 30 10 5 True
```

A function value with no C address is refused where the compiler sees it, and raises where it
does not: `ptr()` of a lambda written in place is E1195, and a value that reaches the conversion
as it runs raises `TypeError` saying why: a closure that captures variables, a lambda or a bound
method (`ptr(w.m)`), a callable converted from another type, or a function whose parameters or
result C cannot take (a generator, a coroutine, a generic function, a `list` parameter).

```jac
def address(f: Callable[[int], int]) -> ptr {
    return ptr(f);
}

with entry {
    k = 2;
    def scaled(n: int) -> int {
        return n * k;
    }
    try {
        p = address(scaled);
        print("C may call it:", not p.is_null());
    } except TypeError as e {
        print(e);
    }
}
```

```output
a closure that captures variables, or a callable converted from another type, has no C address
```

## Globals

`glob name: T;` in an import block names a variable the library defines (C's `extern T name;`).
The program reads and assigns it in place: after `glob opterr: i32;` in `import from c`,
`opterr` reads getopt's flag.

`glob name: T = value;` in an import block **defines** C data in the program itself, under that
symbol name. A scalar is read and assigned as a variable is. A list literal defines a C array,
which the program reaches through `addressof(name)`, a `ptr[T]` to its first element. The array
is C's storage and not a list, so its name is a value nowhere else (E1153):

```jac
import from c {
    glob limit: i32 = 9;
    glob weights: list[f32] = [1.0, 3.0, 3.0, 5.0, 9.0];
}

with entry {
    limit += 1;
    w = addressof(weights);
    w[2] = 3.5;
    print(limit, addressof(limit)[0], w[2], w[4]);
}
```

```output
10 10 3.5 9.0
```

`addressof(x)` gives the address of a C global or of a C record value, as a `ptr[T]`, and of any
other place of C plain data: a `glob`, a local, a parameter, a field or an item of one
([`addressof`](pointers-and-native-memory.md#addressof)). It takes nothing else (E1154).

- **`glob:priv name: T = value;`** in an import block is C data that is the module's alone, as C's
  `static` at file scope: its symbol is internal and named for the module, so it never meets a
  library's symbol of that name, nor another module's. Without `:priv` the data keeps its C name,
  for the module's C files to use.
- **A `glob` of an opaque record** (`glob first_counter: counter;`, C's `extern counter
  first_counter;`) is bound, and used through its address: `counter_next(addressof(
  first_counter))`. Reading it as a value is E1151, since its size is C's alone.

## Naming the library, and how a program links

What follows `import from` names the library: `z` by the platform's convention, `"libz.so.1"` as
a file, `vendor.raylib` as a library the project provides. How each is found on each platform, and
how a program links the libraries it binds, is in
[Naming and linking a C library](c-libraries-linking.md) (`neojac docs project library`).

## What is rejected

Errors in the declarations:

```jac
# expect: E5090 x2, E1152, E1158, E1155, E1150
import from c {
    obj Link {
        has next: Link,
            value: i32;
    }

    glob table: list[i32] = list(range(4));
    def twice(x: int) -> int {
        return x * 2;
    }
    def total(xs: list[int]) -> int;
    def strlen(s: &str) -> u64;
    def printf(fmt: str, **kwargs: any) -> i32;
}

with entry {
    print("declared");
}
```

Errors in the uses:

```jac
# expect: E1053, E1195, E1157, E1154, E1151, E1153 x2
import from c {
    obj FILE;

    glob table: list[i32] = [1, 2, 3];
    def abs(x: i32) -> i32;
    def printf(fmt: str, *args: VaList) -> i32;
    def qsort(base: ptr[i32], n: int, size: int, cmp: Callable[[ptr[i32], ptr[i32]], i32]) -> None;
}

with entry {
    n = 5;
    print(abs(i64(n)));
    qsort(ptr[i32](), 0, 4, lambda (a: ptr[i32], b: ptr[i32]) -> i32 { return a[0] - b[0]; });
    printf("%d\n", [1, 2]);
    print(addressof([n]));
    f = FILE();
    print(table[2]);
    table = [4, 5, 6];
}
```

| Code | Condition |
|---|---|
| E5090 | A type C cannot take (a list, a dict, a Jac object), a function with a body, a base or method on a record |
| E1150 | A C record contains itself by value |
| E1151 | An opaque C type is constructed or held by value, or a global of one read as a value |
| E0181 | A bit-field's width that is not an integer literal |
| E2262 | A bit-field outside a C record |
| E2263 | A bit-field wider than its integer type, or of a type that is no integer |
| E1152 | A borrow parameter, or `pin()`, of something that is not C plain data |
| E1053 | An argument of another type than the parameter's, an `i64` where an `i32` is declared among them |
| E1153 | A C array's name used as a list: indexed, assigned or passed, where only `addressof()` of it is a value |
| E1154 | `addressof()` of what is no place of C plain data: a value no variable, field or item holds |
| E1155 | A C array defined by anything but a list literal |
| E1157 | A variadic argument that is no C scalar, pointer, `str`, `bytes` or `bytearray` |
| E1158 | A C function declared with `**kwargs` |
| E1195 | A lambda or bound method passed as a callback, or assigned to a `Callable` field of a C record |

`neojac docs E1150` prints any of these with its message. The codes of naming a library
(E5148, E5149, W5021) are in [Naming and linking a C library](c-libraries-linking.md).

## Differences from Python and from the reference design

- In Python, C is reached through `ctypes` or `cffi` objects built as the program runs. Here the
  declarations are compiled: a call is a direct C call with no marshaling layer, and a mistyped
  argument is a compile error.
- `int` is 64 bits. A C `int` is `i32`, not `int`.
