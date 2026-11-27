---
description: ptr[T], a pointer into C memory - indexing, arithmetic, bounds-checked views, pin and Pinned for addresses C keeps, hold, held, held_at and release for Jac objects C keeps, addressof, and load, store and vector for packed, aligned, volatile and streaming accesses.
keywords: ptr, ptr[T], pointer, null pointer, is_null, PtrView, pin, Pinned, hold, held, held_at, user data, addressof, C plain data, native memory, volatile, nontemporal, unaligned access
---
# Pointers and native memory

`ptr[T]` is a pointer into memory that C laid out: what a C function returns, what `malloc`
gives, a field of a C record, a device's registers. It is the type C's `T *` has in a
[C library](c-libraries.md) declaration, and `ptr` alone is C's `void *`.

A pointer is an address and nothing more. It does not own what it points to, the collector does
not follow it, and indexing it is unchecked, as in C. Memory a C function allocated is freed by
the C function that frees it.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}

with entry {
    raw = calloc(64, 1);
    nums = ptr[i32](raw);
    nums[0] = 10;
    nums[1] = 20;
    nums[2] = nums[0] + nums[1];
    print(nums[2], raw[0], raw[4]);
    q = nums + 2;
    print(q[0], q[-1], q - nums, q == nums + 2);
    print(nums.is_null(), ptr[i32]().is_null(), int(nums) == int(raw));
    free(raw);
}
```

```output
30 10 20
30 20 2 True
False True True
```

## What a pointer does

`T`, the item, is C plain data: a number of any sized type, a `bool`, another pointer, a C
record, a plain [struct](../language/structs.md) (one holding no reference), an `array` of
those (C's pointer to an array, `int (*p)[2]`, is `ptr[array[i32, 2]]`: `p[i]` is the array at
the `i`th place, where it is, `p[i][j]` an item of it, and `p + 1` steps by an array's size), or
a C function pointer, `Callable[[P], R] | None` of a signature C has
([A pointer to a function pointer](c-libraries.md#a-pointer-to-a-function-pointer)), or a list of
C's variadic arguments, `ptr[VaList]`, C's `va_list *`
([Functions of C's variadic arguments](c-libraries.md#functions-of-cs-variadic-arguments)). A
pointer to anything else is refused where it is indexed (E1152).

| Expression | Meaning |
|---|---|
| `ptr[T](x)` | `x` as a `ptr[T]`: `x` is an `int` address, another pointer (a cast), or a `str` (the address of its UTF-8 bytes, for as long as the program holds the str) |
| `ptr[T]()`, `ptr()` | The null pointer |
| `p[i]` | The `T` at `p + i`. `i` may be negative. Unchecked |
| `p[i] = v`, `p[i] += v` | Writes the `T` at `p + i`. The index is evaluated once |
| `p + n`, `p - n` | The pointer `n` items on: the address moves by `n` times the size of `T` |
| `p - q` | How many items apart two pointers of one type are, an `int` |
| `p == q`, `p != q`, `p < q`, `p <= q`, `p > q`, `p >= q` | Comparison of the addresses |
| `p.is_null()` | Whether the address is zero |
| `int(p)` | The address |
| `str(p)` of a `ptr[i8]` | A copy of the NUL-ended UTF-8 text at `p`, as a `str`; `ValueError` for the null pointer. `print(p)` and `f"{p}"` give the same text. A pointer of any other item type has no text (E5090) |
| `p.view(n)` | A bounds-checked view of the first `n` items (below) |
| `p.load(i, ...)`, `p.store(i, v, ...)`, `p.vector(i, N)` | An access that says more than `p[i]` (below) |

A value of type `ptr[T]` fits where a bare `ptr` is wanted. A bare `ptr` has no item type, so it
is not indexed or viewed (E1040, E1191, E1199): cast it first, `ptr[u8](p)`.

Reading through a null, freed or out-of-range pointer is undefined, as in C. Nothing checks it.
A pointer a C++ class's member gives into its object, where C++ declares it so (`s.c_str()`, a
member marked `[[clang::lifetimebound]]`), is a loan of the object, which is kept while the
pointer, a copy of it or a pointer computed from it is used
([A pointer into an object](c-modules.md#a-pointer-into-an-object)).

### Records in place

Where `T` is a C record or a plain struct, `p[i]` is the record there, in place: `p[i].x = 1.0`
writes C's memory. Reading `p[i]` into a variable copies the record; `p[i] = r` copies `r` in.
`sizeof(T)`, from `jaclang.comptime`, is the bytes C lays one out in, for the target being built,
as C's `sizeof` is: what to ask `calloc` or `malloc` for (see
[Compile-time values](../language/compile-time-values.md#bits-signed-and-sizeof)).

```jac
import from jaclang.comptime { sizeof }

import from c {
    obj Pair {
        has a: i32,
            b: f32;
    }

    def calloc(n: int, size: int) -> ptr[Pair];
    def free(p: ptr[Pair]) -> None;
}

with entry {
    pairs = calloc(2, sizeof(Pair));
    pairs[1].a = 9;
    pairs[1].b = 2.5;
    kept = pairs[1];
    pairs[1].a = 10;
    pairs[0] = pairs[1];
    print(kept.a, pairs[1].a, pairs[0].a, pairs.view(2)[0].b);
    free(pairs);
}
```

```output
9 10 10 2.5
```

## Views

`p.view(n)` is the `n` items at `p` with their length known: `v[i]` and `v[i] = x` are
bounds-checked (`IndexError`), a negative index counts from the end, and `len(v)` is `n`. The
view reads and writes the same memory the pointer does; it copies nothing.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[f32];
    def free(p: ptr[f32]) -> None;
}

def total(p: ptr[f32], n: int) -> float {
    v = p.view(n);
    acc = 0.0;
    for i in range(len(v)) {
        acc += float(v[i]);
    }
    return acc;
}

with entry {
    p = calloc(4, 4);
    v = p.view(4);
    v[0] = 1.5;
    v[-1] = 2.5;
    print(len(v), p[3], total(p, 4));
    try {
        print(v[4]);
    } except IndexError as e {
        print("IndexError:", e);
    }
    print(bytes(ptr[u8](p).view(4)));
    free(p);
}
```

```output
4 2.5 4.0
IndexError: PtrView index out of range
b'\x00\x00\xc0?'
```

- `bytes(v)` and `bytearray(v)` copy a view of `u8` out of C memory.
- A view is indexed, not iterated: loop over `range(len(v))`.
- A negative length is a `ValueError`, and so is a view of one or more items of a null pointer.
  `ptr[T]().view(0)` is an empty view.
- A view held in a local variable that its function only indexes and measures (`v[i]`,
  `v[i] = x`, `len(v)`) is kept as its pointer and length and allocates nothing. A view passed
  on, returned or stored is an object.

## Addresses C keeps: `pin`

A `&x` or `&mut x` argument lends C the address of a variable for one call. Where C keeps the
address after the call returns (a callback's context, a buffer a library fills later), the
storage must stay where it is. `pin(x)` makes that storage: a cell holding `x` at a stable
address, of type `Pinned[T]`. `T` is C plain data (E1152).

```jac
import from c {
    def time(t: &mut Pinned[int]) -> int;
}

obj Clock {
    has cell: Pinned[int];
}

with entry {
    cell = pin(5);
    print(cell.value);
    cell.value = 9;
    c = Clock(cell=cell);
    now = time(&mut c.cell);
    print(cell.value == now, c.cell.value == now);
}
```

```output
5
True True
```

- `cell.value` reads and assigns what the cell holds.
- A `Pinned[T]` is a reference: `c.cell` and `cell` above are one cell.
- A C declaration takes a pinned cell's address with a `&Pinned[T]` or `&mut Pinned[T]`
  parameter, and the call site passes `&cell` or `&mut cell`.
- The cell lives as long as the program holds it. Keep it in a field or a global for as long as C
  uses the address.

## Objects C keeps: `hold`, `held`, `held_at`, `release`

A C library that calls back often takes a `void *` beside the callback, its user data, and hands
it back on every call. `pin` lends C plain data; `hold` lends it a Jac object:

| Expression | Meaning |
|---|---|
| `hold(x)` | A `ptr`: the address of the object `x`, with one reference to it that C holds. The object stays, at that address, until the reference is released, though nothing in Jac holds it |
| `held[T](p)` | The object at `p`, as a `T`: a reference of Jac's own, for as long as the program uses it. `TypeError` where C holds no object at `p` (null, an address C released, any other address), asked before the object is read, and where it holds one of no class that is or derives from `T` |
| `held[T](f=p)` | The `T` C holds whose field `f`, a C record it keeps in place, is at `p`: the object found by the address of a record inside it. `TypeError` as for `held[T](p)` |
| `held_at(x)` | The address C holds the object `x` at, with no reference of its own: what `hold(x)` gave. `TypeError` where C holds none of `x` |
| `release(p)` | C's reference goes. The object is freed when nothing else holds it. `TypeError` where C holds no object at `p` |

```jac
import from c {
    obj Handler {
        has run: Callable[[ptr, int], int],
            data: ptr;
    }

    def calloc(n: int, size: int) -> ptr[Handler];
    def free(p: ptr[Handler]) -> None;
}

obj Tally {
    has total: int = 0;

    def __del__ {
        print("tally freed at", self.total);
    }
}

def add(data: ptr, n: int) -> int {
    t = held[Tally](data);
    t.total += n;
    return t.total;
}

def register(h: ptr[Handler]) {
    h[0].run = add;
    h[0].data = hold(Tally());
}

with entry {
    h = calloc(1, 16);
    register(h);
    print(h[0].run(h[0].data, 5), h[0].run(h[0].data, 7));
    print(held[Tally](h[0].data).total);
    release(h[0].data);
    print("released");
    free(h);
}
```

```output
5 12
12
tally freed at 12
released
```

- `x` is a counted object: an instance of an `obj`, `node`, `edge` or `walker`. A number, a
  struct or a C record is refused (E1635), and so is a struct or a C record as `held`'s `T`.
- Each `hold` is one reference of C's, and each is released once. `held` leaves C's reference as
  it is: it may be called on the same address any number of times, and `release` after the last.
- While C holds it, the object is a root of the cycle collector: a cycle one of whose objects C
  holds stays whole until `release`.
- `hold`, `held`, `held_at` and `release` keep C's holds in one table the program shares, which
  another thread may be changing, so a `Shared` class's method may call none of them (E1541):
  take the object back with `held` before its threads start. A `flow for` whose body calls one
  runs its chunks one after another on the calling thread
  ([When it runs in order](../language/flow-for.md#when-it-runs-in-order)).
- Only native code has addresses: in a cpython, node, browser or hermes space each of them is
  refused (E1540, "native memory").

`held_at` is for an object C holds from where it gets it to where it lets it go, as a C++ object is
held from its `new` to its `delete`: the program keeps the object as a Jac reference and gives C
its address each time, with no new reference, and releases it once at the end. This is how
`neojac port` writes a C++ class whose objects' addresses go to C ([Porting C++](port-cxx.md)).

```jac
obj Hub {
    has name: str;

    def __del__ {
        print("hub freed:", self.name);
    }
}

def lifetime {
    hub = held[Hub](hold(Hub(name="main")));
    p = held_at(hub);
    print(held[Hub](p).name, held_at(hub) == p);
    release(held_at(hub));
    print("C holds it no more");
    try {
        release(p);
    } except TypeError as e {
        print("TypeError:", e);
    }
}

with entry {
    lifetime();
    try {
        held_at(Hub(name="loose"));
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
main True
hub freed: main
C holds it no more
TypeError: release() of an address C holds no object at
TypeError: held_at() of a Hub C does not hold
hub freed: loose
```

The object is freed at the `release`: the local `hub` is not used after it.

### An object found by a record it keeps

A C library often takes the address of a record of its own and hands that address back, where the
program wants the object the record belongs to: C's subclassing by first member, where a library's
record (a table of callbacks, a cursor) heads a structure that carries the program's own state
after it. A field of an `obj` whose type is a C record is kept in the object's own memory, as a C
member is, so it has an address: `addressof(x.f)`, good while the object lives. `held[T](f=p)` takes
that address back to the object.

```jac
import from c {
    obj Pair {
        has a: i32,
            b: f32;
    }
}

obj Tally {
    has n: int,
        pair: Pair;
}

def bump(q: ptr[Pair]) -> int {
    t = held[Tally](pair=q);
    t.n += int(q[0].a);
    return t.n;
}

with entry {
    t = Tally(n=4, pair=Pair(a=i32(3)));
    p = hold(t);
    q = addressof(t.pair);
    print(bump(q), bump(q), held[Tally](pair=q) is t);
    release(p);
    try {
        held[Tally](pair=q);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
7 10 True
TypeError: held[Tally]() of an address C does not hold
```

- `f` must be a field of `T` whose type is a C record, and `p` a `ptr` of that record's type.
  Check proves both (E1638): a bare `ptr` C handed back is cast first, `ptr[Pair](p)`.
- C must hold the object (`hold`), as for `held[T](p)`: C's holds are asked before anything is
  read, and an address of no object C holds, a released one included, is `TypeError`.
- This is how `neojac port` writes a C++ cast between a class's pointer and the pointer to the C
  record that is its first member ([Porting C++](port-cxx.md)).

## `addressof`

`addressof(place)` is the address of a place that holds C plain data, as a `ptr[T]`, `T` the
place's type. A place is:

- a `glob`, a C global of an import block among them;
- a local variable or a parameter;
- a field of a place: `addressof(p.x)` of a struct `p`, a C record's field wherever the record is,
  and a field of an `obj` whose type is a C record, a struct or an array, kept in the object's own
  memory (`addressof(t.pair)`, [An object found by a record it keeps](#an-object-found-by-a-record-it-keeps));
- an item of an `array` place, `addressof(a[i])`, or of a pointer, `addressof(p[i])`.

`T` is C plain data, as a pointer's item is ([What a pointer does](#what-a-pointer-does)): a sized
number, `int`, `float`, `bool`, a pointer, a C record, a plain struct, a union, or an `array` of
those. Of an `array[T, N]` place, and of a C array an import block defines, it is a `ptr[T]` to the
first item. A place that holds C's function pointer, a struct's or a C record's `Callable` field
or an item of an `array[Callable[[P], R] | None, N]`, gives a `ptr[Callable[[P], R] | None]`
([A pointer to a function pointer](c-libraries.md#a-pointer-to-a-function-pointer)); a variable
of a `Callable` type holds a function value, which is no C data.

```jac
import from c {
    def memset(p: ptr, c: i32, n: int) -> ptr;
}

struct Point {
    has x: f32 = f32(0.0),
        n: i32 = i32(0);
}

glob calls: i32 = i32(0);

def bump(p: ptr[i32]) {
    p[0] = p[0] + i32(1);
}

with entry {
    n: i32 = i32(41);
    bump(addressof(n));
    bump(addressof(calls));
    pt = Point(x=f32(1.5), n=i32(2));
    bump(addressof(pt.n));
    xs = array[i32, 3](i32(1), i32(2), i32(3));
    bump(addressof(xs[1]));
    first = addressof(xs);
    first[2] = i32(30);
    memset(addressof(n), 0, 4);
    print(n, calls, pt.n, xs[1], xs[2]);
}
```

```output
0 1 3 3 30
```

- **The place and the pointer are one memory.** A write through the pointer is what the name reads
  next, and a write to the name is what the pointer reads.
- **The pointer is good while the place lives**, as in C: a `glob` for the whole run, a local or a
  parameter until its function returns, a field or an item while what holds it lives. Nothing
  checks it, as nothing checks any `ptr`.
- **Native and wasm.** On a JavaScript or CPython host, whose memory is not laid out as C's, it is
  E5090, as a union is.
- **A local whose memory is no frame of C's** is refused (E5090): a local of a generator or of an
  async function, whose frame lives apart from the stack, a local a closure captures, which a cell
  of its own holds, and a variable of a small float type (`f16`, `bf16`, the 8- and 4-bit ones),
  which Jac holds widened to a float.

It takes nothing else (E1154): a value no variable, field or item holds (`addressof(f())`), an
item of a `list` or a field of an `obj` of a type Jac lays out, a bit-field, a `str`, an object, a
function, a variable of a `Callable` type.
[C libraries](c-libraries.md) shows it with a C global.

## Accesses that say more: `load`, `store`, `vector`

`p.load(i, ...)` and `p.store(i, v, ...)` reach the `T` at `p + i` as `p[i]` does, and state more
about the access in keywords, each known at compile time.

| Keyword | Meaning |
|---|---|
| `align=n` | The address is a multiple of `n`, a power of two up to 2**32. `p[i]` assumes `T`'s natural alignment. `align=1` reads and writes packed data at any byte. A larger value promises more, which the optimizer may use for wider moves; an address that is not so aligned is undefined, as in C |
| `volatile=True` | The access is performed exactly as written, in order with the other volatile accesses: for memory-mapped I/O |
| `nontemporal=True` | `store` only: the store streams past the caches, for data the program will not read again soon |

`T` is a number, a bool or a pointer; a C record or a struct is reached through `p[i]` (E1467).
A `load` or `store` with none of the keywords is `p[i]`, and is refused in its favor (E1466).

`p.vector(i, N)` reads the `N` items from `p + i` as a `simd[T, N]`, and `p.store(i, v)` of a
vector `v` writes its lanes there. They are what a tensor's `t.vector` and `t.store` are, but
unchecked, as `p[i]` is. Each is one access of the whole vector, aligned as one `T` is (so a
`ptr[u8]`'s vector may be at any byte) unless `align=` says more, and takes the same keywords.
`T` is a vector's lane type, an int or float type (E1410), and `N` a power of two from 2 to 64
(E1411). Vectors are described in the accelerated-computing pages: `neojac docs simd`.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[u8];
    def aligned_alloc(align: int, size: int) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}

with entry {
    # Packed data: a u16 and a u32 at odd bytes.
    pk = calloc(16, 1);
    ptr[u16](pk + 1).store(0, u16(0x1234), align=1);
    ptr[u32](pk + 3).store(0, u32(0x12345678), align=1);
    print(ptr[u16](pk + 1).load(0, align=1), ptr[u32](pk + 3).load(0, align=1), pk[1], pk[2]);
    # Vectors: four bytes at an odd address, and two u32s.
    for k in range(16) {
        pk[k] = u8(k);
    }
    print(pk.vector(3, 4), ptr[u32](pk + 1).vector(0, 2));
    pk.store(0, pk.vector(8, 4));
    print(pk[0], pk[3]);
    free(pk);
    # Over-aligned memory, a streaming store and a volatile access.
    al = aligned_alloc(64, 128);
    d = ptr[f64](al);
    d.store(0, 0.25, align=64, nontemporal=True);
    reg = ptr[u32](al + 64);
    reg.store(0, u32(1), volatile=True);
    print(d.load(0, align=64), reg.load(0, volatile=True));
    free(al);
}
```

```output
4660 305419896 52 18
[3, 4, 5, 6] [67305985, 134678021]
8 11
0.25 1
```

Typical uses:

| Access | For |
|---|---|
| `ptr[u32](frame + 3).load(0, align=1)` | A `u32` at an odd byte of a packet |
| `out.store(i, v, align=64, nontemporal=True)` | A streaming store into a large output buffer |
| `ptr[u32](mmio).load(0, volatile=True)` | A device register |
| `ptr[u8](data).vector(i, 16)` | 16 bytes at any address |

## Below pointers: the raw memory intrinsics

Native code also has intrinsics that work on an address held as an `int`: loads and stores of
each width, stack memory (`__alloca`), the address of a value or of its data, thread-local cells
and a float's bits. They are for an address a C library hands over as a plain integer, and for
code that needs exactly one machine operation. See
[Raw memory intrinsics](pointers-and-native-memory-intrinsics.md) (`neojac docs intrinsic`); the
atomic ones are in [Atomic integers](../language/numbers-atomics.md).

## What is rejected

```jac
# expect: E1040, E1191, E1199, E1152 x2, E1001, E1465, E1052, E1466, E1467, E1410, E1411, E1635 x2, E1638, E1154 x2
import from c {
    obj Pair {
        has a: i32,
            b: f32;
    }

    def calloc(n: int, size: int) -> ptr[u8];
    def malloc(n: int) -> ptr;
}

obj Box {
    has v: int = 0;
}

with entry {
    bare = malloc(8);
    print(bare[0]);
    bare[0] = 1;
    print(len(bare.view(1)));
    boxes = ptr[Box](calloc(1, 8));
    print(boxes[0]);
    boxes[0] = Box();
    f = ptr[f32](calloc(4, 4));
    f[0] = "x";
    print(f.load(0, align=3));
    print(f.load(0, nontemporal=True));
    f.store(0, 1.0);
    pairs = ptr[Pair](calloc(2, 8));
    print(pairs.load(0, align=4));
    print(ptr[bool](calloc(4, 1)).vector(0, 4));
    print(f.vector(0, 3));
    lent = hold(5);
    held[Pair](bare);
    held[Box](v=bare);
    names = ["a"];
    print(addressof(names[0]), addressof(len(names)));
}
```

| Code | Condition |
|---|---|
| E1040, E1191 | Indexing or assigning through a bare `ptr` |
| E1199 | A view of a bare `ptr` |
| E1152 | An item that is not C plain data: `ptr[Box]` of a Jac object, `pin()` of a list |
| E1001 | A value of another type than the item's stored through the pointer |
| E1465 | An alignment that is not a compile-time power of two, at most 2**32 |
| E1052 | A keyword the access does not take: `nontemporal=` on a `load` |
| E1466 | `load` or `store` with no keyword |
| E1467 | `load` or `store` of a C record or a struct |
| E1410, E1411 | A vector of something that is no int or float type, or of a length that is not a power of two from 2 to 64 |
| E1154 | `addressof()` of what is no place of C plain data: a call's value, an item of a `list`, a field an `obj` lays out |
| E1635 | `hold()` of what is no counted object, or `held[T]` of a `T` that is none: `hold(5)`, `held[Pair](p)` |
| E1638 | `held[T](f=p)` where `f` is no C record field `T` keeps in place, or `p` no `ptr` to that record: `held[Box](v=bare)` |

## Differences from Python and from the reference design

- Python has no pointer type; `ctypes` pointers are objects that check and convert on every
  access. A `ptr[T]` is a machine address, and `p[i]` compiles to one load.
- A `ptr[T]` is not a reference the language tracks: the ownership rules (`neojac docs
  ownership`) do not apply to what it points at, and nothing frees it for the program.
