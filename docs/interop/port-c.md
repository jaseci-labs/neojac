---
description: What neojac port makes of each C construct - the Jac it becomes, and what it refuses.
keywords: port c, porting C, C to Jac
---
# Porting C

`neojac port` translates a C source file into a Jac module that behaves as the file does, or
refuses it ([port](../toolchain/port.md)). This page is the mapping: each C construct port
translates and the Jac it becomes. It is printed from the table the translation itself reads
(`neojac port --mapping c`).

Clang reads the file once for each target neojac builds C for, with its module's flags, and
port translates each reading. Where they agree the Jac is written once. A statement that
differs by target is written under `comptime if` on `target()`, and a declaration that differs
goes to the module's target variant files (`x.windows.jac`).

A source file is ported with the header of its name, if it has one: `geom.c` and `geom.h` are
the module `geom`.

| C | Jac |
|---|---|
| `int`, `unsigned`, `long long`, `int64_t`, `signed char`, `unsigned char`, `short`, `double`, `float`, `_Bool` | `i32`, `u32`, `int`, `int`, `i8`, `u8`, `i16`, `float`, `f32`, `bool`: an integer by its width on each target, and a signed 64-bit one is `int`, as a C module's interface declares it |
| `int *`, `void *`, `const char *`, `FILE *`, `int (*)(int, int)`, `int (**)(int)`, `long long (*)()` (a function of no prototype, as `FARPROC`), `char [16]` in a record or at file scope | `ptr[i32]`, `ptr`, `ptr[i8]` on every target, `ptr[FILE]` with `obj FILE;` in `import from c`, `Callable[[i32, i32], i32] \| None`, `ptr[Callable[[i32], i32] \| None]` (its item `p[0]` read and written as the function pointer, and a local function pointer whose address is taken the item in the frame, `__alloca` memory, since a local of a `Callable` type holds a function value, no C data), `ptr` (converted to a prototype before each call, as C does), `array[i8, 16]` |
| `char`, whose sign is the target's: `int n = c;`, `c == 'a'` | `i8` on every target. Its value as a number is the target's: `n = i32(c);`, and `n = i32(u8.wrap(c));` where `char` is unsigned (Linux arm64), the two under `comptime if` where the targets differ |
| `int f(int a, double b) { }`, `void g(void) { }` | `def f(a: i32, b: float) -> i32 { }`, `def g { }` |
| `__func__`, `__FUNCTION__`, `__PRETTY_FUNCTION__` (as glibc's `assert` gives them), GNU's `__extension__ e` | the function's name as a C string literal is, `ptr[i8]("name")`; `e` |
| `CFSTR("name")` (CoreFoundation's `__builtin___CFStringMakeConstantString`) | `__CFStringMakeConstantString(ptr[i8]("name"))`, the function CoreFoundation's header names for it where the compiler has no builtin, declared in `import from c` |
| `int say(const char *fmt, ...) { va_list ap; va_start(ap, fmt); n = vprintf(fmt, ap); va_end(ap); }` | `def say(fmt: ptr[i8], *ap: VaList) -> i32 { n = vprintf(fmt, ap); }`: a function of C's variadic arguments, by the C ABI, which C calls as it called the C; `va_start` is the parameter, `va_end` is where the list's scope ends, and a function given the `va_list` (`vprintf`, `PyErr_FormatV`) is given `ap` |
| `va_arg(ap, int)`, `va_arg(ap, double)`, `va_arg(ap, const char *)` | `ap.next[i32]()`, `ap.next[float]()`, `ap.next[ptr[i8]]()`: the next argument, read as C reads it |
| `va_list cp; va_copy(cp, ap);`, `int vsay(const char *fmt, va_list ap)` | `cp = ap.copy();`, `def vsay(fmt: ptr[i8], ap: VaList) -> i32` |
| `int main(void) { }` | `def main -> i32 { }` and `with entry { sys.exit(int(main())); }` |
| `int total = 0;` at file scope, `int x = 1;` in a function, `int x;`, a local of a name another variable of the function or of the file has | `glob total: i32 = 0;`, `x: i32 = 1;`, `x: i32 = 0;`, the name with `_2` (`_3`, ...): a Jac function has one variable of a name, of one type |
| `int x; f(&x);`, `g(&total);`, `h(&n);` of a parameter `n`, `&p.y`, `&xs[2]`, `int xs[3] = {1, 2};`, `char name[] = "ab";`, `f(xs)`: a local, a global or a parameter whose address is taken, a field or an item of one, a local array | `x: i32 = 0; f(addressof(x));`, `g(addressof(total));`, `h(addressof(n));`, `addressof(p.y)`, `addressof(xs) + 2`, `xs: array[i32, 3] = array[i32, 3](1, 2, 0);`, `name: array[i8, 3] = array[i8, 3](97, 98, 0);`, `f(addressof(xs))`: an ordinary variable, the place C's `&` names; an array's address is its first item's |
| `static int n = 0;` in a function `next`, `&n` | `glob next_n: i32 = 0;`, beside the function, `addressof(next_n)` |
| `extern int counted;` at file scope or in a function, of a global another file of the module defines, and `counted` where it is used | Nothing where it is declared, and `counted`, which the wire from the file that defines it gives, `native.unity ++> native.count { counted }` |
| `struct point { double x; int n; };`, `struct point p = {1.5, 2};`, `p.x` | `struct point { has x: float = 0.0, n: i32 = 0; }`, `p: point = point(x=1.5, n=2);`, `p.x` |
| `union word { unsigned whole; unsigned short half; };`, `union word w; w.whole = 1;`: a union the file declares, at file scope or in a function | `union word { has whole: u32, half: u16; }`, `w: word = word(); w.whole = 1;`: a Jac union, made zeroed, its fields with no default |
| `struct header { unsigned ready : 1; unsigned kind : 3; unsigned : 4; signed level : 5; unsigned : 0; unsigned char after; };`: bit-fields a record the file declares holds | `struct header { has ready: u32: 1 = 0, kind: u32: 3 = 0, _: u32: 4, level: i32: 5 = 0, _: u32: 0, after: u8 = 0; }`: a width on the field, laid out as C lays it out; a bit-field of no name only pads, `_`. On a target whose C lays bit-fields out otherwise (Windows' Microsoft layout) the record is refused |
| `struct dispatch { long long (*run)(long long, long long); long long (*table[3])(long long, long long); };`, `static long long (*handlers[3])(long long, long long) = {added, NULL, larger};`, the same array in a function, `&handlers[2]` | `struct dispatch { has run: Callable[[int, int], int] \| None = None, table: array[Callable[[int, int], int] \| None, 3] = array[Callable[[int, int], int] \| None, 3](); }`, `glob handlers: array[Callable[[int, int], int] \| None, 3] = array[Callable[[int, int], int] \| None, 3](added, None, larger);`, `addressof(handlers[2])`: C's function pointers, held as the addresses they are |
| `struct dispatch { int kind; union { int tag; unsigned flags; }; };`, `d.tag = 2;`: an anonymous member | `struct dispatch_anon0 { ... }` and the field `anon0: dispatch_anon0 = dispatch_anon0()`, `d.anon0.tag = 2;`: a record of no name, named for its record and the member, as a C module's interface names one |
| `m->items[i]` of `int items[1];`, C's struct hack, and any index of an array that is not a constant its length keeps in range | `addressof(m[0].items[0])[i]`: the item at the address C reads, unchecked as C's index is; a constant index in range is the array's own, `m[0].items[0]` |
| `#include "Python.h"` then `#include "pycore_long.h"`, and `#define NEEDS_ONE 1` above them, in a source of a C module of the project | The Jac module's table in jac.toml, `[c.cpython.files."Objects/boolobject.jac"] headers = ["<Python.h>", "<pycore_long.h>"]` and `defines = ["NEEDS_ONE=1"]`, beside the flags the table gave the source: the Jac module binds what its source's translation unit declared, its headers read in that order under those flags. A header beside the source is named by its path from the module, `Objects/clinic.h`; a macro set between two of them is refused |
| `_Static_assert(sizeof(int) == 4, "four bytes");` at file scope or in a function | `comptime assert i32(u64(4) == 4) != 0, "four bytes";`, its condition as each target's reading has it |
| `lldiv_t q = lldiv(47, 5);`, `union sigval v; v.sival_int = 9;`: a record or a union a system header declares, held by value, or a record of no name a named one's field has (`extern_proc`'s `p_un`); a record of a header of the project's C module | `obj lldiv_t { has quot: int, rem: int; }` and `union sigval { has sival_int: i32, sival_ptr: ptr; }` in `import from c`, the fields from Clang's layout, a record of no name by the two names (`extern_proc_p_un`); the module's record by the wire from its header |
| `enum { RED, GREEN = 5 };` | `comptime RED: i32 = 0;`, `comptime GREEN: i32 = 5;` |
| `typedef struct { } point;`, `typedef int count;`, at file scope or in a function | The record by its typedef's name; any other typedef is the type it names |
| `if (c) { } else if (d) { } else { }`, `while (c) { }` | `if c { } elif d { } else { }`, `while c { }`; a condition that is a number is `c != 0` |
| GNU's statement expression, `if (({ int t = f(x); t > 2; })) { }`, glibc's `CPU_SET` and `CPU_ISSET` | Its statements written before the statement whose evaluation it begins (an expression statement, an `if`'s condition, a `return`'s value, a declaration's value), then its last expression: `t = f(x);` then `if t > 2 { }`; anywhere else a `do` block where it stands, `n = g() + do { t = f(x); t > 2 };` |
| `__attribute__((fallthrough));` (CPython's `_Py_FALLTHROUGH`), `[[likely]]`, `__attribute__((musttail)) return f(x);`: a statement's attribute | Nothing, `return f(x);`: the statement, without the attribute, which tells the compiler what it may assume or how to compile it and changes nothing the program does (Jac's `switch` falls through by itself) |
| `(struct point){1.5, 2}`, `&(struct point){1.5, 2}` in a function, at file scope | `point(x=1.5, n=2)`; `do { was_1: point = point(x=1.5, n=2); addressof(was_1) }`, a local that lives until the function returns; `addressof(literal_1)` of `glob literal_1: point = point(x=1.5, n=2);`, a global of the module |
| `for (int i = 0; i < n; i++) { }`, `for (p = head; p; p = p->next) { }` | `for i = i32(0) while i < n with i += 1 { }`, `for p = head while p != ptr[link](ptr()) with p = p[0].next { }` |
| `do { } while (c);`; one with a `continue` of its own; a `for` whose step is more than one assignment, `for (i = 0, j = n; i < j; i++, j--)`, with a `continue` | `while True { ... if not c { break; } }`; `while True { do:pass_1 { ... break:pass_1; ... } if not c { break; } }`, `i = 0; j = n; while i < j { do:pass_2 { ... break:pass_2; ... } i += 1; j -= 1; }`: the body a named `do` block its `continue` leaves, to the condition or the step as C's goes |
| `return v;`, `break;`, `continue;` | The same |
| `goto error;` forward, to a label of a block that holds the `goto`, from anywhere before the label: a nested loop, a `switch`, an earlier label's code; `goto again;` back, to a label before it | `break:error;`, out of `do:error { ... }`, a block that ends where the label stands; `continue:again;` of `forever:again { ... break:again; }`, a loop from the label to the last `goto` back to it: a named `break` and `continue` leave the loops and switches between, at any depth |
| `error: free(buf); return NULL;` that a forward `goto` reaches, or that none does; its code may return, go to a later label, or leave its loop | `do:error { ... } free(buf); return None;`: the label's code follows the block a `goto` to it leaves, and the code before falls into it; a label no `goto` names is its statement; C's `skip:` is `label_skip`, a name Jac keeps |
| `a + b`, `a - b`, `a * b` of signed integers and of floats | `a + b`, `a - b`, `a * b`: C leaves a signed overflow undefined, and Jac raises OverflowError |
| `a + b`, `a - b`, `a * b`, `a << k` of unsigned integers | `a +% b`, `a -% b`, `a *% b`, `wrapping_shl(a, k)`: they wrap, as C defines |
| `a / b`, `a % b` of signed integers | `(a // b + 1) if (a % b != 0 and (a < 0) != (b < 0)) else (a // b)`, and the like for `%`: C rounds toward zero and Jac toward negative infinity |
| `a / b`, `a % b` of unsigned integers | `a // b`, `a % b` |
| `a / b` of floats; `x = f() / g();`, whose operands have side effects, where the division is the first thing its statement evaluates; `x = h() + f() / g();`, after something else | `a / b` where `b` is a literal other than 0; else `(a / b) if b != 0.0 else a * math.copysign(float("inf"), b)`, since Jac raises where C gives an infinity; `was_1: float = f(); was_2: float = g();` before the statement, which divides those: each operand once, in C's order; after something else, the same in a `do` block where it stands, `x = h() + do { was_1: float = f(); was_2: float = g(); ... };` |
| `a < b`, `<=`, `>`, `>=`, `==`, `!=`, `a && b`, `a \\|\\| b`, `!a` | The same comparisons, `a and b`, `a or b`, `not a`; where C takes the result as a number, `i32(a < b)` |
| `a & b`, `a \\| b`, `a ^ b`, `~a`, `a >> k`, `-a`, `c ? a : b` | `a & b`, `a \\| b`, `a ^ b`, `~a`, `a >> k`, `-a` (`-%a` of an unsigned), `a if c else b` |
| `x = v;`, `x += v;` and the other compound assignments, `x++;`, `x--;` as statements | `x = v;`, `x += v;` (`x +%= v;` of an unsigned), `x += 1;`, `x -= 1;` |
| `5`, `5u`, `'a'`, `1.5`, `1.5f` | `5` where its type is given by what takes it, else `i32(5)`, `u32(5)`, `i32(97)`; `1.5`, `f32(1.5)` |
| `#define SHELF 12` and `SHELF` where a value is taken, a macro whose expansion is one integer | `comptime SHELF: i32 = 12;` and `SHELF`; any other macro is written as what it expands to |
| `L"text"`, `u"text"`, `U"text"`: a wide string literal | `ptr[u32]("text")` (`ptr[i32](ptr[u32]("text"))` where `wchar_t` is signed), and `ptr[u16]("text")` where `wchar_t` is 16 bits (Windows); `ptr[u16]("text")`, `ptr[u32]("text")`: static NUL-ended data of its code units, as wide as the target's |
| `p->x`, `*p`, `p[i]`, `&a[i]`, `&p->x`, `p + n`, `p - q`, `NULL`, `if (p)`, `!p` | `p[0].x`, `p[0]`, `p[i]`, `a + i` (`addressof(a) + i` of an array `a`, which may point past its end, as C's may), `addressof(p[0].x)`, `p + n`, `p - q` (an `int`), `ptr[T]()`, `if not p.is_null()`, `p.is_null()` |
| `switch (x) { case 1: case 2: f(); break; default: g(); }`, GNU's `case '0' ... '3':` and `case 0 ... 999:`, `switch (c) { int seen; case 1: ... }` | `switch x { case 1: case 2: f(); break; default: g(); }`: Jac's `switch` falls through as C's does; `case 48 \| 49 \| 50 \| 51:`, a range of at most 64 values; a wider range is its lowest value, `case 0:`, to which the subject is mapped before the `switch`, `switch do { s = x; 0 if 0 <= s and s <= 999 else s } { ... }`; a declaration above the first case, or that the `switch` makes (C++'s `switch (int x = f())`), is before the `switch` |
| A conversion, written `(long long)x` or made by C: to a type that holds every value | `int(x)`, `float(x)` |
| A conversion to an integer type that does not hold every value; of a float to an integer | `u8.wrap(x)`, and `int(i64.wrap(x))` to a signed 64-bit integer: it keeps the low bits, as Clang defines; `i32(x)`: toward zero |
| `(char *)p`, `(void *)p`, `(intptr_t)p`, `(int *)n`, a string literal where its address is taken | `ptr[i8](p)`, `ptr(p)`, `int(p)`, `ptr[i32](int(n))`, `ptr[i8]("...")` |
| `(void *)f` of a function pointer a variable holds, `(release_fn)-1`, `f == g` of function pointers, a function given to C's `...`; `f = NULL`, `if (f)`, `!f`, `f == NULL` of a function pointer; `*f`, `(*f)(x)` | `ptr(f)`, `Callable[[ptr], None](ptr(int(-1)))`, `ptr(f) == ptr(g)`, `ptr(f)`: the C address the value holds; a function's value gives its C trampoline; `f = None`, `if f is not None`, `f is None`, `f is None`: a null C address is `None`, and `ptr(f)` of `None` is the null address; `f`, `f(x)`: C's `*` of a function pointer is the function |
| `f(a, b)`; `printf("%d\n", n)` of the C library | `f(a, b)`; `printf("%d\n", n)`, with `import from c { def printf(format: str, *args: VaList) -> i32; }` |
| `__builtin___strcpy_chk(d, s, n)`, `__builtin___snprintf_chk(b, n, f, k, fmt, ...)`: what `strcpy` and `snprintf` expand to where a header fortifies them | `strcpy(d, s)`, `snprintf(b, n, fmt, ...)`: the C library's function, without the check of a size the compiler would have known |
| `__builtin_memset(p, 0, n)`, `__builtin_memcpy`, `__builtin_memmove`, `__builtin_memcmp`, `__builtin_strlen` | `memset(p, 0, n)` and the like: the C library's function, which the builtin is |
| `__builtin_isnan(x)`, `__builtin_isinf(x)`, `__builtin_isfinite(x)`, `__builtin_isinf_sign(x)`, `__builtin_inff()`, `__builtin_nan("")`, `__builtin_fabs(x)`, `__builtin_copysign(x, y)`, `__builtin_expect(c, 0)`, `__builtin_unreachable();` | `math.isnan(x)`, `math.isinf(x)`, `math.isfinite(x)`, `(i32(1) if x > 0.0 else i32(-1)) if math.isinf(x) else i32(0)` (of a value with side effects taken once in a `do` block), `f32(float("inf"))`, `float("nan")`, `math.fabs(x)`, `math.copysign(x, y)`, `c`, `raise AssertionError("unreachable code was reached");`: the library's function of the builtin's meaning; Jac raises where C's program would be undefined |
| `isnormal(x)` (`__builtin_isnormal`), `signbit(x)` (`__builtin_signbit`) | `math.isfinite(x) and abs(x) >= 2.2250738585072014e-308` (C's DBL_MIN; FLT_MIN of a `float`), `i32(1) if math.copysign(1.0, x) < 0.0 else i32(0)`: the operand read once |
| `_Atomic int n;` and `n++`, `n += 2`, `n = 0`, a read of `n`; `atomic_load_explicit(&n, memory_order_relaxed)`, `atomic_fetch_add(&n, 1)`, `atomic_exchange(&n, 1)`, `atomic_compare_exchange_strong(&n, &want, 10)` | `n: i32` and `__atomic_add_i32(int(addressof(n)), i32(1), 5)`, `__atomic_store_i32(int(addressof(n)), i32(0), 5)`, `__atomic_load_i32(int(addressof(n)), 5)` (C's plain use of an `_Atomic` object is sequentially consistent); `__atomic_load_i32(int(addressof(n)), 0)`, `__atomic_swap_i32(...)`; `do { e = want_p[0]; found = __atomic_cas_i32(int(addressof(n)), e, i32(10), 5); want_p[0] = found; found == e }`, which writes the value found back through `expected`, as C does. An `_Atomic` record or float is refused |
| `__builtin_available(macOS 10.12, *)` | `__isPlatformVersionAtLeast(i32(1), i32(10), i32(12), i32(0)) != 0`, the call Clang makes of it, declared in `import from c`, where the target is macOS and the version is newer than the oldest it runs on; `True` where the check names no version of the target's platform |
| `__builtin_constant_p(x)` | `1` or `0`, the answer Clang gives where it compiles the call: 1 for a constant, 0 for an argument with side effects (not run), that is not a number, or that the optimizer is left to prove (0 is an answer the builtin always allows) |
| `const char *names[3];` in a record, `static const char *kinds[3] = {"a", "b"};` | `names: array[ptr[i8], 3]`, `glob kinds: array[ptr[i8], 3] = array[ptr[i8], 3](ptr[i8]("a"), ptr[i8]("b"), ptr[i8]())`: an array of pointers, zeroed as null; `char _f[0]` at a system record's end, padding that holds no bytes, is left out |
| `struct kauth_acl acl;` whose field is `struct kauth_ace acl_ace[1];`, `acl.acl_ace[0].ace_flags = 2;`, `struct kauth_acl again = acl;` | `acl_ace: array[kauth_ace, 1]` in the import block's `obj kauth_acl`, `acl[0].acl_ace[0].ace_flags = 2;`, `again[0] = kauth_acl(acl_entrycount=acl[0].acl_entrycount, acl_flags=acl[0].acl_flags, acl_ace=acl[0].acl_ace);`: an array of records held in the record, each item the record where it lies, and a copy of the record copies its array |
| `struct ifreq` of the kernel's `<linux/if.h>` in `kernel.c` and of the C library's `<net/if.h>` in `libc.c` | Each file's import block declares the record as its header does (`ifru_data: ptr` and `ifru_settings: if_settings` for `kernel.c`, `ifru_data: ptr[i8]` for `libc.c`): declarations of one tag that agree are one type across the program, and ones that differ are each their module's own, as C's two files hold two types |
| `struct __attribute__((aligned(4), packed)) buf { uint32_t size; uint64_t used; };`, `#pragma pack(2)` | `@packed @align(4) struct buf { has size: u32 = u32(0), used: u64 = u64(0); }` (`@packed(2)`), with `import from jaclang.comptime { align, packed }`: C's offsets, size and alignment; another attribute of a record, or one of a field, is refused |
| `struct { ... } buf;` in a function `f` | `struct f_buf { ... }` of the module, named for the function and the variable |
| `struct sysinfo info; sysinfo(&info);` (a system record whose tag is also a function's or a global's name) | `obj sysinfo as struct_sysinfo { ... }` beside `def sysinfo(a0: ptr[struct_sysinfo]) -> i32;` in `import from c` |
| `_Generic(x, int: abs, double: fabs, default: labs)(x)`, the tgmath macros | The association Clang chooses for the operand's type, on each target: `fabs(x)` of a `double` |
| `__builtin_choose_expr(sizeof(long) == 8, a, b)` | The operand its constant chooses, on each target: `a` |
| `__builtin_types_compatible_p(T, U)` | Its answer on each target, `1` or `0` |
| `sizeof(int)`, `_Alignof(double)` | Its value on each target, `u64(4)`, `u64(8)`: every size and alignment C folds to a constant; one of no fixed size (a variable-length array's) is refused |
| `offsetof(struct s, f)` | Its value on each target, `u64(8)` |

## What is refused

Anything not in the table is refused with E4001, and nothing is written for the file: a record
with no name that no field names, a copy of a union a system header
declares, a `goto` into a block from outside it or into the loop a `goto` back makes, a `goto`
back whose loop would take a `break` or a `continue` of a statement around it, a `va_list`
that is read from a record or a global, a pointer to an array (the address of an array given where C takes
another pointer is the address of its first item), a record
or a field with an attribute other than packed or aligned, a thread-local variable. So is a
construct in the table whose Jac would mean something else (E4005):

- **An assignment, `++` or `--` used for its value whose target has side effects** (`*p++ = v`
  used for a value). Port would evaluate the target twice. Where C evaluates one only sometimes (on
  the right of `&&` or `||`, in an arm of `?:`, in a `for`'s condition or step, in an `else if`'s
  condition), port writes it as a `do` block where it stands, `a > 0 and do { t = a * 2; t > 3 }`;
  elsewhere as a statement before the one that uses its value. An assignment of a local that
  holds a number or a pointer is `(c := *tail)` wherever it stands. C's comma operator used for
  its value is the same: a statement before, or a `do` block, `do { t += 1; t + 1 }`.
- **A `case` label that is not directly in its `switch`'s braces.**

In a project, a C file that stays calls the Jac module's functions through its wire and the
module's header. Outside a project a function another file still calls is refused with E4002:
nothing would give that file the Jac. A call of a function a header of the project defines
`static inline` is refused with E4030 where no C module holds that header: once the file is Jac,
nothing would bind it.
