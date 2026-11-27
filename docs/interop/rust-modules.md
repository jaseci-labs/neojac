---
description: Rust crates as modules of a Jac program - what a crate's interface gives Jac, Rust's own API used natively (std's types, a crate's items, generics, enums, traits a Jac struct conforms to, closures, panics, drops), calling back into Jac and C, how crates are compiled, cached and linked into the one binary, and what goes wrong.
keywords: Rust module, crate, Cargo.toml, extern "C", no_mangle, repr(C), native Rust import, std.collections, RustPanic, slice_bytes, slice_str, Slice, Rust slice, Rust iterator, rust.Result, Rust trait, Rust enum, Rust closure, .cargo/config.toml, CARGO_INCREMENTAL, RUSTFLAGS, CARGO_ENCODED_RUSTFLAGS
---
# Rust modules

A directory holding a `Cargo.toml` is a Rust module: a crate that a program compiles with it and
imports as it imports a [C module](c-modules.md). In a project (a directory with a `jac.toml`) the
manifest is a table of `jac.toml`, `[cargo."<directory>"]`, which neojac writes as that file:
`neojac absorb <directory>` takes an existing one in ([Packages](../toolchain/packages.md#rust-crates-c-modules-and-python-projects)). `neojac build` compiles the crate, with its
dependencies, build scripts and procedural macros, and links it all into the one binary.

## The shortest example

`adder/Cargo.toml`:

```toml
[package]
name = "adder"
version = "0.1.0"
edition = "2024"
```

`adder/src/lib.rs`:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn add(a: i64, b: i64) -> i64 {
    a + b
}
```

`main.jac`, beside `adder/`:

<!-- example: not checked: needs the Rust crate adder beside the program -->
```jac
import from adder { add }

with entry {
    print(add(2, 3));
}
```

```sh
neojac build main.jac -o main && ./main      # prints 5
```

No Rust needs installing: the toolchain carries cargo and rustc (see [Rust](rust.md),
`neojac docs Rust`). A crate in a subdirectory is named by its dotted path (`ws.ffi` for
`ws/ffi/Cargo.toml`), as any module is.

## What a crate gives Jac

A crate's interface is what rustdoc reads of it, in the types a [C library](c-libraries.md#types-in-a-declaration)
declaration takes:

| Rust | Jac |
|---|---|
| `#[unsafe(no_mangle)] pub extern "C" fn` | A function. `i64` is `int`, `u64` is `u64`, `i32` is `i32`, `f64` is `float`, `*const c_char` is `str`, another `*const T` / `*mut T` is `ptr[T]` (which also takes `&x`), an `extern "C" fn` pointer a `Callable` |
| `#[unsafe(no_mangle)] pub static` (or `static mut`) | A global, read in place |
| `#[repr(C)] pub struct` | A record, constructed by keyword and passed by value |
| Any other `pub struct` | An opaque type, held as `ptr[T]` |
| `pub const` of an integer type | An `int` constant |
| A `#[repr(i32)]` (or other integer) `enum`'s variants | `int` constants named as the variants |

```rust
use std::ffi::CStr;
use std::os::raw::c_char;

pub const ADDER_LIMIT: i32 = 41;

#[repr(i32)]
pub enum Color {
    Red = 1,
    Blue = 2,
}

#[repr(C)]
pub struct Pair {
    pub left: i64,
    pub right: f64,
}

pub struct Tally {
    seen: Vec<i64>,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn text_length(s: *const c_char) -> usize {
    unsafe { CStr::from_ptr(s) }.to_bytes().len()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn pair_sum(p: Pair, q: *const Pair) -> f64 {
    p.left as f64 + p.right + unsafe { (*q).right }
}

#[unsafe(no_mangle)]
pub extern "C" fn apply(f: extern "C" fn(i64) -> i64, x: i64) -> i64 {
    f(x) + 1
}

#[unsafe(no_mangle)]
pub extern "C" fn tally_new() -> *mut Tally {
    Box::into_raw(Box::new(Tally { seen: Vec::new() }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tally_add(t: *mut Tally, x: i64) {
    unsafe { &mut *t }.seen.push(x);
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tally_sum(t: *const Tally) -> i64 {
    unsafe { &*t }.seen.iter().sum()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tally_free(t: *mut Tally) {
    drop(unsafe { Box::from_raw(t) });
}

#[unsafe(no_mangle)]
pub static mut ADDER_COUNTER: i32 = 7;
```

<!-- example: not checked: needs the Rust crate adder beside the program -->
```jac
import from adder {
    ADDER_COUNTER,
    ADDER_LIMIT,
    Blue,
    Pair,
    apply,
    pair_sum,
    tally_add,
    tally_free,
    tally_new,
    tally_sum,
    text_length,
}

def tripled(x: int) -> int {
    return x * 3;
}

with entry {
    print(ADDER_LIMIT, Blue, ADDER_COUNTER);
    print(text_length("héllo"), apply(tripled, 4));
    p = Pair(left=1, right=0.5);
    print(pair_sum(p, &p));
    t = tally_new();
    tally_add(t, 4);
    tally_add(t, 38);
    print(tally_sum(t));
    tally_free(t);
}
```

```text
41 2 7
6 13
2.0
42
```

A public item the interface cannot express is left out, and importing it says why (E5138): a
`pub fn` that isn't `extern "C"` (`it isn't extern "C"`), one without a fixed name, one whose
types C cannot pass. Through `extern "C"`, Rust's own types (`String`, `Vec`, generics, methods) do not cross; use
them natively ([below](#rusts-own-api-natively)), or keep them behind an opaque handle as `Tally`
is above.

## Rust's own API, natively

A program also uses Rust as Rust declares it, with no `extern "C"`: rustc reads the items, and
each call goes through a shim it compiles.

- **`import from std.collections { BinaryHeap }`** names a Rust item by its path, for `std`,
  `core` (written through `std`) and `alloc`, anywhere. A module of the program of that name
  wins over the crate.
- **A crate's ordinary public items** (functions, structs and their methods, enums) are imported
  through a wire from the crate, or an import where the project has no `archwire.jac`. A Jac
  file inside a crate names the crate's dependencies by their Rust paths
  (`import from adder { Bag }`), and a file outside it does not.
- **An item the crate gives as its own** (`pub use dep::{el, Element}`) is one of its items, and
  is the dependency's: `Element` is one class whichever crate it is imported from. A value of
  a type one of the crate's dependencies defines (`pub fn color() -> dep::Color`) is that type's,
  with its methods, though the program names the crate alone. Two crates of one name (two
  versions of one package) give two types.
- **A generic is instantiated by its arguments**: `Vec[u32].new()`, `Stack[u32]`,
  `Option[Ordering].Some(o)`. An argument is a Rust type, a number type, a tuple of numbers
  (`Vec[tuple[u64, u32]]`, which crosses as a Jac tuple), or a struct of the program whose fields
  are all numbers, which Rust sees as a `#[repr(C)]` copy of it.
- **What crosses**: numbers and `bool` as they are; a `char` as a `str` of one code point (a
  surrogate given where Rust takes one is a panic, `RustPanic`), `Option<char>` as `str | None`;
  a tuple result may hold chars and `Option`s of numbers and chars (`(Option<char>, usize)` is
  `tuple[str | None, u64]`); `&str` as a `str`, whole, a NUL in it included (a `&str` a
  function returns that holds `"a\0b"` is `'a\x00b'`, of length 3), `&[u8]` as `bytes`; Rust's
  own values (`String`, `Vec`, a crate's struct) as owned Jac objects, which Rust drops when Jac
  lets them go. A parameter Rust takes by value moves the object, and leaves the Jac object
  empty. `v[i]` reads and writes through `Index<usize>`; a field of an element is not a place
  (E1504), so `e = v[i]; e.x = 1; v[i] = e;`.
- **A type that implements `Default`** has `default()`, its static: `String.default()`,
  `HashMap[K, V, S].default()` for a map with a hasher of its own, which has no `new`.
- **An enum** is a class whose variants are its values: `Ordering.Less`, `o.reverse()`,
  `o == Ordering.Less`; it prints as `Ordering.Less`.
- **A trait** is an interface a Jac struct conforms to: listed as a base, its methods written in
  Jac (`cmp`, `eq`), which Rust calls. `BinaryHeap[Job]` orders the program's `Job`s by its `cmp`.
- **A closure** Rust calls before it returns (`then_with`, `map`) is a Jac lambda, and an exception
  it raises passes out through Rust to the Jac that called it.
- **A closure Rust keeps** (`pub fn new(f: impl Fn(i64) -> i64 + 'static) -> Hook`, which the
  `Hook` holds and calls whenever it is fired) is a Jac lambda too, given to a method or to a
  function. It lives, with what it captured, until Rust drops what holds it, as a closure a Jac
  value keeps does. An exception it raises passes out through Rust to the Jac whose call into
  Rust was running it (`hook.fire(3)`). One that captured a borrow and is called once the
  borrow's owner is gone raises `RustPanic`.
- **A closure Rust may call on a thread of its own** (one bounded by `Send` or `Sync`) is not
  given: a program's Jac runs on the threads the program starts. The method or function that
  takes it is left out, and a call of it says so (E5138).
- **A panic** is the Jac exception `RustPanic`, of `import from rust { RustPanic }`.
- **A value whose drop runs code** (rustc's significant drop: a guard, a lock, a collection) is
  dropped where its `own` owner's scope ends, as Rust drops it. A local or a field with no
  ownership annotation is a managed place, which shares it and drops it when its last reference
  goes; an `own` binding takes it only from where it is made, not from such a place (E1637;
  [Ownership](../language/ownership.md#values-whose-drop-runs-code-dropped-where-their-scope-ends)).

```jac
import from rust { RustPanic }
import from std.cmp { Eq, Ord, Ordering, PartialEq, PartialOrd }
import from std.collections { BinaryHeap }
import from std.option { Option }
import from std.vec { Vec }

def order_of(a: u32, b: u32) -> Ordering {
    if a < b {
        return Ordering.Less;
    }
    return Ordering.Greater if a > b else Ordering.Equal;
}

"""A job, ordered by its rank, the lowest first."""
struct Job(Ord, PartialOrd, Eq, PartialEq) {
    has start: u32 = 0,
        rank: u32 = 0;

    def cmp(other: &Job) -> Ordering {
        return order_of(other.rank, self.rank).then(order_of(other.start, self.start));
    }

    def partial_cmp(other: &Job) -> Option[Ordering] {
        return Option[Ordering].Some(self.cmp(other));
    }

    def eq(other: &Job) -> bool {
        return self.start == other.start and self.rank == other.rank;
    }
}

with entry {
    heap: own BinaryHeap[Job] = BinaryHeap[Job].new();
    heap.push(Job(start=u32(0), rank=u32(3)));
    heap.push(Job(start=u32(2), rank=u32(1)));
    heap.push(Job(start=u32(1), rank=u32(1)));
    order: list[str] = [];
    while not heap.is_empty() {
        j = heap.pop().unwrap();
        order.append(f"{j.start}/{j.rank}");
    }
    print(order);
    o = Ordering.Less;
    print(o.reverse(), Ordering.Equal.then_with(lambda -> Ordering { return o; }));
    pairs: own Vec[tuple[u64, u32]] = Vec[tuple[u64, u32]].new();
    pairs.push((u64(3), u32(7)));
    pairs[0] = (u64(4), u32(8));
    print(pairs.len(), pairs[0]);
    try {
        Vec[u32].new().pop().unwrap();
    } except RustPanic as e {
        print("panic:", e);
    }
}
```

```output
['1/1', '2/1', '0/3']
Ordering.Greater Ordering.Less
1 (4, 8)
panic: called `Option::unwrap()` on a `None` value
```

### Keys, references to numbers and ranges

- **A method generic over the borrowed form of a key** (`HashMap::get<Q>`, `contains_key`,
  `remove`) is bound once, with `Q` the key's `Deref` target: a `Vec<u8>` key is looked up by
  `bytes` (`[u8]`), a `String` key by a `str`, and a key with no `Deref` target by the key
  itself. Jac has no overloading, so this one instance stands for those Rust makes per call.
- **A map is indexed by the same form**: `ranks[b"ab"]` is Rust's `ranks[&b"ab"[..]]`, through
  `Index<&Q>`, and panics where the key is missing, as Rust's does. A map keyed by a number is
  indexed by the number: `decoder[u32(1)]` is Rust's `decoder[&1]`, the item lent by the map.
- **A shared reference to a number crosses as the number**: `Option<&u32>` is `Option[u32]`, the
  number copied, as Rust's own `.copied()` gives it.
- **A range of a slice or a `str`** is a function of `rust`: `slice_bytes(b, start, end)` and
  `slice_bytes_from(b, start)` for `&b[start..end]` and `&b[start..]`, `slice_str` and
  `slice_str_from` for a `&str`, whose bounds are UTF-8 byte offsets. Each panics where Rust
  panics (a bound past the end, reversed bounds, a bound inside a character), where Jac's slicing
  would clamp: `neojac port` writes them for Rust's ranges.

```jac
import from rust { RustPanic, slice_bytes, slice_str_from }
import from std.collections { HashMap }
import from std.string { String }
import from std.vec { Vec }

with entry {
    ranks: own HashMap[Vec[u8], u32] = HashMap[Vec[u8], u32].new();
    key: own Vec[u8] = Vec[u8].new();
    key.push(u8(97));
    key.push(u8(98));
    ranks.insert(key, u32(7));
    print(
        ranks.get(b"ab").unwrap(),
        ranks.get(b"zz").is_none(),
        ranks.contains_key(b"ab"),
        ranks[b"ab"],
    );
    names: own HashMap[String, u32] = HashMap[String, u32].new();
    ann: own String = String.new();
    ann.push_str("ann");
    names.insert(ann, u32(3));
    print(names.get("ann").unwrap(), names["ann"]);
    decoder: own HashMap[u32, Vec[u8]] = HashMap[u32, Vec[u8]].new();
    word: own Vec[u8] = Vec[u8].new();
    word.push(u8(122));
    decoder.insert(u32(1), word);
    print(decoder[u32(1)].len(), decoder.contains_key(u32(1)));
    print(slice_bytes(b"hello", u64(1), u64(3)), slice_str_from("héllo", u64(3)));
    try {
        slice_str_from("héllo", u64(2));
    } except RustPanic as e {
        print("panic:", e);
    }
}
```

```output
7 True True 7
3 3
1 True
b'el' llo
panic: byte index 2 is not a char boundary; it is inside 'é' (bytes 1..3) of `héllo`
```

### Slices, iterators and generic methods

- **A slice of numbers, `&[T]`, is `rust`'s `Slice[T]`**: `def total(s: Slice[u32])` takes one,
  `v.as_slice()` gives a `Vec`'s, and `s.sub(a, b)` and `s.sub_from(a)` are `&s[a..b]` and
  `&s[a..]`, which panic where Rust's ranges panic. `s[i]` reads an item by a `u64` index,
  `s.len()`, `is_empty()` and `to_vec()` are `[T]`'s own; a slice is never written through. It
  borrows what it is a slice of, so it is a value that borrows (below): a parameter or a local,
  and its `Vec` is not changed while it is used (E1302). `Slice[u8]` names `&[u8]` as a type
  argument; a parameter of type `&[u8]` takes a Jac `bytes`, and `bytes(s)` of a `Slice[u8]`
  copies its bytes out into a Jac `bytes`.
- **A slice's methods are a `Vec`'s**, as Rust reaches them through `Deref`: `v.sort()`,
  `v.contains(&x)`, `v.starts_with(b)`, `v.to_vec()` of a `Vec[u8]`.
- **An iterator of a Rust type has `next()`**, which gives an `Option` of its item: a loop steps
  it as Rust's `for` does, `while True { got = it.next(); if got.is_none() { break; } ... }`.
  An item borrows what the iterator borrows (a `HashMap`'s `iter()`, `keys()` and `values()`,
  a `Vec`'s `iter()`), not the iterator: `next` lends the iterator for its call alone, so the
  loop steps it again while an item lives, and the collection is not changed while either is
  used (E1302). An item that is a reference to a number, or a tuple of them (a `HashMap[u32,
  u32]`'s `(&u32, &u32)`), is copied to the numbers. A tuple holding a reference to another
  crate's value among them (a `HashMap[Vec[u8], u32]`'s item) is `tuple[&Vec[u8], u32]`: the
  `Vec` lent, the number copied, and each item unpacked from it borrows as the tuple does.
- **A `Vec` of another crate's values lends its item by index**: `v[i]` is Rust's `&v[i]`
  (`Index::index`, its panic past the end), a borrow of `v`, which is not changed while the item
  is used (E1302). A `Vec` of numbers gives the number.
- **A type parameter that is the type of an argument is taken from the argument**, of a method
  and of a function alike: `e.label("title")` calls `pub fn label(self, s: impl Into<String>)`,
  or `label<S: Into<String>>(self, s: S)`, with `&str`, and `e.label(owned)` with a `String`,
  moved. The argument's Jac type says which Rust type: a `str` is `&str` and `bytes` is `&[u8]`,
  lent for the call; `int` is `i64`, `float` is `f64`, a `bool` is `bool`, and a sized number is
  its own type (`u8(2)` is `u8`); a value of a Rust type is that type. An argument of a type the
  parameter's bounds do not hold for (`counter.add_any("three")` of an `N: Into<u32>`) is E1625.
- **A type parameter no argument is the type of is named at the call**:
  `o.zip[u32](p)`, `re.find_iter[str](text)`. A type argument is a number type or `str`, which
  names Rust's `str` (`Matches[str]`). Each instance a program names is made for it, as a C++
  member template's is. Called with no type named, such a method is E5138, which says that the
  call names it.
- **A function of another crate generic over its input is called both ways too**:
  `loudly("quiet")` gives a `pub fn loudly(s: impl AsRef<str>)` its `&str`, and
  `decode_last_utf8[Slice[u8]](b)` calls `bstr`'s
  `decode_last_utf8::<&[u8]>`, and `size_of[u32]()` std's `size_of::<u32>`. A function imported
  under another name is named so (`import from std.cmp { max as larger }`, `larger[u32](u32(3),
  u32(7))` is 7). The instance is asked of rustc as the module is read, and what it lends and
  keeps is judged on the instance: only an input whose type there holds a borrow is lent, and
  only where the result holds one is it kept, so `max[u32]` of two numbers borrows nothing. One
  whose bounds do not hold for its type arguments (`size_of[str]()`: Rust's `str` has no size) is
  E1625. A Rust function is named only through an import of it: a module's dotted path
  (`std.cmp.max`) is not a form for a Rust module (W1100).
- **`rust.char_is_whitespace(c)`** is Rust's `char::is_whitespace`: whether `c` has Unicode's
  White_Space property, as Rust's table gives it. Python's `isspace` also counts U+001C to U+001F,
  which are not White_Space: `char_is_whitespace("\x1c")` is `False` where `"\x1c".isspace()` is
  `True`. `neojac port` writes it for a `char`'s `is_whitespace()`.

```jac
import from rust { RustPanic, Slice }
import from std.option { Option }
import from std.vec { Vec }

def total(s: Slice[u32]) -> int {
    t = 0;
    for k in range(int(s.len())) {
        t += int(s[u64(k)]);
    }
    return t;
}

def main {
    v: own Vec[u32] = Vec[u32].new();
    for n in [4, 5, 6, 7] {
        v.push(u32(n));
    }
    print(
        total(v.as_slice()),
        total(v.as_slice().sub_from(u64(1))),
        total(v.as_slice().sub(u64(1), u64(3))),
    );
    steps = v.iter();
    seen: list[int] = [];
    while True {
        got = steps.next();
        if got.is_none() {
            break;
        }
        seen.append(int(got.unwrap()));
    }
    print(seen, Option[u32].Some(u32(2)).zip[u32](Option[u32].Some(u32(3))));
    try {
        v.as_slice().sub(u64(3), u64(9));
    } except RustPanic as e {
        print("panic:", e);
    }
}

with entry {
    main();
}
```

```output
22 18 11
[4, 5, 6, 7] Some((2, 3))
panic: range end index 9 out of range for slice of length 4
```

```jac
import from std.collections { HashMap }
import from std.vec { Vec }

def main {
    m: own HashMap[u32, u32] = HashMap[u32, u32].new();
    m.insert(u32(1), u32(10));
    m.insert(u32(2), u32(20));
    total = 0;
    it = m.iter();
    while True {
        got = it.next();
        if got.is_none() {
            break;
        }
        (k, v) = got.unwrap();
        total += int(k) * int(v);
    }
    rows: own Vec[Vec[u8]] = Vec[Vec[u8]].new();
    first: own Vec[u8] = Vec[u8].new();
    first.push(u8(26));
    rows.push(first);
    row = rows[u64(0)];
    print(total, row.len(), row[u64(0)]);
}

with entry {
    main();
}
```

```output
50 1 26
```

```jac
import from std.collections { HashMap }
import from std.vec { Vec }

def main {
    v: own Vec[u8] = Vec[u8].new();
    for n in [9, 3, 7] {
        v.push(u8(n));
    }
    v.sort();
    print(bytes(v.as_slice()), v.contains(&u8(7)), v.starts_with(b"\x03"));
    copied: own Vec[u8] = v.to_vec();
    m: own HashMap[Vec[u8], u32] = HashMap[Vec[u8], u32].new();
    m.insert(copied, u32(17));
    it = m.iter();
    (key, n) = it.next().unwrap();
    print(bytes(key.as_slice()), n);
}

with entry {
    main();
}
```

```output
b'\x03\x07\t' True True
b'\x03\x07\t' 17
```

`m.clear()` before the last `print` would be E1302: `key` borrows `m`.

### A `Vec` of numbers as a buffer

A `Vec` of numbers (an integer of up to 64 bits, `f32` or `f64`) has Python's buffer protocol:
`memoryview(v)` views its items in place, with no copy, one dimension, read-only, its format the
item's (`u32` is `I`, `f64` is `d`, `usize` the target's word), and `bytes(m)` and `m.tolist()`
read the `Vec`'s own memory. A view holds the `Vec` it views, which lives as long as the view does.

- **A call that may resize the `Vec` while a view is out raises `BufferError`**, as a
  `bytearray`'s does: each method that takes it `&mut` (`push`, `clear`, `reserve`) or by value,
  and the `Vec` given to Rust by `&mut` or moved. A change in place (`v[i] = x`, `sort`, `fill`,
  the slice's methods) is not one, and the view shows it. `m.release()` ends the view.
- **A `Vec` Rust lends** (`&Vec`, a `Vec[Vec[u8]]`'s item by index) has no view (`BufferError`):
  what lends it may change it through calls Jac does not see.
- An extension module's class whose `__buffer__` gives such a view gives Python the same buffer
  ([Packages](../toolchain/packages.md)); `neojac port` writes PyO3's `__getbuffer__` that fills a
  view of a field's `Vec` so ([Porting Rust](port-rust.md)).

```jac
import from std.string { String }
import from std.vec { Vec }

def main {
    v: own Vec[u32] = Vec[u32].new();
    for n in [4, 5, 6] {
        v.push(u32(n));
    }
    m = memoryview(v);
    print(m.format, m.itemsize, m.readonly, len(m), m.tolist());
    v[1] = u32(50);
    print(m[1], bytes(m)[4]);
    try {
        v.push(u32(7));
    } except BufferError as e {
        print("BufferError:", e);
    }
    m.release();
    v.push(u32(7));
    s: own String = String.default();
    print(v.len(), s.len());
}

with entry {
    main();
}
```

```output
I 4 True 3 [4, 5, 6]
50 50
BufferError: Existing exports of data: object cannot be re-sized
4 0
```

### A Result of Jac's types

Std's `Result` and `Option` are Rust's own where they hold Rust's types. Where what they hold is
Jac's (a crate's own type once it is ported, a tuple), a `Result` is `rust`'s `Result[T, E]`, a Jac
class with std's meaning: `Ok` and `Err` to make one, and `is_ok`, `is_err`, `ok`, `err`, `unwrap`,
`unwrap_err`, `expect` and `unwrap_or`, which panic (`RustPanic`) with Rust's messages, the value
printed by its `repr`, as Rust prints it by `Debug`. An `Option` of a Jac type is `T | None`.
Rust's unit as a type argument of a Rust type is `None`: `Result<(), Error>` is `Result[None, Error]`.
`neojac port` writes these for a crate's `Result`s
([Porting Rust](port-rust.md)), with a `Display` impl as `__str__` and a derived `Debug` as
`__repr__`.

```jac
import from rust { Result, RustPanic }

obj Fault {
    has code: int;

    def __repr__ -> str {
        return f"Fault {{ code: {self.code} }}";
    }
}

def halves(n: int) -> Result[tuple[int, int], Fault] {
    if n % 2 == 1 {
        return Result[tuple[int, int], Fault].Err(Fault(code=n));
    }
    return Result[tuple[int, int], Fault].Ok((n // 2, n // 2));
}

with entry {
    r = halves(8);
    print(r.is_ok(), r.unwrap(), halves(3).err().code, halves(3).unwrap_or((0, 0)));
    try {
        halves(5).unwrap();
    } except RustPanic as e {
        print(e);
    }
}
```

```output
True (4, 4) 3 (0, 0)
called `Result::unwrap()` on an `Err` value: Fault { code: 5 }
```

Rust's `Box<dyn Error + Send + Sync>` is `rust`'s `DynError`: what a program can still ask of a
boxed error, how `{}` and `{:?}` print it, held as `shown` and `debug`, which its `str()` and
`repr()` give. `neojac port` writes a `Result<T, Box<dyn Error>>` as `Result[T, DynError]`, and
`?` of another crate's error as `Err(DynError(shown=str(e), debug=repr(e)))`.

```jac
import from rust { DynError, Result, RustPanic }

def parsed(text: str) -> Result[int, DynError] {
    if not text.isdigit() {
        why = DynError(shown="invalid digit", debug="ParseIntError { kind: InvalidDigit }");
        return Result[int, DynError].Err(why);
    }
    return Result[int, DynError].Ok(int(text));
}

with entry {
    print(parsed("42").unwrap(), parsed("4x").err());
    try {
        parsed("4x").unwrap();
    } except RustPanic as e {
        print(e);
    }
}
```

```output
42 invalid digit
called `Result::unwrap()` on an `Err` value: ParseIntError { kind: InvalidDigit }
```

### Values that borrow, and how a Rust value prints

- **A Rust value that borrows** (a type with a lifetime: `Option<&Vec<u8>>`, an `Iter<'_, u32>`,
  `Result<&str, Utf8Error>`) is a Jac value that may only be a local, borrowing what rustc says it
  borrows: the receiver of the `&self` method that gave it, or the `str` or `bytes` a function was
  given. Its type is written as rustc writes it, a reference as a type argument:
  `Result[&str, Utf8Error]`, `Option[&Vec[u8]]`, `Slice[u8]` for `&[u8]`. It may not be stored in a field, a global or a container, nor
  returned (E1315), and while it is used its owner may not be changed, moved or dropped (E1302,
  E1303, E1304), as Rust's borrow checker holds it. A `&T` result is a borrow of the Rust value
  (`got.unwrap()` above is a `&Vec[u8]`), and a `&mut self` method lends its receiver mutably for
  the call. A method that takes a borrowing receiver by value (`unwrap` of an
  `Option[&Vec[u8]]`) gives a result that borrows what the receiver borrowed, not the receiver,
  as Rust's signature says: an item taken out of a lending iterator's `Option` outlives the
  `Option`, and holds the iterator's owner.
- **A value lent by a `str` or `bytes` argument keeps it.** `from_utf8(b)` gives a
  `Result[&str, Utf8Error]` that borrows the bytes made of `b` for the call: the value holds them
  for as long as it lives, and what it lends on (`decoded.ok()`, `unwrap()`) holds them too. A
  result that borrows several of its inputs is lent by each.
- **What is not offered**: a function or method whose result borrows an argument other than its
  receiver and its `str` and `bytes` arguments (a Rust value it is given by `&`), a reference
  into the bytes it is given, and one that may keep a borrow of an
  argument (`HashSet<&str>::insert`): a Jac `str` or `bytes` is otherwise lent to Rust only for
  the call.
- **A Rust value prints as Rust shows it**: `repr()` is its `Debug` (`{:?}`), and `str()` and
  `print` its `Display` where it has one, else its `Debug`. A type with neither prints as its Rust
  type, `<adder::Bag>`. Its class is named as the program writes it, `HashSet[u32]`, in messages
  too.

```jac
import from std.collections { HashMap, HashSet }
import from std.string { String }
import from std.vec { Vec }

def main {
    m: own HashMap[u32, Vec[u8]] = HashMap[u32, Vec[u8]].new();
    v: own Vec[u8] = Vec[u8].new();
    v.push(u8(7));
    v.push(u8(9));
    m.insert(u32(1), v);
    got = m.get(&u32(1));
    inner = got.unwrap();
    print(inner.len(), inner[1], got.is_some());
    m.clear();
    print(m.len(), m.get(&u32(1)));
    s: own HashSet[u32] = HashSet[u32].new();
    s.insert(u32(3));
    name: own String = String.new();
    name.push_str("hé");
    print(s, name, repr(name));
}

with entry {
    main();
}
```

```output
2 9 True
0 None
{3} hé "hé"
```

`m.clear()` before the `print` that reads `got` would be E1302: `got` borrows `m`.

A value lent by the bytes it was given, read after those bytes, and much else since, are garbage:

```jac
import from std.option { Option }
import from std.result { Result }
import from std.str { Utf8Error, from_utf8 }

def main {
    decoded: Result[&str, Utf8Error] = from_utf8(("h\u00e9" * 3).encode());
    spilled = 0;
    for k in range(20000) {
        spilled += len(f"spill {k}".encode());
    }
    text: Option[&str] = decoded.ok();
    print(text.unwrap(), spilled > 0, from_utf8(b"\xff").is_err());
}

with entry {
    main();
}
```

```output
héhéhé True True
```

An item rustc reports that Jac cannot bind is left out with its reason (E5138), where it is
imported and, for a method, where it is called: a type that borrows and is not offered as above,
a method generic over a type no argument is of, a closure that is `Send`. An item of a kind Jac
does not import (a constant the interface does not give, a static, a module, a macro) is E5138
too, saying which it is, and a name the crate has no public item for is E1145. Rust items that
cannot be read or built at all are E5190.

## Tasks that wait in Rust

A [task](../language/async.md#tasks-flow-and-wait) whose call is a crate's function or a method
of a Rust value waits in Rust without the program's lock
([How threads take turns](../library/threading.md#how-threads-take-turns)), so the program's
other threads run meanwhile. Called any other way, Rust keeps the lock, and the call is one step
to every other thread.

<!-- example: not checked: needs a Rust crate with a function that waits and a Gate beside the program -->
```jac
def opener(gate: Gate) -> bool {
    awaited = wait flow gate.awaited(u64(10000));
    gate.open();
    return awaited;
}

with entry {
    naps = [flow nap(300) for k in range(4)];
    print([wait t for t in naps]);
    gate = Gate.new();
    opening = flow opener(gate);
    print(wait flow gate.pass(u64(10000)), wait opening);
}
```

```text
[300, 300, 300, 300]
True True
```

The four naps take the time of one. `gate.pass` returns once another thread has called
`gate.open`, which a thread that kept the lock while it waited would never let run.

- **`flow f(a)` runs on a thread of the program's pool, and `wait flow f(a)` on the thread that
  waits**: a loop that must stay on the thread that started the program, and still let the
  others run, is `wait flow app.run()`.
- **A Jac function Rust calls back while it waits** (a callback, a closure) takes the lock for the
  call, and gives it up again as it returns.
- **An `extern "C"` function is given only what no other thread can change meanwhile**: a number,
  a `bool`, a `str`, `bytes`, a `ptr`, a function, a record, a local given by `&`. Anything else,
  a `bytearray` say, is E1308.
- **A method needs a value another thread may be given**: one that is `Send`, or `Sync` for a
  method that takes `&self`, which rustc says of each type. A task of a method of any other value
  is E1308, and so is one given another Rust value as an argument.
- **A value that is `Sync` is shared while a method that takes `&self` waits in it.** Other
  threads go on calling its `&self` methods, any number of tasks wait in it at once, and a method
  that would change it or move it raises `RustPanic` until they are out.
- **Any other waiting call has its value to itself.** A thread that uses the value before the
  call returns raises `RustPanic` (`a value is used that Rust moved, or that a call that waits
  has to itself`).

## Calling Jac and C from Rust

A crate calls C modules and Jac functions by name, declared in an `unsafe extern "C"` block, and
the project's [archwire](../language/modules-wiring.md) says where each comes from. In a project
with C modules `shapes` and `geom`, a crate `tally` and a Jac module `helpers`:

`archwire.jac`:

<!-- example: not checked: an archwire.jac of a project with C modules and a crate -->
```jac
graph layers {
    layer helpers { helpers; }
    layer libraries { shapes | geom | tally; }
    layer program { main; }
}

graph import {
    edge Helpers: helpers --> libraries;
    edge Libraries: libraries --> program;

    shapes ++> geom;
    geom ++> main { geom_total }
    tally ++> geom;
    tally ++> main { tally_twice }
    helpers ++> tally { jac_double }
}
```

| Wire | Means |
|---|---|
| `helpers ++> tally { jac_double }` | The Jac module `helpers`' functions `jac_double` become C-ABI functions of that name, which the crate calls |
| `shapes ++> tally;` | The crate calls the C module `shapes`' functions by name; `shapes` is built into every program the crate is in |
| `tally ++> geom;` | The C module `geom`'s code calls the crate's `extern "C"` functions by name; the crate is linked, as a library whatever its `crate-type`, into every program `geom` is in |
| `tally ++> main { tally_twice }` | Jac binds the crate's names, as `import from tally { tally_twice }` does |

A crate takes names from a Jac module and a C module whole; any other wire into it is E5141. A Jac
function a crate calls that raises an exception returns 0 to Rust, and the exception's traceback is
printed on standard error.

## A crate's files

A crate of the project's own is what cargo builds, and its files are modules of the project
besides: `ws/gear/src/teeth.rs` is `ws.gear.src.teeth`. Where one file of the crate names an item
another defines, a `-->` wire declares it, as for a file in any other language
([Declared wires](../language/modules-wiring.md#declared-wires---)):

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    ws.gear.src.teeth --> ws.gear.src.lib { RATIO, count }
    ws.gear.src.util --> ws.gear.src.teeth;
}
```

`lib.rs` holds `use crate::teeth::count;` and `teeth::RATIO` in an expression; `teeth.rs` holds
`use crate::util::*;`.

- rustc reads the crate: its library and its programs, as cargo builds them. An import is a path
  rustc resolved to an item of the crate that another file defines, wherever the path is written.
  A method has no path of its own; the type's is the import. What a macro's expansion names
  counts for the file that calls the macro.
- A `mod` declaration is no import: it says a file is part of the crate, not that its names are
  used.
- A crate is the project's own where `jac.toml` holds its manifest (`[cargo."ws/gear"]`). A crate
  with a `Cargo.toml` that `jac.toml` does not hold is a dependency, one module whole, and so is a
  crate from crates.io. An import of another crate is cargo's, in the manifest.
- Code differs by platform (`#[cfg(windows)]`), so a crate is read for the platform being built
  and for every other platform neojac builds Rust for whose standard library is at hand. A reading
  never compiles a standard library. Where one is missing, an import no reading holds may be one
  that platform compiles, so a wire is not reported as declaring nothing (E1147) until every
  platform has been read; an import no wire declares (E1575) is reported from any.
- A reading is kept in the build cache by what the crate holds (its manifest and every `.rs` file
  under it), the platforms read, and the neojac that read it; it names the crate's files from the
  crate's directory. A copy of the project in another directory is checked from the same reading.
- These wires are checked by every command ([What a command judges](../language/modules-wiring.md#what-a-command-judges)), whether the program at hand uses the crate or not, and mended by `neojac fmt --fix`. A
  `macro_rules!` macro called by its textual scope leaves no path in what rustc resolves, and is
  not an import here.

## How it is built and linked

- **cargo plans, neojac compiles.** cargo resolves and fetches the dependencies from `Cargo.lock`
  and says what to build; neojac runs rustc on each crate, and each build script and procedural
  macro, as cargo would. A build script's output lines mean what they mean to cargo, in both
  spellings (`cargo::rustc-link-lib=static=cadd` and `cargo:rustc-link-lib=static=cadd`).
- **Profiles.** Each crate compiles with its profile's settings as cargo resolves them for it,
  `lto = "off"` among them, and a profile's own `rustflags` (cargo's `profile-rustflags`), which
  rustc is given ahead of those of `RUSTFLAGS`, as cargo gives them. One package that two Rust modules build with different settings
  (`debug-assertions = false` in one's `[profile.dev]`) is two crates, and the program links
  both.
- **Each crate is a unit of the build cache**, kept by the content of the files rustc read. A
  rebuild compiles what an edit changed and the crates that depend on it; an edit to the Jac alone
  compiles no Rust. A crate is the smallest thing rustc compiles, so editing one file of a large
  crate costs more than editing one C file.
- **Incremental mode.** A crate compiles with rustc's incremental mode where cargo's profile says
  so: a local package's crates in the dev profile (a build without `--release`), unless
  `CARGO_INCREMENTAL=0`, `build.incremental` or the profile turns it off, or the build runs under
  CI, where cargo turns it off. An incremental crate is
  not the same bytes from build to build, since rustc names its objects at random; every other
  crate is the same bytes from every build of the same sources, wherever they, the toolchain and
  the build cache are, and a module's crates link in the same order from every build.
- **Variables.** A crate that reads a variable (`env!`, `option_env!`) compiles again when it
  changes, and a change to a variable cargo or rustc is configured by makes the build look again.
- **cargo's configuration** applies as it does to `cargo build`: `.cargo/config.toml`'s `[env]`
  (a plain value, `{ value = ..., force = true }` which wins over the environment, and
  `{ value = ..., relative = true }` made absolute from the file's directory), its
  `[build] rustflags` for the target's crates (not procedural macros, which are built for the
  machine building), `RUSTFLAGS` in place of the configured flags, `CARGO_ENCODED_RUSTFLAGS` in
  place of both, and `$CARGO_HOME/config.toml`.
- **`NEOJAC_DEPENDENCY_DIGEST`** is in every crate's compile environment: a digest (a multiple of
  64 hex characters) of what the crates it depends on are, their artifacts and the native
  libraries they link, by content and never by path. A crate that reads it
  (`env!("NEOJAC_DEPENDENCY_DIGEST")`) can say exactly which build of its dependencies it was
  linked with, the same from any rebuild of the same sources.
- **Builds at once.** Builds that compile Rust in one cache run side by side: nothing a build
  script or rustc writes there is written twice. Two builds that need the same crate at the same
  moment compile it once: one does, and the other does the rest of its work, waits for that
  crate if it has nothing else to do (`waiting for the crates another build is compiling`), and
  reads it.
- **`--release`** compiles the crate whose items the Jac binds to bitcode, which optimizes with the
  program's Jac and C, so calls inline across the languages both ways. Of a crate whose Rust
  items the program imports too, it is the shims that are so compiled: the crate's
  `extern "C"` functions are called, not inlined.
- **Each Rust module links as a unit of its own**, which shows the rest of the program only its
  interface: the names the Jac imports of it, and, for a module wired into a C module, the
  symbols that C module calls. Every other symbol of it, a `#[no_mangle]` one or one of the C its
  build scripts compile included, is private to it, so two modules may each define a symbol of
  one name. A static library a build script names from outside its build (`openssl-sys` naming
  the toolchain's OpenSSL) is linked once.
- **A crate whose Rust items a program imports is in the program once.** The crates those items
  are of link in one unit, with the shims, and what the program binds of such a crate's
  `extern "C"` interface is that unit's: a static of the crate is one static, whichever way its
  functions are called. Two modules that depend on one crate, each used through its interface
  alone, each have their own of it.
- **One standard library.** The crates of a program share one copy of `std`.
- **Panics and memory.** A panic unwinds inside Rust and aborts the program at an `extern "C"`
  boundary, as Rust defines (`panic in a function that cannot unwind`). Rust allocates with the C
  library's allocator; memory crossing the boundary is freed by the side that allocated it.
- **Targets.** A program with Rust modules builds for every platform `neojac build` does but
  `wasm32-wasi`, with `--target` and `--release` as usual; another target's Rust standard library
  is compiled the first time, as [Rust](rust.md) describes.

## What goes wrong

| Code | Cause |
|---|---|
| E5138 | The imported item, or the method called, is something Jac is not given; the message says why |
| E1145 | The crate has no public item of that name |
| E5146 | Two Rust modules both give the program a symbol the program calls by name |
| E5144 | The crates of one Rust module do not link together (two `#[global_allocator]`s, say); rustc's reason follows |
| E5140 | A crate does not compile; rustc's errors are printed first |
| E5137 | cargo cannot resolve the module (a bad `Cargo.toml`, a dependency it cannot fetch) |
| E5139 | The crate's interface cannot be read |
| E5141 | A wire into a crate other than names from a Jac module or a C module whole |
| E5190 | Rust items the program imports natively cannot be read or built; the message says why |
| E2270 | A Jac file of a crate imports from a dependency that a Jac or Python module is also named |
| E1637 | A value whose drop runs code is taken from a managed place into an `own` binding |
| E1625 | An instance of a generic function or method that rustc cannot make for its type arguments, written at the call or taken from its arguments |
| E1308 | A task of a Rust call is given a value another thread could change, or a Rust value no other thread may be given |

## Differences from Python and from the reference design

- Python reaches Rust through a compiled extension module (PyO3, maturin). Here a crate's
  `extern "C"` items are bound directly, and the crate is linked into the program.
- The reference design has no Rust modules.
