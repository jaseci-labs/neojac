---
description: C and C++ source compiled into a Jac program as a module - the cmodule.toml manifest and its keys, what Jac binds from the headers, wiring C modules together, C calling Jac, inline modules, C++ classes used and derived by Jac, and what goes wrong.
keywords: C module, cmodule.toml, {lib}, {platform}, {dir}, whole archive, inline C module, C++ module, C interface, calling Jac from C, jac/ header, static inline, C++ class, super.init, CRTP, libcxx, std_vector, header-only library, C data, extern, std_string, std_vector_iterator, std_atomic, headers per target, std_to_string, std_pair, C++ default argument, C++ function pointer, callback from C++
---
# C modules

A directory holding a `cmodule.toml` is a C module: C (or C++) source that a program compiles with
it and imports as it imports a Jac module. In a project (a directory with a `jac.toml`) the manifest
is a table of `jac.toml`, `[c."<directory>"]`, which neojac writes as that file: `neojac absorb
<directory>` takes an existing one in ([Packages](../toolchain/packages.md#rust-crates-c-modules-and-python-projects)). Clang, inside neojac, reads the module's headers, so the
program binds what they declare without writing declarations of its own, and compiles its sources
into the program. To call a library that is already built, declare its functions instead: see
[C libraries](c-libraries.md) (`neojac docs C library`).

A C module is one of two things, by who holds its manifest:

| | The project's own | A dependency |
|---|---|---|
| Its manifest | A table of `jac.toml`, `[c."<directory>"]` | A `cmodule.toml` in its directory that `jac.toml` does not hold: a vendored library, a loose module beside a program with no `jac.toml` |
| Its interface | What its own files declare: the headers its `headers` key lists, per target, or every header in its directory where it has no `headers` key; and each function and variable its C sources define, whether a header declares it or not | The headers its `headers` key lists |
| Under an `archwire.jac` | Its files are modules, and a wire names the file that defines what it brings ([below](#wiring-c-modules)) | One module, whole |

## The shortest example

A program with a C module `geom`, a directory beside `main.jac`. It needs no `jac.toml`: a loose
`main.jac` builds with the module beside it, as a project's does.

`geom/cmodule.toml`:

```toml
headers = ["geom.h"]
sources = ["geom.c"]
libs = ["m"]
```

`geom/geom.h`:

```c
#include <stdint.h>

#define GEOM_VERSION 2

typedef enum { SHAPE_SQUARE = 1, SHAPE_CIRCLE = 2 } shape_kind;

typedef struct {
    double x;
    double y;
} point;

typedef struct polygon polygon;

extern int64_t points_made;

point point_new(double x, double y);
double point_length(const point *p);
const char *shape_name(int32_t kind);
int64_t geom_sum(int32_t n, ...);
int64_t geom_fold(int64_t start, int32_t times, int64_t (*step)(int64_t, int64_t));
polygon *polygon_new(void);
void polygon_add(polygon *poly, point p);
double polygon_perimeter(const polygon *poly);
void polygon_free(polygon *poly);
```

`geom/geom.c` defines them. `main.jac`, beside `geom/`:

<!-- example: not checked: needs the C module geom beside the program -->
```jac
import from geom {
    GEOM_VERSION,
    SHAPE_CIRCLE,
    geom_fold,
    geom_sum,
    point,
    point_length,
    point_new,
    points_made,
    polygon,
    polygon_add,
    polygon_free,
    polygon_new,
    polygon_perimeter,
    shape_name,
}

def add(acc: int, i: int) -> int {
    return acc + i;
}

def square(side: float) -> ptr[polygon] {
    poly = polygon_new();
    polygon_add(poly, point(x=0.0, y=0.0));
    polygon_add(poly, point(x=side, y=0.0));
    polygon_add(poly, point_new(side, side));
    polygon_add(poly, point_new(0.0, side));
    return poly;
}

with entry {
    p = point_new(3.0, 4.0);
    print(GEOM_VERSION, p.x, point_length(&p), shape_name(i32(SHAPE_CIRCLE)));
    print(geom_sum(i32(3), 10, 20, 12), geom_fold(100, i32(4), add));
    sq = square(2.5);
    print(polygon_perimeter(sq), points_made);
    polygon_free(sq);
}
```

```sh
neojac build main.jac -o main && ./main
```

```text
2 3.0 5.0 circle
42 106
10.0 3
```

`import geom;` works too, and the names are then `geom.point_new` and so on. A C module is found as
any import's module is: by its dotted path from the importing file's directory or the project's
root (`import from vendor.zlib { ... }` for `vendor/zlib/cmodule.toml`).

## What Jac binds from the headers

Clang reads the headers for the program's target. What they declare in files under the module's
directory, and under the directory of each header they name outside it (a library's installed
API, such as Node-API's `node_api.h`), becomes Jac declarations, in the types a
[C library](c-libraries.md#types-in-a-declaration) declaration takes. Declarations of the system's
headers (`<stdio.h>`, `<stdint.h>`) are not part of the module.

| C | Jac |
|---|---|
| A function | A function; a variadic one takes extra arguments as `*args` does. One declared without a prototype (`long long count();`) takes no parameters where the module's definition of it takes none, as C reads an empty list in a definition |
| `int32_t`, `int` | `i32`; `int64_t`, `long long` are `int`, the other integer types their sized type |
| `double`, `float` | `float`, `f32` |
| `const char *` parameter | `str \| bytes \| bytearray \| ptr[i8] \| None`: the text, the bytes of a buffer, a pointer passed as it is, or `NULL` |
| `const unsigned char *` parameter | `str \| bytes \| bytearray \| ptr[u8] \| None`, as a `const char *` is, with a pointer to bytes passed as it is: `shape_octet_sum(b"\x01\x02\x03", 3)` |
| `const char *` result | `str \| None`, `None` for `NULL`; a C++ class's member gives `ptr[i8]` instead ([below](#what-jac-uses-of-c)), and so does the interface of a source a Jac module of `jac` replaces, for a parameter too ([below](#the-manifest)) |
| `char *` | `ptr[i8]`, whatever the target's `char` signedness |
| Any other pointer `T *` | `ptr[T]`; a parameter also takes `&x` or `&mut x` of a `T` variable, its address for the call |
| A pointer to a function | `Callable[[P, ...], R] \| None`, which a named Jac function is passed as, or `None` for `NULL`; a C function of a module is passed as its own address, to a parameter or a record's field: with `int64_t pick(int64_t (*f)(int64_t), int64_t x)` and `twice` of one module wired in, `pick(twice, 21)` is C's `pick(twice, 21)`. Where a Jac function takes it (`def applied(f: Callable[[int], int], x: int) -> int`), a C function that takes and gives numbers and pointers is a function value as a named Jac function is, which calls it as a direct call does: `applied(twice, 21)` |
| A `struct` | A record, constructed by keyword (`point(x=1.0, y=2.0)`, fields left out are zero), passed and returned by value |
| A `struct` declared but not defined (`typedef struct polygon polygon;`) | An opaque type, held as `ptr[polygon]`; its name is importable |
| A `struct` holding bit-fields, or arrays of numbers, pointers, function pointers or records | A record with [bit-fields and arrays](c-libraries.md#bit-fields-and-arrays), checked against Clang's layout: `void (*callbacks[32])(void);` is `callbacks: array[Callable[[], None] \| None, 32]` |
| A bit-field with no name, which only pads (`unsigned : 24;`, `unsigned : 0;`) | `_: u32: 24`, `_: u32: 0`: laid out as C lays it out, with no name a program reads |
| A trailing array of no length (`int32_t data[];`) | Left out of the record, whose size stays C's: it is the memory past the record |
| A `union`, a `typedef union` | A [union](../language/structs.md#unions), used by address and as a field, and passed and returned by value as the target's C calling convention passes it (`double number_value(union number n)` is `number_value(number(f=1.5))`) |
| A record with no name that is a field's type (`struct { union { ... } amount; }`) | A record named by its record and field (`shape_tagged_amount`), reached through the field |
| An anonymous member, a record with no name and no field name (`struct value { int32_t kind; union { int64_t whole; double real; }; }`) | A field `anon0` (the next anonymous member `anon1`) of a record named by its record and that name (`value_anon0`): C's `v.whole` is `v.anon0.whole`. Where the record has a field of its own named `anon0`, the member stays unnamed, and `neojac port` refuses a use of it |
| A record whose tag is also a function's name (`struct extent` beside `int64_t extent(struct extent *e)`) | A record named `struct_` and its tag, `obj extent as struct_extent` in the interface: `struct_extent(w=i32(6), h=i32(7))`. It is the one type `struct extent` is across the program, and a wire names it `struct_extent` (see [A record named in Jac other than by its tag](c-libraries.md#a-record-named-in-jac-other-than-by-its-tag)) |
| An `extern` variable | A global the program reads and assigns in place; one of an opaque type is used through `addressof()` |
| An enum constant, an integer `#define` | An `int` constant; a sign and a suffix (`(-17)`, `0xff00u`) are kept |
| A header's `static const` variable of an integer type, or of a record or a union whose value is integers and floats (`static const int SHAPES_STEP = 4;`, `static const union number SHAPES_ONE = { 1 };`) | A global of its value, which has no symbol in C either, each file that includes the header holding its own: `SHAPES_STEP`, of its type, and `SHAPES_ONE`, `number(i=1)` |
| A `static inline` function of a header | A function of its C name, called through a C shim the module compiles |

**A header's `static inline` function** defines no symbol, so neojac writes a shim for it: a C
function that calls it, compiled with the module's flags (as bitcode in an inline module, so the
call costs nothing once LLVM inlines it). The interface declares it under its own name, and the
program calls it as any C function: `shapes_point_sum(&pt)`. Only the shims of the functions a
Jac module imports are compiled, those of an included header (`Py_INCREF` of `<Python.h>`)
among them.

A declaration the interface cannot express is left out, and a module that imports it is told why
(E5133):

- a function taking or returning a union by value, or a record holding one: the calling
  convention of such a record is not bound;
- a `static inline` function taking C's `...`, which a shim cannot pass on;
- a record whose bound fields do not make C's size: an array of anything but numbers, pointers
  and records, a bit-field with no name, a layout that differs from Clang's;
- a global C array.

A name the headers do not declare at all is E1145.

## The manifest

```toml
headers = ["counter.h"]            # a dependency's interface, read with Clang
sources = ["counter.c"]            # compiled into every program using it
jac = ["clamp.jac"]                # Jac modules its sources were ported to (below)
language = "c++"                   # its headers are C++ though they end in .h (below)
include = ["include"]              # header directories
defines = ["NDEBUG", "LEVEL=2"]    # -D, as NAME or NAME=VALUE
cflags = ["-fwrapv"]               # other Clang flags, for every source
cxxflags = ["-std=c++20"]          # Clang flags for its C++ sources alone
libs = ["m"]                       # C libraries its code calls
ldflags = ["-Wl,--gc-sections"]    # options for the linker of what it is linked into (below)
archives = ["lib/libfoo.a"]        # static libraries linked with its code
whole_archives = ["lib/libapi.a"]  # static libraries linked whole
also_in = ["vendor.engine"]        # C modules whose archives hold this code already (below)
crates = ["{lib}/node/crates"]     # Rust crates outside the project its code links (below)
inline = true                      # compiled to bitcode, inlined with the Jac (below)
export = true                      # the program exports its symbols (below)
shared = "counter"                 # built into a shared library beside the program (below)
vendored = true                    # another project's code, kept in this one (below)
interpreter = true                 # an interpreter's C API: an extension module links none of it (below)

[files."counter.c"]                # flags for one source, besides the module's:
defines = ["COUNTER_FAST"]         # include, defines and cflags

[target.linux]                     # added for one target
sources = ["counter_posix.c"]

[target.darwin]
frameworks = ["CoreFoundation"]    # macOS frameworks its code calls
```

- `name` (in a project's table) gives the module a key of its own, by which a wire names it
  (`[c."probe/arch"] name = "_probe"`, `_probe ++> main { ... }`); the table stays keyed by its
  directory. It is identifiers joined by `.`, and a key no Jac or Python module of the program
  has (E2270). `neojac absorb --record` writes it, as the last part of the extension module the
  module is built into. Without it the module's key is its directory. A module at the
  project's root, whose directory names no module, takes a `name` (E5132 otherwise), which
  `neojac absorb` writes as the directory's own name. A program that reaches the
  module both by its `name` and through the wires of the files it holds (a ported file's
  `_probe ++> probe.arch.osx { ... }` beside a C file's own `-->` wires) reaches one module,
  built and linked once. A wire from the module, where its directory is also a Python package,
  names it by its `name`: the directory's dotted name is the package's (E2270).
- `headers`, where the table has the key, is the module's whole list of headers. An entry is a
  path from the module's directory, or `<name>`, a header found on the module's include path,
  the system's included (`headers = ["<Python.h>"]`). A module whose sources are all gone (every
  one ported to Jac) stays a module over such headers: its interface binds what the wires name,
  their `static inline` functions included, through a shim neojac compiles. A header beside a
  Jac module of its stem is that module's face to C ([below](#calling-jac-from-c)), never one of
  a C module's headers.
- Every key is optional. A dependency with no `headers` (one that is only `archives`, say: a
  library built elsewhere) has no interface: a program binds its functions by declaring them
  (below). A module of the project's own takes its interface from its files: the `headers` it
  lists, which may differ by target (`[target.linux] headers = [...]`), as
  `neojac absorb --record` writes them from what each platform's build read; where it has no
  `headers` key, every header of its directory. A module an extension module's record names is
  read for the platforms that record lists alone (`[extensions."<path>"] recorded`), as its build
  and `neojac port` read it; one no record names is read for every platform. A directory that holds every platform's headers
  (`arch/linux/init.h` beside `arch/osx/init.h`) names each target's, so that no target reads
  another's. A header of the project outside the module's directory that its build reads
  (`../include/clamp.h`) is the module's when `headers` names it: its `static inline` functions
  are bound with the module's, and a header of the project that defines such functions belongs
  to one C module, the one whose build reads it, as `absorb --record` writes it.
- Paths in `headers`, `sources`, `include`, `archives`, `whole_archives`, a files table's name
  and its `include` are relative to the module's directory, and may climb out of it
  (`archives = ["../../api/libplain.a"]`). A files table's `include` must name a directory
  (E5132).
- A target table is named by an operating system (`darwin`, `linux`, `windows`), an architecture
  (`x86_64`, `aarch64`) or both (`"darwin.aarch64"`). What it holds is added to the module's lists
  when the program is built for that target; it may hold files tables too.
- `frameworks` names the macOS frameworks the module's code calls, so it belongs in
  `[target.darwin]`. At the top level it
  is refused (E5132, `macOS's go in [target.darwin]`) in a build for another operating system.
- `{lib}` in a path is the toolchain's `lib/`, which neojac carries inside itself and writes out
  into its cache as a build needs it, and `{platform}` the program's platform (`linux-x86_64`,
  `macos-aarch64`, `windows-x86_64`, ...). So a module builds on the C libraries the toolchain
  has for each platform, another platform's fetched with that platform's neojac the first time
  ([build](../toolchain/build.md#--target-building-for-another-platform)):

  ```toml
  include = ["{lib}/clibs/{platform}/include"]
  archives = ["{lib}/clibs/{platform}/lib/libz.a"]
  ```

  A path naming any other place (`{root}`) is E5132.
- A define's value may name `{lib}`, `{platform}` and `{dir}`, the module's own directory, each as
  a C string's contents: `defines = ['DATA_DIR="{dir}/data"']`.
- An assembly source (`.S`, `.s`) is compiled too.
- `prebuilt_shared = "lib/foo"` (Windows) links `lib/foo.lib` and copies `lib/foo.dll` beside the
  program.
- An archive may have a shared library that holds the same code: a file `<archive>.shared` beside
  it names the library, by a path from the archive's directory (`libfoo.a.shared` holding
  `libfoo.so`). On Linux a plain build then links the library, not the archive, and the program
  finds it where it was at the build; a `--release` build links the archive in
  ([build](../toolchain/build.md#--release)). The LLVM a build of neojac itself links says this
  of its archives.
- `crates` names Rust crates the module's code links, by their directories, each holding a
  `Cargo.toml`: each is built in the program's one Rust link, against its one standard library,
  and wired whole into the C module, as `crate ++> cmod` does. It is for a crate the project's
  `archwire.jac` cannot name, outside the project (the toolchain's own: Node's crate is
  `{lib}/node/crates`); the project's own crate there is E5132, since its wire is the one way.
- `vendored = true` says the module is another project's code kept in this repository (a
  library's amalgamation, a dependency's sources): it is built as it is, and
  [`neojac port`](../toolchain/port.md#in-a-project) reads none of it (a path into it is E4011).
  No tool can tell that from the files, so `absorb` never writes it: the project says it. An
  extension module or an addon that uses it links it by its row's `links`
  ([Extension modules](../toolchain/packages.md#extension-modules)), and never takes its
  functions from the process that loads it (E5270); the extension exports its entry points alone,
  so its calls of them reach its own copy on every system.
- `jac` lists the Jac modules the module's own sources were ported to, by paths from its
  directory: [`neojac port`](../toolchain/port.md#in-a-project) takes a source off `sources` and
  lists its Jac here. They are the module's code as its C was, never a space's: a program, an
  extension module or a Node addon built from the module links them with the sources that stay,
  and no npm tree's space takes them, whatever the tree's `files` names. A module all of whose
  C++ sources were ported keeps `language = "c++"`, which port writes, so that its headers are
  still read as C++ ([C++ sources](#c-sources)).
- **A Jac module of `jac` binds what its source's translation unit declared**: its files table
  holds `headers`, the headers its source included, in their order (a path from the module's
  directory, or `<name>` for one found on the include path), with each macro the source set
  between two of them where it stood (`{ define = "OFF(x)=offsetof(PyFunctionObject, x)" }`,
  `{ undef = "X" }`: `headers = ["Python.h", { define = "OFF(x)=offsetof(PyFunctionObject, x)" }, "structmember.h"]`),
  and the flags the source was compiled with (`include`, `defines`, `cflags`), which port writes.
  Its interface is those headers read in that order, each macro set where it stands, and what a
  part of the source (a header only it includes that defines functions, ported with it) includes,
  where the part stood, under the
  module's flags and its own, with what the module's other
  sources define that its wires name and the headers do not declare. A C string there is the
  pointer C has, with its `NULL` and its identity, as the ported C keeps it: a `const char *`
  parameter and result are `ptr[i8]` (a `const unsigned char *` `ptr[u8]`), as a field and a
  global are, where the interface a program writes against the module gives a `str`, a copy.
  What it takes from another C module read as C++ (a header library's class, function or record)
  it binds from that module, which owns its classes: a class is one Jac class wherever it is
  named, and libc++'s templates over it are made by that module's reading. libc++'s own headers
  are no module's but `libcxx`'s, so a translation unit that includes `<string>` binds
  `std::string` from `libcxx`, as a header library that includes it does.
  A target table holds a target's own headers, after the base table's. The module's interface proper is read only
  where something other than its own Jac modules binds from it.
- `interpreter = true` says the module is an interpreter's C API, which the interpreter that
  loads an extension module gives it: a program that is an extension module
  ([Extension modules](../toolchain/packages.md#extension-modules)) compiles against the
  module's headers and links nothing of it, neither its sources nor its archives, libraries and
  frameworks, and takes those functions from the interpreter that loads it (on macOS it is linked
  as a bundle whose undefined symbols the loader resolves, as a C extension is). neojac's CPython
  says it of itself.
- A key the manifest does not know is E5132.

### Shared, exported and whole

- **`shared = "<name>"`** builds the module's code into a shared library, `lib<name>.so`,
  `lib<name>.dylib` or `<name>.dll`, which the build writes beside the program and the program
  loads. Every module naming the same `shared` goes into the same library. A build writes the
  library again when it is missing, and programs built into one directory share it.
- **`export = true`** makes the program export the module's symbols, those of its sources and of
  the static libraries it links, as an interpreter linked with `--export-dynamic` does, for the
  shared libraries the program loads to link against. Nothing else of the program is exported:
  its Jac, the other C modules (what their assembly sources define included) and its Rust
  modules are linked hidden. That holds for an ELF or Mach-O program. A Windows program exports nothing this way: there what an interpreter exports
  is its DLL's, as CPython's C API is `python315.dll`'s.
- **`ldflags`** are options for the linker of what the module is linked into: the program, or the
  extension module built from it. One written as a compiler driver is told, `-Wl,a,b`, is the
  options `a` and `b`. They are the linker's own (ld64's on macOS, ld's on Linux), so they belong
  under `[target.<os>]` wherever they differ, and an option the linker has none of fails the link.
- **`whole_archives`** links every object of an archive, not only those the link reaches. That is
  what a module that exports a C API needs of a library whose functions it exports though nothing
  in the program calls them.
- **An archive several modules name**, by one path or by several leading to the same file, is
  linked once into each output (the program, or a `shared` library), and whole if any of them
  lists it in `whole_archives`.
- **`also_in`** names, by their dotted names, the C modules that already hold this module's
  code: a library another module links whole that was built with these same sources. In a
  program with one of them the sources are not compiled, and the functions the headers declare
  are that module's; the code is in the program once either way. The runtime's expat is such a
  module: the interpreter a program using Python links has expat built in, under the same
  names.

## Inline modules

A module whose manifest says `inline = true` compiles to LLVM bitcode instead of objects, and the
program's module links it in, each source a unit of its own. The optimizer then inlines across its
C and the Jac, as it does between Jac modules, at the cost of optimizing its code again with the
program's on every build. C's own constructs carry through: `__attribute__((constructor))` functions run before
the program's code and `destructor` ones after it, and `used` data, weak references and computed
gotos are kept. `neojac build --c-archive` builds no program, so there an inline module compiles to
objects, which the archive holds with every other module's.

## C++ sources

A source Clang takes for C++ by its name (`.cc`, `.cpp`, `.cxx`, ...) compiles as
[`neojac c++`](c-and-cpp.md) compiles it, with libc++ and the module's `cxxflags` besides its
`cflags`. A header ending in `.h` that is C++ (a header-only library) is read as C++ when the
module's table says `language = "c++"`; a module with no sources may list its `headers` alone.
A C++ library built already is such a module that lists its `headers` and the `archives` it
links (LLVM's): Jac uses it as it uses a header-only library, a member its headers define
(inline, or a template's) called through the module's shim and one defined out of line at its
symbol in the archives.

C++ static objects are constructed before the program's code runs. Every program and shared
library links the toolchain's C++ runtime (libc++, libc++abi, and libunwind except on macOS)
statically, after everything else, so the linker takes only what something references, and a
program that references none of it links none.

### What Jac uses of C++

A C++ file is wired into Jac as a C file is (`shapes.figures ++> main { Figure, Rect, scaled }`),
and Jac uses what it declares as C++ means it, through C-ABI shims neojac compiles from it.
Nothing needs to be `extern "C"`.

| C++ | Jac |
|---|---|
| A class | An `obj`, its methods called as Jac's: `r.area()`, `Figure.alive()` for a static one |
| A constructor | `C.make(args)`; a class that declares none has `make()`. A class with a static method `make` of its own keeps that name for the method, and names its constructors by their parameters, always: `make_()` for the default one, `make_i32(n)` for `C(int)`. `C()` is the default constructor, where the class has one the interface binds; a call of the class with arguments, or of one with no default constructor, is E1621 |
| A constructor template | Each instance the program's C++ or its port names, a constructor named by its parameters as any other: `std::string s(p)` is `std_string.make_ptr_i8(p)` |
| A copy, a destructor | `v.__copy__()`. An object whose destructor runs code is destroyed where its `own` owner's scope ends ([below](#c-values-whose-destructor-runs-code)); any other by `__del__`, when the Jac object is freed |
| Single inheritance | The Jac classes derive each other: a `Rect` is a `Figure`, and a virtual call runs C++'s final overrider |
| An overload set | One function a member, named by its parameters' interface types: `scaled(double)` is `scaled_f64`, `scaled(int, int)` `scaled_i32_i32`, a second constructor `make_i32`; a name with one member keeps it. A member's bare name where it is overloaded (`s.compare(t)`) is E5133, whose reason lists the overloads by their names |
| A method that hides a base's method of its Jac name, with other parameters | Named by its parameters, as an overload is, so that the base's stays reachable: `Rect`'s copy assignment, which hides `Figure`'s, is `r.op_assign_Rect(other)` beside the inherited `op_assign`; one of no parameters is named `_none` |
| An operator, a conversion | A method named `op_` and the operator's word: `c[i]` is `c.op_index(i)`, `a == b` `a.op_eq(b)`, `s += t` `s.op_iadd(t)`, `c = d` `c.op_assign(d)`; a conversion `op_to_` and its type, `operator int()` `c.op_to_i32()`. Overloads are named apart as any member's. A class with a copy and a move assignment binds the move beside the copy as `op_assign_move`: `a = std::move(b)` is `a.op_assign_move(b)`. Jac's own `a == b` or `a != b` of two values of C++ classes is E1624: it would compare the Jac objects |
| An overload taking `T&&` beside one taking `const T&` | The rvalue one is the member's name and `_move`, the other keeps the name: `v.push_back(x)` copies `x`, `v.push_back_move(x)` moves it, as `a = std::move(b)` is `op_assign_move` |
| A non-member operator template | A function of the module named `op_` and the operator's word, its instance named at the call ([below](#function-templates)): `box + 2` is `op_add[i32](box, 2)`. A non-member operator that is no template is not bound |
| A parameter whose default is a constant | Optional to a Jac caller, the default C++'s: `s.find_i8_uword(c)` is `s.find(c)` from position 0, and `s.substr(u64(1))` leaves `substr`'s `n = npos` to the member. Only a trailing run of such parameters; a default that is no constant (`int then = seed()`) leaves its parameter, and those before it, required |
| A result by value | Owned by Jac; a result by reference is borrowed |
| A member's `const char *` result (`s.c_str()`, `s.data()`) | `ptr[i8]`, the pointer into the object; where C++ declares it so (`std`'s strings), a loan of it: the object is kept while the pointer is used ([below](#a-pointer-into-an-object)). `str(p)` copies its text (`str(s.c_str())`), and `print(p)` prints it ([Pointers](pointers-and-native-memory.md#what-a-pointer-does)). A free function's `const char *` result is `str \| None`, a copy, as a C function's is |
| A result that is a reference to a number or a pointer (`int &operator[](size_t)`, `int &at(size_t)`) | The read, and beside it the store through the reference, the member's name and `_set`: `v.op_index_set(i, x)` for `v[i] = x`, `v.at_set(i, x)` for `v.at(i) = x`. None where a member of that name exists, and none for `const char *&` |
| A pointer parameter or result | Typed as C++ types it: `int *` is `ptr[i32]`, `napi_value` (`struct napi_value__ *`) `ptr[napi_value__]`, `X **` `ptr[ptr[X]]`; a C record no header of the module declares is declared by the interface (`obj napi_value__;`), one type across the program with C's |
| A parameter that is a reference to a class (`const C&`, `C&`) | A borrow, `c: &C`: the Jac object is lent for the call, and an assignment through the reference is `op_assign` |
| A record C could declare (a C struct, or a record of an `extern "C"` block), by value, by const or rvalue reference, or by pointer | The C record, one type across the program by its tag and members, given and taken by value as C passes it, and `ptr[R]` by pointer. By non-const reference it is not bound: Jac would copy it, where C++ writes through |
| A pointer to a function of C++ types (`int (*f)(Counter &, int)`) | Its Jac form, `Callable[[Counter, i32], i32]`, given a def or a static method by its name, for a member's parameter or a free function's ([below](#a-jac-function-c-calls-back)); a pointer to a function of C types (`int (*f)(int)`) the same, `h.scaled(plus_one, i32(5))` |
| A pointer to a member function of the class a Jac class derives (`int (T::*m)(int)`) | A method of the Jac class by its class, `Drop.plus_size` ([below](#a-jac-method-c-calls-through-a-pointer-to-a-member-function)) |
| `std::initializer_list<E>`, by value or `const &` | A Jac list, `list[E]`, its items made into `E`s one by one as braces make them: `total(std::initializer_list<int>)` is `total([i32(1), i32(2)])`. Where `E` has exactly one constructor from one class or C record, the list holds those (`list[R]`); an `explicit` one raises `ValueError` when the call runs. The overload is named `list` among its set's (`define_ptr_i8_list_ptr`). A `const std::vector<E> &` stays `&std_vector[E]` |
| A pointer to a record no header gives the members of (`napi_value`) | C's opaque handle, as a C function's is ([above](#what-jac-binds-from-the-headers)): a member taking or giving one is bound |
| `std::string`, `std::vector<int>`, `std::lock_guard<std::mutex>` | `std_string`, `std_vector[i32]`, `std_lock_guard[std_mutex]`: libc++'s classes, of the module `libcxx` ([below](#the-c-standard-librarys-classes)) |
| A pointer as a template's argument (`std::vector<Vt *>`) | `ptr[T]`: `std_vector[ptr[Vt]]`, `emplace_back[ptr[Vt]]`, a C record behind it the same type as C's |
| A thrown exception | A Jac exception: `std::out_of_range` is `IndexError` |
| A member function template | `o.m[A, B](args)`, the instance `m<A, B>`, made for the program ([below](#member-function-templates)) |
| A function template of a header library | `f_[A, B](args)`, the instance `f<A, B>`, made for the program ([below](#function-templates)) |
| A class template of the module | `T[A, B]`, the class `T<A, B>` by its template form, made for the program ([below](#class-templates)); a Jac class may derive one made with itself (CRTP, below); the standard library's are `libcxx`'s |

A wire may name an overload set by its C++ name, and binds each member: `tally.tally ++> main {
twice }` binds `twice_i32` and `twice_f64`, which the Jac code calls.

A header library's function is the module's wherever in its directory it is defined: node-addon-api's
`napi.h` declares functions that `napi-inl.h`, a header only `napi.h` includes, defines. A wire
names it from the header the module lists (`headers = ["napi.h"]`), and so does a use of it from
another C++ file of the project. Of a library that lists several headers (LLVM's, which a file
reaches through as many as it includes), a wire names a class or a function from the header
that declares it: `toolchain.llvm.include.llvm.IR.Module ++> app.units { Module }`.

### Member function templates

A call of a C++ class's member function template names its instance by type arguments in brackets,
as a call of a Jac generic method may ([Generics](../language/generics.md)): `o.m[A, B](args)` calls
`m<A, B>`, and a static one is called by its class, `C.m[A](args)`.

- **Its type arguments are Jac types**, as the interface writes C++ types: a class of the module, a
  `libcxx` class, or a number type (`i32` for `int`, `int` for a 64-bit integer, `float` for
  `double`).
- **A type argument says what C++ instantiated**: `T` is the type by value, `&T` is
  `const T &` and `&mut T` is `T &`, as a def's parameter given to C++ is read.
  `said.emplace_back[std_string](s)` is the instance for an rvalue, which moves `s` into the
  vector; `said.emplace_back[&mut std_string](s)` is `emplace_back<std::string &>`, the instance
  C++ makes for `said.emplace_back(s)` of a local, which copies it, and `[&std_string]` the one
  for a `const` string. A number given by reference is its place, a `ptr`:
  `duos.emplace_back[&mut i32, &mut i32](addressof(a), addressof(b))` takes the addresses of
  two `i32` locals, as port writes an `int` local whose address C++ takes.
- **A template is named by its C++ name** where the class has one template of that name. Templates
  of one name are named as an overload set's members are, by the types of the parameters that do
  not name the template's own: `add(const T &)` is `add_`, `add(const char *, const T &)` is
  `add_ptr_i8`.
- **The program's build makes each instance it names**, though nothing in the C++ makes it: the
  module's headers are read again with the instance asked for, and the interface binds it as a
  member of the class. A result of a class type is owned, as any result by value is.
- An instance the template does not take, or whose argument is no class or number type of C++, is
  E1620 where the program names another instance of the template that the build makes. Where it
  names none, the class has no member of that name, and the call is E1030 (`Counter has no field
  'to'`). E1030 names the class as the program writes it, an instance by its template form:
  `said.nothere[std_string, i8](i8(1))` of a `std_vector[std_string]` is
  `std_vector[std_string] has no field 'nothere'`, and the type arguments after the name are not
  judged.

The header library `tally/tally.h`, a C module of the project with `language = "c++"`:

```cpp
class Counter {
public:
    explicit Counter(int start) : count(start) {}
    int value() const { return count; }
    template <class T> T to() const { return T(count); }
    template <class T> int add(const T &x) { count += int(x); return count; }
    template <class T> int add(const char *why, const T &x) { count += int(x) * 2; return count; }

private:
    int count;
};
```

<!-- example: not checked: needs the C module tally, wired tally.tally ++> main { Counter } -->
```jac
with entry {
    c = Counter.make(i32(7));
    again = c.to[Counter]();
    print(c.to[float](), again.value());
    print(c.add_[i32](i32(2)), c.add_ptr_i8[float]("half", 1.5));
}
```

```text
7.0 7
9 11
```

### Function templates

A header library's free function template is called by its instance, named by type arguments in
brackets as a member template's is: `kept_[Counter](c)` calls `kept<Counter>`.

- **A name that has templates names all its members by their parameters**, as an overload set's
  are, a template by the types of the parameters that do not name the template's own: beside
  `template <class T> T kept(T v)`, `int kept(const char *why)` is `kept_ptr_i8`, and the template
  is `kept_`. A wire names the set by its C++ name (`tally.tally ++> main { kept }`), and binds
  both.
- **A non-member operator template** is named `op_` and the operator's word, as a member operator
  is: `template <class T> Box<T> operator+(const Box<T> &, const T &)` is `op_add`, and `box + 2`
  is `op_add[i32](box, i32(2))`.
- **Its type arguments are Jac types**, and **the program's build makes each instance it names**,
  as a member template's ([above](#member-function-templates)).
- An instance the template does not take, or whose argument is no class or number type of C++, is
  E1622.

With `tally/tally.h` holding

```cpp
template <class T> T kept(T v) { return v; }
inline int kept(const char *why) { return static_cast<int>(__builtin_strlen(why)); }
template <class T> Box<T> operator+(const Box<T> &a, const T &b) { return Box<T>(a.get() + b); }
```

<!-- example: not checked: needs the C module tally, wired tally.tally ++> main { Box, Counter, kept, op_add } -->
```jac
with entry {
    c = Counter.make(i32(13));
    print(kept_[Counter](c).value(), kept_[float](2.5), kept_ptr_i8("four"));
    print(op_add[i32](Box[i32].make(i32(1)), i32(2)).get());
}
```

```text
13 2.5 4
3
```

### Class templates

A class template of the module is named by its template form, as the standard library's are
([below](#the-c-standard-librarys-classes)): `T[A, B]` is the C++ class `T<A, B>`, its arguments
Jac types as the interface writes C++ types (a class of the module, a `libcxx` class, a number
type). It is the module's own class, the same Jac class its functions take and give, with its
constructors, methods and operators bound as any class's are. The program's build makes each
instance the program names, whether or not the module's C++ reaches it.

With `tally/tally.h` holding

```cpp
template <class T> class Box {
public:
    explicit Box(const T &v) : held(v) {}
    T get() const { return held; }

private:
    T held;
};

inline Box<int> boxed(int v) { return Box<int>(v); }
```

<!-- example: not checked: needs the C module tally, wired tally.tally ++> main { Box, Counter, boxed } -->
```jac
with entry {
    bx: Box[i32] = boxed(i32(5));
    print(bx.get(), Box[i32].make(i32(6)).get());
    tc = Counter.make(i32(13));
    made = Box[Counter].make(tc);
    print(made.get().value());
}
```

```text
5 6
13
```

`Box[i32]` is the class `boxed` gives; `Box[Counter]` is an instance nothing in the C++ makes.
An instance whose argument is no class or number type of C++ is refused by name.

- **A member template of an instance only the program names is made for it too.** With `Box`
  holding `static int keep(int v)` and `template <typename F> static int keep(int v, F f)`, which
  makes a `Counter` of `v` and returns `f(c, 1)`, `Box[i16].keep(i32(4), bump_by)` is the
  instance of `Box<short>::keep` for `bump_by` ([A Jac function C++ calls
  back](#a-jac-function-c-calls-back)), though nothing in the C++ makes `Box<short>`, and
  `Box[i32].keep(i32(3))` the static that is no template.

- **Classes or class templates of one name in two namespaces** (napi's `AccessorCallbackData` in
  `Napi` and in `Napi::details`) are each named by their qualified name, its parts joined by
  `_`: `tally::Pair<T>` is `tally_Pair[T]` and `tally::inner::Pair<T>` `tally_inner_Pair[T]`, as
  `tally::Mark` and `tally::inner::Mark` are `tally_Mark` and `tally_inner_Mark`. A wire names
  them so. A name only one class of the library has keeps its last part (`Box`).
- **An instance a library gives through a name of a class template's own** (napi's
  `ObjectWrap<T>::PropertyDescriptor`, which names `ClassPropertyDescriptor<T>`) is named by the
  instance it names, never by that name: `Keeper<T>::Weight`, a `Tag<T>`, is `Tag[T]`, and the
  library's own class `Weight` stays `Weight`.

### A Jac class deriving a C++ class

A Jac class may list a C++ class as its base, where C++ allows a class to be derived: it is
polymorphic, not `final`, and its destructor is public or protected. Its `init` makes the
object's C++ part with `super.init(args)`, C++'s `: Figure(4)`, as its first statement: the base's
constructor runs before the rest of `init`, as C++ runs a base's constructor before the derived
body. Where the base has several constructors a subclass may call, public or protected, each is
named as `make`'s overloads are, with `init` for `make`: `super.init_f64_f64(2.0, 3.0)`.

<!-- example: not checked: needs the C module whose figures.hpp declares Figure and described -->
```jac
obj Square(Figure) {
    has side: float;

    def init(side: float) {
        super.init(i32(4));
        self.side = side;
    }

    override def area -> float {
        return self.side * self.side;
    }
}

with entry {
    sq: own Square = Square(3.0);
    print(str(described(sq).c_str()), sq.sides());
}
```

```text
figure/4/9 4
```

`described` is C++, and calls `area`, which Jac overrides, and `name`, which `Figure` defines.

- **`super.init` is the first statement of `init`**, and stands nowhere else: after another
  statement, a second time, or in another method it is
  [E2335](../reference/diagnostics/e22-4.md#e2335). It runs the direct base's own constructor,
  so no other class's can be reached through it. Where `init` writes no `super.init`, or the
  class has no `init`, the base's constructor that takes no arguments makes the part, before
  `init`'s body runs (after the fields' defaults and before `postinit` where there is no
  `init`); where the base has none, that too is E2335.
- **The C++ part is a subclass of `C`** whose overrides of every virtual method of `C` and its
  bases call the Jac object's method of that name. A method the Jac class does not override, and
  `super.area()`, run C++'s own definition. A pure virtual method the Jac class does not
  override raises `NotImplementedError` when called.
- **A virtual method that is not public is forwarded too.** A `protected` one, pure or with a
  definition of its own (napi's `AsyncWorker::Execute` and `OnOK`), is overridden as a public one
  is (`override def run`), and C++'s own calls of it reach the Jac method; `super.done(r)` runs
  C++'s definition. Jac has no `protected`: a program may call such a method on an object of a
  class that derives the C++ class, and on an object no Jac class derives it raises
  `RuntimeError`.
- **A class whose `private` virtual has a definition of its own cannot be derived**: that
  definition is one only the class itself calls, which no Jac override may take the place of. Nor
  can a class with no virtual method. An `obj` that names such a class as its base is E5133
  where it is declared, with the reason (`'Plan.init' of the C module 'tally' cannot be bound: a
  Jac class cannot derive it: its virtual method step: it is private, and its definition is one a
  class deriving it cannot call`, or `it has no virtual method, and a Jac class derives only a C++
  class C++ calls through one`); the class itself is bound, and Jac makes and uses it as it is. A
  class a Jac class may derive is derived the same way from any header, one that declares no
  template among them.
- **The Jac object owns its C++ part**, which is deleted when the Jac object is dropped: a class
  whose destructor runs code makes the deriving class an owned value too, bound `own`.
- **The Jac class's `destroy` is its C++ part's destructor's body.** It runs once, when the part
  ends, before the base's destructor: where Jac drops the object, and where C++ deletes the part
  (`delete f` of the `Figure *` it was given). A C++ class with a member named `destroy` cannot
  be derived, and its interface says why (E5133).
- **A call that reaches the C++ part after it has ended**, or before it was made (a base
  member, or the object given to C++), raises `RuntimeError`: "the C++ Figure part of this object
  was never made, or has ended". What is the Jac object's own, its fields and the methods it
  defines, still answers.
- **A virtual method takes** numbers, C strings, pointers and classes (given to Jac borrowed), and
  gives nothing, a number, a pointer or a copyable class by value. A class with any other
  virtual method cannot be derived, and its interface says why (E5133).

**A class template made with the deriving class**, C++'s CRTP, is a base too:
`obj Heavy(Counted[Heavy])` is `Counted<H>`, where `H` is Heavy's C++ part, a C++ class the
program's own C++ unit declares. Its members are Heavy's methods of number and `bool` types, each
calling the Jac method, so what the template calls on `T` reaches Jac, and its overrides of
`Counted`'s virtual methods call Heavy's. As a base, only an instance whose arguments name
the deriving class itself, besides number types, is made; a Jac class deriving any other
instance, or a class template a C++ source rather than a header defines, is refused by name. A
program whose C++ instances do not compile (a Jac method's types disagree with the template's
virtual of that name) is E5200.

<!-- example: not checked: needs the C module whose figures.hpp declares Counted -->
```jac
obj Heavy(Counted[Heavy]) {
    has w: int = 5;

    def init(w: int) {
        super.init();
        self.w = w;
    }

    def weight -> int {
        return self.w;
    }

    override def unit -> i32 {
        return i32(3);
    }
}

with entry {
    hv: own Heavy = Heavy(7);
    print(hv.tally(i32(2)), hv.unit());
}
```

```text
13 3
```

#### C++ making the Jac object

A class template a header library declares may make the class it is made with, as a library that
keeps its users' objects does: `Keeper<T>::make(seed)` runs `new T(seed)`. A Jac class deriving
it, `obj Kid(Keeper[Kid])`, is then made by C++ too: `new T(seed)` makes the Jac object, running
its `init` with those arguments, and its `super.init` takes the C++ part C++ is making. `init`'s
parameters are C++'s constructor's: numbers, `ptr` and C++ classes taken by `&`, as
`def init(w: &Weight)` takes the `Weight` C++'s `new T(w)` lends it. Since C++ constructs the base
before any of `init` runs, each argument of `super.init` is one of `init`'s parameters, passed as
it is, once. A parameter C++ cannot give (a `str`), or another argument, is
[E2336](../reference/diagnostics/e22-4.md#e2336) where `init` declares it.

- **`T *` and `T &` are the Jac object itself.** A member of the base that gives `T *`
  (`static T *last()`) gives the object C++ holds, or `None` for a null pointer, typed as the
  class deriving the instance: `Keeper[Kid].last()` and `Kid.last()` are a `Kid | None`. Called
  through a class deriving `Kid` (`Grandkid.last()`) it is a `Kid | None` too, as C++'s
  `Keeper<Kid>::last()` gives a `Kid *` whoever calls it; the object it gives may be a `Grandkid`.
  A member that takes `const T &` takes the object, of `Kid` or of any class deriving it. A `T` by
  value is not bound.
- **An object C++ made is C++'s until C++ deletes it** (`delete` in `Keeper<T>::end()`): the
  delete runs its `destroy`, ends its C++ part and lets the Jac object go. An object Jac made
  ends where its owner drops it, as any other.
- **An object the program makes for C++ to keep** is lent to C as any Jac object is
  ([Pointers](pointers-and-native-memory.md)): `k: Kid = held[Kid](hold(Kid(4)));` is held until
  `release(held_at(k));`, which is how a port writes C++'s `new Kid(4)` and its `delete k`. Given
  where the base is taken (`base: Keeper[Kid] = k;`), it is the object itself.

<!-- example: not checked: needs the C module whose tally.h declares Keeper -->
```jac
glob gone: list[str] = [];

obj Kid(Keeper[Kid]) {
    has seed: int = 0,
        seen: bool = False;

    def init(seed: i32) {
        super.init(seed);
        self.seed = int(seed);
        self.seen = Kid.last() is self;
    }

    override def step -> i32 {
        return i32(self.seed * 10);
    }

    def destroy {
        gone.append(f"kid {self.seed}");
    }
}

with entry {
    made = Kid.make(i32(3));
    k = Kid.last();
    print(made, k is not None and k.seen, Kid.run(i32(2)), Kid.end(), Kid.run(i32(2)), gone);
}
```

```text
33 True 60 True -1 ['kid 3']
```

`make`, `run` and `end` are C++: `make` gives what its object's `step()`, Jac's override, gives
plus the seed, and `run` is `-1` once `end` has deleted the object.

A Jac class with no `init` of its own is made by C++ too, `new T()` running its base's default
constructor.

**Not done.** These parts of a Jac class deriving a C++ class are not built yet:

- a static of the object's class given by its address;
- C++ making the object for a class template a C++ source module's header declares, rather than a
  header library: such an instance is made in `libcxx`'s unit, and has no constructor for `init`
  yet.

### A Jac function C++ calls back

A C++ library that keeps a function and calls it later takes a pointer to a function of C++
types: `void on_bump(int (*f)(Counter &, int))`, or a free function that calls the one it is
given, `int with_counter(int (*f)(Counter &, int), int start)`. A Jac function is given there by
its name, as a C callback is ([Callbacks](c-libraries.md#callbacks)), and C++ calls it through a
function the interface writes for that pointer type and that Jac function.

- **The parameter is the pointer's Jac form**, `Callable[[Counter, i32], i32]` for the member
  above, and the function given must have exactly that signature. A class the pointer takes,
  by reference or by value, is the library's class in the Jac signature
  (`def bump_by(c: Counter, step: i32) -> i32`): one taken by reference is the object C++ holds,
  lent to the call, so what the function does to it C++ sees; one taken by value is a copy the
  function owns. A class the function gives back by value is given to C++ as a copy.
- **A def or a static method, given by its name**: a def of the calling module (`bump_by`), a def
  another module gives (`jhelp_bump`), or a static method by its class (`Bumper.by_ten`). A
  lambda, a bound method, a function with captures, or a def of another signature is E1639.
- **An exception the function raises unwinds C++'s frames** as a C++ exception, running their
  destructors, and is raised again in the Jac code that called the outer C++ function, as the
  same object (`e is` what was raised). Where the module's C++ is built without exceptions
  (`-fno-exceptions` in its `cxxflags`), nothing can unwind it: the program ends where the
  function raises, printing the function and the pointer's C++ type (`the Jac function
  jmain.bump_refused raised an exception through the C++ pointer to a function int
  (*)(tally::Counter &, int), in C++ built without exceptions`) and the exception's traceback.
- **In a program, it is called on the thread that called into C++.** Jac never runs beside the
  thread running Jac, so a library that calls the function from a thread of its own ends the
  program there, printing the function and the rule the call breaks: `neojac: the Jac function bump_by was
  called from C++ on a thread other than the one that started the program, while the program
  runs Jac on that one thread alone`, or, where the program has started threads of its own, `on
  a thread whose state the Jac runtime never set up`.
- **In an extension module or a Node addon, a thread of the process that loads it enters the
  Jac through the module's C entries**: an export the process calls, and every Jac function C
  calls. Such a thread is made known to the Jac runtime the first time it enters, and holds the
  Jac lock while it runs Jac, giving it up when it leaves, so the Jac runs on one thread at a
  time: an addon called from Node's main thread and from a worker's, whose C++ calls a Jac
  function back on the thread that called it, runs on both. In a program, a thread nothing made
  known (one a C++ library starts) still ends it, as above.

<!-- example: not checked: needs the C++ header library whose Hooks keeps a function pointer -->
```jac
def bump_by(c: Counter, step: i32) -> i32 {
    return c.bump(step * i32(2));
}

def remade_by(c: Counter, step: i32) -> Counter {
    c.bump(step);
    return Counter.make(c.value() * i32(10));
}

def bump_refused(c: Counter, step: i32) -> i32 {
    raise ValueError(f"no bump by {step}");
}

with entry {
    h = Hooks.make(i32(1));
    before = h.bumped(i32(3));
    h.on_bump(bump_by);
    h.on_made(remade_by);
    print(before, h.bumped(i32(3)), h.value(), h.remade(i32(2), i32(5)));
    h.on_bump(bump_refused);
    try {
        h.bumped(i32(4));
    } except ValueError as e {
        print(e, h.value());
    }
}
```

```text
-1 7 7 70
no bump by 4 7
```

`Hooks` keeps the counter it was made with, calls the kept `bump` with it by reference and `made`
with a `Counter` by value, and gives `-1` while it keeps none.

A static method is given by its class, and a free function of the library takes a Jac function as
a member does:

<!-- example: not checked: needs the C++ header library whose Hooks keeps a function pointer -->
```jac
obj Bumper {
    static def by_ten(c: Counter, step: i32) -> i32 {
        return c.bump(step * i32(10));
    }
}

with entry {
    h = Hooks.make(i32(1));
    h.on_bump(Bumper.by_ten);
    print(h.bumped(i32(2)), with_counter(bump_by, i32(5)));
}
```

```text
21 9
```

`with_counter` makes a `Counter` of its second argument and calls the function with it and 2.

**A member template that takes a callable** (`template <typename Hook> int bump_with(Hook hook,
int by)`), whose template argument C++ deduces from the function given, as napi's `Function::New`
takes one, is called by the template's own name with a def or a static method, and no type
arguments: `h.bump_with(bump_by, i32(2))`, `Hooks.run(Bumper.by_ten, i32(5))` for a static
template. The program's build makes the instance for the C++ type of the function given, one for
each function. A function with a parameter or a result that is no C++ type, or one the
template's definition does not compile for, is
[E1641](../reference/diagnostics/e16.md#e1641).

<!-- example: not checked: needs the C++ header library whose Hooks has the member templates run and bump_with -->
```jac
with entry {
    h = Hooks.make(i32(1));
    print(Hooks.run(bump_by, i32(5)), h.bump_with(bump_by, i32(2)));
}
```

```text
1111 5
```

`Hooks::run(cb, start)` makes a `Counter` of `start` and gives `cb(c, 3) * 100 + c.value()`, and
`bump_with` calls the hook with the counter the `Hooks` keeps.
A library's registration has that shape: node-addon-api's `NODE_API_MODULE(name, InitAll)` is a
call of its `RegisterModule(env, exports, InitAll)`, given the module's own function, and
[`neojac port`](../toolchain/port.md) writes the addon's Node-API entry points over that call, with
the ported `InitAll` given by its name.

- **Where C++ calls the function with an rvalue of a copyable class** (`fin(Counter(start), 4)`,
  as napi's `Buffer<T>::NewOrCopy` calls its finalizer with `Env(env)`), the instance takes the
  class by value, and the def's `c: Counter` is the callback's own copy for the length of the
  call. Where the instance by reference compiles too, it is the one taken.
- **Two patterns of one name that differ only in parameters a template argument makes**
  (`template <typename Hook> int on_done(Hook)` and `template <typename Hook, typename Arg> int
  on_done(Hook, Arg *)`, as napi's `AddCleanupHook(hook)` and `AddCleanupHook(hook, arg)`) are
  named apart by those parameters' pieces: the first keeps `on_done`, the second is
  `on_done_T0_ptr_T1`. Only names that would collide change.
- **A `T *` the function given does not deduce is `void` where the argument is a Jac `ptr`**:
  `h.on_done_T0_ptr_T1(noted, p)` with `p = hold(note)` makes `on_done` over `void *`, and the def
  takes a `ptr` (`def noted(p: ptr)`), which `held[Note](p)` reads back
  ([Pointers](pointers-and-native-memory.md)).
- **The file's own object crosses such a `T *` as itself**: given `held_at(note)`, the address C
  holds a `Note` at while `hold(note)` is in force, `h.on_done_T0_ptr_T1(note_kept, held_at(note))`
  takes a hook that takes the `Note` (`def note_kept(note: Note)`), and C++ gives it the object.
  The instance is still the one over `void *`: a template that needs the class complete (one
  that copies `*arg`) has no instance for a Jac class, and giving it one is
  [E1641](../reference/diagnostics/e16.md#e1641).

<!-- example: not checked: needs the C++ header library whose Hooks has the member templates on_done and finish -->
```jac
obj Note {
    has n: int = 0;
}

def noted(p: ptr) {
    held[Note](p).n += 5;
}

def note_kept(note: Note) {
    note.n += 7;
}

def nothing_noted {
    print("hook of no arguments");
}

def fin(c: Counter, k: i32) -> i32 {
    return c.value() + k;
}

with entry {
    h = Hooks.make(i32(1));
    note = Note();
    p = hold(note);
    print(h.on_done(nothing_noted), h.on_done_T0_ptr_T1(noted, p), note.n);
    h.on_done_T0_ptr_T1(note_kept, held_at(note));
    print(note.n);
    release(p);
    print(Hooks.finish(fin, i32(3)));
}
```

```text
hook of no arguments
1 2 5
12
700
```

`on_done` calls the hook with no argument or with the one it is given, and gives `1` or `2`;
`Hooks::finish(fin, start)` gives `fin(Counter(start), 4) * 100`.

### A Jac method C++ calls through a pointer to a member function

A class template the Jac class derives may take a pointer to a member function of its argument,
`int (T::*m)(int)`, as a library's table of an object's methods takes them. A method of the Jac
class is given there by its class, `Drop.plus_size`, and C++ calls it on the object it has, the
Jac object, through a function the interface writes for that method. A list of entries C++ takes
in braces may hold them too.

- **The method's parameters and result are the pointer's**, with the object first: for
  `int (T::*m)(int)`, a method `def plus_size(x: i32) -> i32`, whose type by its class is
  `Callable[[Drop, i32], i32]`.
- **Only a method of the class, given by its class**: a lambda, a bound method (`Drop().plus_size`,
  one object's) or a method of another signature is
  [E1623](../reference/diagnostics/e16.md#e1623).

<!-- example: not checked: needs the C++ header library whose Pool takes pointers to T's member functions -->
```jac
obj Drop(Pool[Drop]) {
    override def size -> i32 {
        return i32(6);
    }

    def twice(x: i32) -> i32 {
        return x * i32(2);
    }

    def plus_size(x: i32) -> i32 {
        return x + self.size();
    }
}

with entry {
    print(
        Drop.call(Drop.plus_size, i32(5)),
        Drop.table([Drop.slot("twice", Drop.twice), Drop.slot("plus", Drop.plus_size)], i32(5)),
    );
}
```

```text
11 219
```

`Pool<T>::call(m, x)` makes a `T` and gives `(t->*m)(x)`; `slot` keeps a name and a method, and
`table` runs each on one `T`, adding ten times its result and its name's length.

### C++ values whose destructor runs code

A C++ class whose destructor is not trivial (`std::string`, `std::vector`, a class of the module
that frees what it holds) is a scoped [owned value](../language/ownership.md): a local declared
`own` holds it as its one owner, and the C++ object is destroyed where that owner's scope ends, as
C++ destroys it. A local or a field with no ownership annotation is a managed place: it holds one
counted, and destroys it when its last reference goes, or at `del o.f`. An `own` binding takes
one only from where it is made, not from a managed place (E1637). A Jac class deriving such a
class is one too.

- **A C++ function's class parameters are borrows** (`def described(f: &Figure)` in the
  interface): an owner is lent for the call, and C++ copies a by-value parameter itself.
- **A pointer a member gives is a loan of its receiver where C++ declares it so**
  ([below](#a-pointer-into-an-object)).
- **The C++ standard library's classes are `libcxx`'s** (below): a local holding the string
  `text` returns is declared `sep: own std_string = text(" ");`, with `std_string` imported from
  `libcxx`.

### A pointer into an object

A pointer a C++ class's non-static member gives may point into the object it was called on. Where
C++ declares that it does, the result is a shared loan of the object, as `&s` is
([Borrows](../language/ownership-borrows.md)): a member marked `[[clang::lifetimebound]]`, and the
accessors of `std`'s strings and containers that Clang's own lifetime analysis follows (`c_str`,
`data`, `begin`, `operator[]`, `front` and the rest). That holds for a `ptr[T]` result, a
reference result and a pointer to a class alike. The object is kept while the pointer is used,
and while a copy of it (`q = p`) or a pointer computed from it (`p + 8`) is: as C++ keeps a local
to the end of its scope, where a managed local would otherwise go at its last use.

```jac
import from libcxx { std_string }

def tail -> str {
    s = std_string.make_ptr_i8("a string longer than the small buffer holds");
    rest = s.c_str() + 2;
    return str(rest);
}

with entry {
    print(tail());
}
```

```output
string longer than the small buffer holds
```

An `own` owner given away while such a pointer is used is E1304, as with any borrow: with
`p = l.text()` of a member marked `[[clang::lifetimebound]]`, `m: own Label = l` before `p`'s last
use is `'l' is destroyed while still borrowed`. A public field of class type read through such a
loan carries it on, since the field is a place inside the object: with
`e = v.op_index(u64(0))` of a `std_vector[std_pair[std_string, i32]]` and `f = e.first`, giving
`v` away (`give(v)`, to a parameter `own`) before `f`'s last use is E1304 too. A member C++
declares no such thing of gives its pointer under C++'s own contract, with no loan: a managed
local's object goes at its last use, an `own` one's where its scope ends, and the pointer then
dangles; keep the object in a local read after the pointer, or in an `own` local, as long as it
is used. What a loan does not cover is C++'s own contract too, as it is in C++, and nothing checks
it:

- **a member that changes the object** (`s.append_ptr_i8(...)`, a vector's `push_back` past its
  capacity) called while the pointer is used may leave it dangling;
- **a pointer stored in a field or a global, returned, or given to C to keep** outlives the
  function's loan: the object goes when its owner's scope ends, or with its last reference, and
  the pointer then dangles.

Keep the object where the pointer goes (a field beside it), or copy what it points to
(`str(p)`), as C++ asks.

### The C++ standard library's classes

The classes of the C++ standard library a program uses have one home, the module `libcxx`, which
neojac makes for each program from the libc++ it ships: `import from libcxx { std_string,
std_vector }`. A C module's interface names them rather than declaring its own, so the string one
module's function gives is the string another's takes.

- **A class is named `std_` and its C++ name**: `std::string` is `std_string`, `std::mutex`
  `std_mutex`, and one of a namespace inside `std` with each `::` as `_`:
  `std::chrono::system_clock` is `std_chrono_system_clock`. A header library's function that takes
  a `std::chrono::system_clock::time_point` binds, and is given what the clock's members make:
  `since_ms(std_chrono_system_clock.from_time_t(1000))`, `since_ms(std_chrono_system_clock.now())`.
- **A class has its `std` name however a header spells it**: where a header writes
  `std::basic_string<char>` before any `std::string`, a function of it taking one still takes a
  `std_string`, and `import from libcxx { std_string }` binds.
- **A class template is named by its template form**, as a program's own C++ template is:
  `std::vector<int>` is `std_vector[i32]`, `std::lock_guard<std::mutex>` is
  `std_lock_guard[std_mutex]`. libcxx makes each instance the program names, whether or not any
  C++ of the program reaches it. A class a program imports and never names makes nothing:
  `import from libcxx { std_unique_lock }` with no use is no error. A template argument may be a
  pointer, `ptr[T]`, a pointer to a C record among them: `std::vector<Vt *>` is
  `std_vector[ptr[Vt]]`, the record the same type as C's.
- **A `std` class over a class of a C++ module is that module's** ([below](#a-std-class-over-a-modules-class)).
- **Its members are bound as a C++ class's are**: overloads by their parameters' types, so a
  `std::vector`'s default constructor is `make_()`, which `std_vector[i32]()` calls; `at` past the
  end raises `IndexError`, and `v.at_set(i, x)` and `v.op_index_set(i, x)` store as `v.at(i) = x`
  and `v[i] = x` do.
- **A class whose destructor runs code is bound `own`** (below).
- **A move assignment is `op_assign_move`**, beside the copy: `a = b` is `a.op_assign(b)`, or, where
  `operator=` has more overloads, the copy's name among them (`op_assign_std_string`), and
  `a = std::move(b)` is `a.op_assign_move(b)`, which leaves `b` as C++ leaves a moved-from value
  (a string empty).
- **A free function, a constant or an enumerator of `std` is named `std_` and its C++ name too**,
  looked up in `std` as C++ looks it up, a function libc++ gives through a `using` of a namespace
  of its own (`std::signbit`) among them: `std_to_string` is `std::to_string`, an overload set a
  program imports by that name and calls by its member's, named by its parameters as every C++
  overload set is (`std_to_string_i32(i32(420))`). A C function `std` gives again
  (`std::printf`) is C's, imported from `c`, and so is one libc++ gives as `const` overloads that
  differ from it only in a pointee's constness (`std::strrchr`, `strchr`, `strstr`, `strpbrk`,
  `memchr` and their wide forms): a call C++ resolves to one of them is a call of the C function,
  as [`neojac port`](port-cxx.md) writes it.
- **A function template of `std` is called by its instance**, as a header library's is
  ([Function templates](#function-templates)). Where the set has more than one template, each is
  named by all its parameters, one whose type is a type parameter of the template by its place,
  `T0`, `T1`: `std::min(a, b)` is `std_min_T0_T0[i32](a, b)`, beside `std_min_T0_T0_T1` (with a
  comparator) and `std_min_std_initializer_list`, and `std::max` likewise. The name the set
  shares names none of them: `std_min[i32](3, 7)`, or `std_min(3, 7)`, is
  [E1642](../reference/diagnostics/e16.md#e1642), which lists the members to write. The import is
  the set's name, `std_min`. Two templates libc++ declares alike but for their constraints
  (`std::copy_n`'s) are one Jac template, `std_copy_n_T0_T1_T2`. A template over a container's
  iterators is called with the iterator's class: `std::sort(v.begin(), v.end())` is
  `std_sort_T0_T0[std_vector_iterator[i32]](v.begin(), v.end())`.
- **A `std` template that takes a callable deduces it from a def**, as a header library's member
  template does ([A Jac function C++ calls back](#a-jac-function-c-calls-back)):
  `std_call_once(flag, started_once)` runs `started_once` once for the `std_once_flag`. A def
  taking a class of a C module is E1641: `libcxx`'s instances are made over its own classes and
  numbers alone.

```jac
import from libcxx { std_call_once, std_once_flag, std_sort, std_vector, std_vector_iterator }

glob started: list[int] = [0];

def started_once {
    started[0] += 1;
}

with entry {
    flag: own std_once_flag = std_once_flag();
    std_call_once(flag, started_once);
    std_call_once(flag, started_once);
    v: own std_vector[i32] = std_vector[i32]();
    for n in [5, 1, 4, 2] {
        v.push_back(i32(n));
    }
    std_sort_T0_T0[std_vector_iterator[i32]](v.begin(), v.end());
    print(started[0], [v.at(u64(k)) for k in range(4)]);
}
```

```output
1 [1, 2, 4, 5]
```

- **A `std` enumerator, and a `std` constant of an enum's type, have the enum's integer type**:
  `std_memory_order_relaxed` is `std::memory_order_relaxed`, a `u32` (the type
  `std::memory_order` is made of), which a member that takes the enum takes as it is
  (`n.fetch_add(i64(3), std_memory_order_relaxed)`).
- **A parameter whose C++ default is a constant may be left out**, as in C++: `s.find_i8_uword(c)`
  is `s.find(c)`, from position 0, and `s.substr(u64(1))` is the rest of the string from 1, its
  `n = npos` C++'s.
- **A class's public number and `bool` fields are properties**, read and, unless `const`, written
  as Jac's: a `std_pair[i32, i32]`'s `p.first` and `p.second`. **A public field of a class type**
  is read as a getter that gives the field itself, not a copy, so what a program does to it the
  object keeps: `pr.second.op_assign_ptr_i8("three")` of a `std_pair[i32, std_string]` writes the
  pair's string, and `hd.c.bump(i32(2))` the `Counter` a header library's `struct Holder { Counter
  c; }` holds. It has no setter: assign through the field's own `op_assign`. A field of any other
  type is not bound, and the interface says why.
- A name `std` does not have, or a member of an overload set imported by its own name
  (`std_to_string_i32`), is E1145 of the import. A type argument a template does not take does not
  compile in libcxx: E5200.

```jac
import from libcxx { std_lock_guard, std_mutex, std_string, std_vector }

def guarded(mu: &std_mutex) -> int {
    lk: own std_lock_guard[std_mutex] = std_lock_guard[std_mutex].make(mu);
    return 1;
}

def main {
    v: own std_vector[i32] = std_vector[i32].make_();
    v.push_back(i32(42));
    v.push_back(i32(7));
    v.at_set(u64(1), i32(8));
    names: own std_vector[std_string] = std_vector[std_string]();
    mu: own std_mutex = std_mutex();
    print(v.size(), v.at(u64(1)), names.size(), guarded(&mu), mu.try_lock());
    mu.unlock();
    try {
        v.at(u64(5));
    } except IndexError {
        print("IndexError");
    }
}

with entry {
    main();
}
```

```output
2 8 0 1 True
IndexError
```

```jac
import from libcxx { std_string }

with entry {
    named: own std_string = std_string.make_ptr_i8(ptr[i8]("named"));
    other: own std_string = std_string.make_ptr_i8(ptr[i8]("other"));
    gone: own std_string = std_string.make_ptr_i8(ptr[i8]("gone"));
    named.op_assign_std_string(other);
    print(named.size(), other.size());
    named.op_assign_move(gone);
    print(named.size(), gone.size());
}
```

```output
5 5
4 0
```

```jac
import from libcxx {
    op_eq,
    std_allocator,
    std_char_traits,
    std_max,
    std_memory_order_relaxed,
    std_min,
    std_pair,
    std_string,
    std_to_string,
    std_vector,
    std_vector_reverse_iterator,
}

with entry {
    duos: own std_vector[std_pair[i32, i32]] = std_vector[std_pair[i32, i32]]();
    duos.emplace_back[i32, i32](i32(1), i32(2));
    duos.resize_uword(u64(2));
    duo = duos.op_index(u64(1));
    duo.first = i32(4);
    duo.second = i32(5);
    ups: own std_vector[u32] = std_vector[u32]();
    ups.push_back(u32(7));
    ups.emplace_back[u32](u32(8));
    back: std_vector_reverse_iterator[u32] = ups.rbegin();
    told: own std_string = std_to_string_i32(i32(420));
    other: own std_string = std_string.make_ptr_i8("421");
    print(duo.first + duo.second, duos.op_index(u64(0)).second, back.op_deref(), told.size());
    print(told.find_i8_uword(i8(50)), told.compare_std_string(other) < 0, std_memory_order_relaxed);
    tail: own std_string = other.substr(u64(1));
    print(told.c_str(), str(tail.c_str()), tail.data() == tail.c_str());
    print(
        op_eq_std_basic_string_std_basic_string[i8, std_char_traits[i8], std_allocator[i8]](
            told, other
        ),
        op_eq_std_basic_string_ptr_T0[i8, std_char_traits[i8], std_allocator[i8]](other, "421"),
    );
    print(std_min_T0_T0[i32](i32(3), i32(7)), std_max_T0_T0[f64](2.5, 0.5));
}
```

```output
9 2 8 3
1 True 0
420 21 True
False True
3 2.5
```

`duo` is the pair the vector holds, so what the program writes to its fields the vector keeps. It
is a reference into the vector, as C++'s `auto &duo = duos[1]` is: a call that makes the vector
reallocate (a `push_back` or `emplace_back` past its capacity) leaves it dangling, as in C++, so
the example takes it after the vector has its size.

- **`emplace_back` and `emplace` are member templates** ([above](#member-function-templates)),
  named with the types of the arguments they forward to the item's constructor:
  `duos.emplace_back[i32, i32](i32(1), i32(2))` makes a `std_pair[i32, i32]` in place, and
  `ups.emplace_back[u32](u32(8))` a number. A string is made in place from a temporary,
  `said.emplace_back[std_string](std_to_string_i32(i32(42)))`, and a pointer from a pointer,
  `words.emplace_back[ptr[i8]](p)`. The instance `emplace_back[std_string]` takes its argument
  as C++'s `std::string &&`, so given a local string it moves the local's value out, as
  `std::move(s)` would, and the local is left empty; `emplace_back[&mut std_string](s)`, the
  instance C++ makes for `v.emplace_back(s)`, copies it, and so does `push_back(s)`. `emplace` of
  a map whose items are `libcxx`'s own (`std_unordered_map[i32, i32]`) is not bound yet: E1030,
  `std_unordered_map[i32, i32] has no field 'emplace'`; over a module's class it is
  ([below](#a-std-class-over-a-modules-class)).
- **`push_back` of a temporary is `push_back_move`**, the overload taking `T&&`, beside
  `push_back`, the one taking `const T&`, which copies.
- **A member's `const char *` result is a `ptr[i8]`**, the pointer into the string: `told.c_str()`
  and `tail.data()` are the same address. `str(p)` copies its text and `print(p)` prints it; the
  string is kept while the pointer is used ([A pointer into an object](#a-pointer-into-an-object)),
  and a member that changes the string may leave the pointer dangling, as in C++.
- **`compare` is an overload set**, so a string is compared with another by the member that takes
  one, `compare_std_string`. The bare `told.compare(other)` is E5133, whose reason lists the
  overloads by their names.
- **C++'s `==` of two strings is a free function template of `std`**, as is its `+` (`op_add`):
  `import from libcxx { op_eq }` gives each of the set's templates, named by their
  parameters, the string as `std_basic_string` and the character pointer as `ptr_T0`, and called
  with `std::basic_string`'s type arguments. Jac's own `told == other` is E1624, whose fix names
  them.

```jac
import from libcxx { std_random_device, std_string, std_to_string, std_vector }

with entry {
    said: own std_vector[std_string] = std_vector[std_string].make_();
    said.emplace_back[std_string](std_to_string_i32(i32(42)));
    said.push_back_move(std_to_string_i32(i32(7)));
    kept: own std_string = std_to_string_i32(i32(9));
    said.emplace_back[&mut std_string](kept);
    words: own std_vector[ptr[i8]] = std_vector[ptr[i8]]();
    words.emplace_back[ptr[i8]](ptr[i8]("first"));
    words.push_back(ptr[i8]("second"));
    print(str(said.at(u64(0)).c_str()), str(said.at(u64(1)).c_str()), said.size(), kept.size());
    print(str(words.at(u64(1))), words.size());
    rd: own std_random_device = std_random_device.make_();
    drawn = [rd.op_call() for _ in range(4)];
    print(len(set(drawn)) > 1, rd.entropy() >= 0.0);
}
```

```output
42 7 3 1
second 2
True True
```

`std::random_device` is made by its constructor of no arguments, `make_()`, and drawn from by
its `operator()`, `op_call()`.

**A container's iterator is a class the library keeps to itself** (`std::__wrap_iter`,
`std::__hash_map_iterator`), and a program has it under the public name its container gives it:
the container's name, `_`, and the member type, with the container's arguments.
`std::vector<int>::iterator` is `std_vector_iterator[i32]`, `std::vector<int>::const_iterator`
`std_vector_const_iterator[i32]`, `std::vector<int>::reverse_iterator`
`std_vector_reverse_iterator[i32]`, `std::unordered_map<int, int>::iterator`
`std_unordered_map_iterator[i32, i32]`, each imported from `libcxx`.

- **A member that gives an iterator is bound where the program names its type**: `begin()`,
  `end()`, `find(k)`. Where the program names it nowhere, a call of the member is refused when the
  program compiles (E5133), and the reason says the type to write.
- **An iterator is walked with its own members**, as C++ finds them: `op_ne` and `op_eq` compare
  two (C++'s `!=` and `==`), `op_deref()` reads the item and `op_deref_set(x)` stores through it,
  `op_inc()` steps. Jac's own `==` and `!=` of two values of C++ classes, iterators among them,
  are refused when the program compiles (E1624): they would compare the Jac objects, not the
  positions. Write `pos.op_ne(stop)`, or `a is b` to ask whether two are the same object.
- **An overload set is named as any member's**: `std::unordered_map`'s `begin()` and `end()` have
  a bucket's overload beside them, so the container's are `begin_()` and `end_()`.
- **`std::atomic<T>` is `std_atomic[T]`**, its members C++'s: `store`, `load`, `fetch_add` and the
  rest. The memory order may be left out, as in C++ (`memory_order_seq_cst`), or given as its
  enumerator, `std_memory_order_relaxed`, a `u32`, or as the number `std::memory_order` gives it
  (`u32(5)` is `memory_order_seq_cst`).

```jac
import from libcxx {
    std_atomic,
    std_memory_order_relaxed,
    std_unordered_map,
    std_unordered_map_iterator,
    std_vector,
    std_vector_const_iterator,
    std_vector_iterator,
}

def summed(v: &std_vector[i32]) -> int {
    total = 0;
    pos: std_vector_const_iterator[i32] = v.cbegin();
    while pos.op_ne(v.cend()) {
        total += int(pos.op_deref());
        pos.op_inc();
    }
    return total;
}

def main {
    v: own std_vector[i32] = std_vector[i32]();
    for n in [3, 4, 5] {
        v.push_back(i32(n));
    }
    pos: std_vector_iterator[i32] = v.begin();
    stop: std_vector_iterator[i32] = v.end();
    while pos.op_ne(stop) {
        pos.op_deref_set(pos.op_deref() * i32(10));
        pos.op_inc();
    }
    print(summed(v), pos.op_eq(stop));
    ages: own std_unordered_map[i32, i32] = std_unordered_map[i32, i32]();
    ages.op_index_set(i32(7), i32(70));
    found: std_unordered_map_iterator[i32, i32] = ages.find(i32(7));
    print(found.op_ne(ages.end_()), ages.find(i32(8)).op_eq(ages.end_()));
    hits: own std_atomic[i64] = std_atomic[i64]();
    seq_cst = u32(5);
    hits.store(i64(1), seq_cst);
    print(hits.fetch_add(i64(2), std_memory_order_relaxed), hits.load(seq_cst));
}

with entry {
    main();
}
```

```output
120 True
True True
1 3
```

`libcxx` also gives C++'s replaceable allocation functions, so that memory C++ allocates is freed
as C++ frees it, and the reverse: `op_new(n)` and `op_delete(p)` are `::operator new` and
`::operator delete`, `op_new_array(n)` and `op_delete_array(p)` `::operator new[]` and
`::operator delete[]`. `n` is a `u64` count of bytes and the result a `ptr`; where C++ would throw
`std::bad_alloc`, they raise `MemoryError`. This is what `neojac port` writes for C++'s `new[]`
and `delete[]` of numbers and pointers ([Porting C++](port-cxx.md)).

```jac
import from jaclang.comptime { sizeof }
import from libcxx { op_new, op_delete, op_new_array, op_delete_array }

with entry {
    xs = ptr[i32](op_new_array(u64(4) * u64(sizeof(i32))));
    for i in range(4) {
        xs[i] = i32(i * 10);
    }
    print(xs[3]);
    op_delete_array(ptr(xs));
    try {
        op_new(u64(1) << u64(62));
    } except MemoryError {
        print("MemoryError");
    }
}
```

```output
30
MemoryError
```

#### A `std` class over a module's class

An instance of a `std` class template whose template arguments name, at any depth, a class of a
C++ module of the program is that module's: `std::unordered_map<int, tally::Box<int>>` is
tally's. The module's reading reaches it, its interface declares it, and its C++ unit compiles
what binds it, under the module's own flags, so the instance has one home as every `std` class
has. A program still writes it with `libcxx`'s name, imported from `libcxx`:
`std_unordered_map[i32, Box[i32]]`, its members those the module's reading gives.

An instance binds whether the module's own C++ reaches it (one a function of its headers gives
or takes) or only the program names it (`std_unordered_map[i32, Box[i16]]`), which the module's
reading then makes. The program makes it, copies it and calls its members, its member templates
and its iterators among them. With the header library `kit/kit.h` holding `Box<T>` and
`std::unordered_map<int, Box<int>> boxes()`, which gives a map of one item, `{1: Box(10)}`:

<!-- example: not checked: needs the C++ header library kit whose boxes() gives an unordered_map of Box<int> -->
```jac
import from libcxx { std_unordered_map, std_unordered_map_iterator }

with entry {
    m: own std_unordered_map[i32, Box[i32]] = boxes();
    fresh: own std_unordered_map[i32, Box[i32]] = std_unordered_map[i32, Box[i32]]();
    fresh.op_assign(m);
    key: i32 = i32(3);
    m.emplace[i32, Box[i32]](i32(2), Box[i32].make(i32(20)));
    m.emplace[&mut i32, Box[i32]](addressof(key), Box[i32].make(i32(30)));
    found: std_unordered_map_iterator[i32, Box[i32]] = m.find(i32(3));
    print(m.size(), fresh.size(), found.op_ne(m.end_()), found.op_deref().second.get());
    small: own std_unordered_map[i32, Box[i16]] = std_unordered_map[i32, Box[i16]]();
    small.emplace[i32, Box[i16]](i32(1), Box[i16].make(i16(5)));
    print(small.size(), small.at(i32(1)).get());
}
```

```text
3 1 True 30
1 5
```

- **`emplace` and `emplace_back` over the module's class are member templates** of the instance,
  named by the types they forward ([Member function templates](#member-function-templates)):
  `m.emplace[i32, Box[i32]](...)` takes the key by value, and
  `m.emplace[&mut i32, Box[i32]](key, ...)` takes it as a place, the instance C++ makes for
  `m.emplace(key, ...)` of an `int` local.
- **A `std` member template's instance whose argument is a header library's class is that
  library's**, though the container is `libcxx`'s own: with `kit.h` giving
  `std::vector<kit_handle> handles()` and a class `Peg` that C++ converts to a `kit_handle`,
  `rows.emplace_back[Peg](Peg.make(i32(2)))` of a `std_vector[ptr[kit_slot]]` is made in kit's
  reading, which converts the `Peg` as C++ does.
- **A container over a class that cannot be copied has no copy.** Of a `std_vector[Lone]`,
  where `Lone`'s copy constructor and copy assignment are deleted, `ls.__copy__()` is E1030,
  `std_vector[Lone] has no method '__copy__'`. With no copy assignment, its move assignment is
  `op_assign`: `ls.op_assign(other)` moves, and leaves `other` empty.

## Wiring C modules

In a project with an `archwire.jac`, wires connect C modules as they connect Jac modules (see
[Import wiring](../language/modules-wiring.md), `neojac docs graph import`).

A C module of the project's own is wired by its files:

- **A C file to Jac** (`shapes.shapes ++> main { point, point_add }`): binds those names in the
  Jac module, as `import from` does. The provider is the file that gives the name: the source that
  defines a function or a variable, whichever header declares it, and the file that holds a type,
  an enumerator or a macro. A name another file gives is E1145.
- **A C file to a C file** (`shapes.shapes --> geom.geom { shape }`): declares what `geom.c` uses of
  `shapes.h`, which Clang holds to the sources ([A C module's files](#a-c-modules-files)). The
  other module is in every program the one that holds `geom.c` is in. No wire gives a module of
  the project an include path: its table's `include` names every directory its sources read
  headers from, outside its own directory too (`include = ["../Include"]`).
- A wire from the module itself (`shapes ++> main { point }`, `shapes ++> geom;`) is E1576, whose
  message gives the wires to write in its place.

A dependency is wired whole, and so is a crate:

- **C to Jac** (`zlib ++> main { crc32 }`): binds those names in the Jac module.
- **C to C** (`zlib ++> png;`): `png`'s sources may include `zlib`'s headers, `zlib` is built into
  every program `png` is in, and `png`'s interface uses `zlib`'s records rather than declaring its
  own.
- **Rust to C** (`tally ++> geom;`): links the crate into every program the C module is in, where
  the C module's code calls its `extern "C"` functions by name. See
  [Rust modules](rust-modules.md).

A C module takes another C module's interface and a Rust module whole, and a Jac module's
functions by name ([Calling Jac from C](#calling-jac-from-c)): a wire of a whole Jac module into
it, or one naming items of a Rust module, is E5136. A Jac module importing a C module of its
own top-level package must use a wire (E1144); across top-level packages, an import is governed by
the edge rules as any other.

## Calling Jac from C

A C module calls a Jac function as it calls any C function, once a wire gives it the function:

- **into a C module of the project's own**, by its file, declared as the C file's own use
  (`jhelp --> shapes.shapes { jhelp_calls, jhelp_scale }`), since the C source writes the calls;
- **into a dependency C module**, whole (`helper ++> c { helper_value }`).

<!-- example: not checked: needs the C module shapes and the archwire.jac that wires jhelp into it -->
```jac
glob calls: list[int] = [0];

def:pub jhelp_scale(x: float, times: i32, seen: ptr[int]) -> float {
    calls[0] += 1;
    seen[0] = 10;
    return x * float(times);
}

def:pub jhelp_calls -> int {
    return calls[0];
}
```

neojac writes the header `jac/jhelp.h`, which declares exactly the functions the wires give that
C module, before Clang reads any of its files (for a Jac module a C module's table lists, those
no header of its C module declares, below):

```c
int64_t jhelp_calls(void);
double jhelp_scale(double, int32_t, int64_t *);
```

and `shapes.c` includes it:

```c
#include "jac/jhelp.h"

double shapes_jac_scaled(double x, int32_t *calls) {
    int64_t seen = 0;
    double out = jhelp_scale(x, 3, &seen);
    *calls = (int32_t)(seen + jhelp_calls());
    return out;
}
```

- **The named functions are C functions of the program** of those names, as a wire into a crate
  makes them. A C file's use of one is held to its wires as any import of C is (E1575, E1147).
- **A function C calls takes and gives** `int`, `i8` to `u64`, `float`, `f32` and `ptr[...]` (a
  pointer to anything but a number is `void *` in the header), and a C record or union of a
  tag by value, `struct <tag>` in the header, passed as the target's C calling convention
  passes it (`def:pub moved(p: point, step: float) -> point` is
  `struct point moved(struct point, double);`), and is neither generic nor
  `async` (E1249). It also takes a `Callable[[P, ...], R]` of those types, a function pointer:
  `def:pub twice_with(f: Callable[[int], int], x: int) -> int` is
  `int64_t twice_with(int64_t (*)(int64_t), int64_t);` in the header, and calls what C passed
  as C's function, `f(f(x))`. `ptr(f)` is the address C passed (see
  [Callbacks](c-libraries.md#callbacks)).
- **The header of a Jac module that replaces a C source** (one a C module's table lists under
  `jac`) declares only what no header of its C module declares, whether or not the source
  included that header: those headers are what the module's C goes on including, and they
  already declare what the source defined, which the header repeating could only disagree with. A record what is left takes or gives is
  spelled as its header spells it, `struct <tag>`, or the typedef that alone names a record with
  no tag (`PyStatus`, `span`), and that header is included: `int32_t span_width(span);` after
  `#include "scale.h"`. A record no name of C spells is E1237 or E1249.
- **A header beside a Jac module of its stem** (`cpu.h` beside `cpu.jac`) is that module's face to
  C: a C use of a name it declares is a use of the Jac module. This is how a C file that
  [`neojac port`](../toolchain/port.md#in-a-project) made Jac is still called by the C of its
  module that stays; port moves the header to `replaced-by-neojac/` with its source once no C
  that stays reads it.
- **A C module built into a shared library** cannot call the program's Jac (E5183): a C module
  that calls Jac is linked into the program.
- **The face header may give C macros of its own**: a wire from the Jac module into a C file
  names them beside the module's functions (`native.count --> native.unity { TWICE_BY, twice }`
  where `count.h` beside `count.jac` defines `TWICE_BY`). A name neither the module nor its face
  gives is E1145.

### C data a Jac module gives C

A `glob` a Jac module declares in `import from c` is C data of the program, and a wire gives it to
C as it gives a function: `jac/<module>.h` declares it `extern`, and the C files read and assign
the one variable the Jac module does.

<!-- example: not checked: needs the C module calc and the archwire.jac that wires knobs into it -->
```jac
import from c {
    glob bias: float = 0.25;
}

def:pub scale(x: float) -> float {
    return x * 2.0;
}
```

with `knobs --> calc.calc { bias, scale }` in `archwire.jac`, `jac/knobs.h` holds

```c
extern double bias;
double scale(double);
```

and `calc.c`'s `return scale(x) + bias;` gives `2.25` for `1.0`. C data a wire gives C is of
`int`, `i8` to `u64`, `float`, `f32`, `ptr[...]` or a C record or union with a tag, which the
header declares by its tag (E1237).

A `glob` of C plain data whose value is made of constants, of `addressof` of other globs and of
named functions given to a C record's function pointer fields is **static data**: it has its
value before any code runs, at the symbol C names, as a C static initializer has. So a ported
CPython type object, `glob PyBool_Type: _typeobject = _typeobject(...)`, is there for the C
that takes its address, whenever that C runs.

An extension module of Python whose C calls Jac is built the same way: with
`counted --> csrc.spam { counted_words }` in `archwire.jac`, `csrc/spam.c` keeps its
`PyInit__spam` and calls `counted_words`, and `neojac build pyproject.toml` builds the extension
with the Jac and the runtime linked in ([Python](python.md#a-python-project-of-the-repository)).

## A C module's files

A C module of the project's own is what its table builds, and its files are modules of the project
besides: `geom/geom.c` with `geom/geom.h`, the header of its name, is `geom.geom`, and
`shapes/private/circle.h`, a header no source has the name of, is `shapes.private.circle`. Where
one file uses what another declares, a `-->` wire says so, as for a file in any other language
([Declared wires](../language/modules-wiring.md#declared-wires---)):

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    shapes.shapes --> geom.geom { SHAPE_SQUARE, shape }
    shapes.private.circle --> shapes.shapes { SHAPES_CIRCLE_FACTOR }
}
```

`geom.c` uses the type `shape` and the enumerator `SHAPE_SQUARE` that `shapes.h` declares, and
`shapes.c` the macro `SHAPES_CIRCLE_FACTOR` of `private/circle.h`.

- Clang reads each of the module's sources as it compiles it, for every platform neojac builds C
  for, since each compiles code the others do not. An import is a use Clang resolved: of a
  function, a variable, a type (a `struct`, a `union`, an `enum`, a `typedef`), an enumerator or
  a macro. An `#include` is not one: it names a header, and says nothing of which file the code
  comes from.
- A function or a variable belongs to the file that defines it, whichever header declares it. A
  type, an enumerator and a macro belong to the file that holds them.
- A name each platform defines in a file of its own, `heap_info` in `arch/linux/heap.c` and in
  `arch/osx/heap.c`, is wired from each: a use belongs to the file that defines the name for
  the platform the use was read for. Where a platform has no file that defines it, the use is
  of the header that declares it.
- A platform's sources that this machine cannot read are not read: macOS's that use a framework
  the toolchain carries no headers of (IOKit), on a machine without the macOS SDK. What such a
  file gives is then not known there, so wires written on one system may not hold on another
  for those files.
- A C module is the project's own where `jac.toml` holds its table (`[c."geom"]`). One with a
  `cmodule.toml` that `jac.toml` does not hold is a dependency, one module whole, and so are a
  system's and a library's headers.
- These wires are checked by every command ([What a command judges](../language/modules-wiring.md#what-a-command-judges)), whether the program at hand uses the module or not, and mended by `neojac fmt --fix`.

## Declaring a C module's functions yourself

A module of another top-level package, or one that no `archwire.jac` governs (of no project, or of a project of fixtures), may also bind a C
module's functions by declaring them, in the form that binds a [C library](c-libraries.md). The
dotted name names the C module, which the program then builds. Under an `archwire.jac` this is a
dependency's form alone: for a C module of the project's own it is E1144, since a wire from the
file that defines a function brings it, declared in a header or not.

<!-- example: not checked: needs the C module ext/plain beside the program -->
```jac
import from ext.plain {
    def plain_twice(x: i32) -> i32;
    def plain_offset(x: int) -> int;
}

with entry {
    print(plain_twice(i32(21)), plain_offset(24));
}
```

- Where the headers declare the function, the declaration must agree with theirs: the same
  parameters, each of the same type and passed the same way, the same result, and variadic only
  if theirs is (E5145, whose message gives the headers' signature). A `const char *` parameter
  may be declared as any one of `str`, `bytes` and `bytearray`.
- A function no header declares, such as one only a source defines, is the declaration's alone
  to describe.
- A record the declarations name is their own, never the headers' record of that name; bind a
  function that takes or returns a record through a wire or an import of the module instead.
- A dotted name that names a C module binds it even where a [project library](c-libraries-linking.md#a-library-the-project-provides)
  of that name exists too.

## Building

- Each source compiles with the Clang in neojac to an object the link takes, as a C build compiles
  it, for the program's target.
- Clang's output is cached under a key of what alone decides it: the Clang version, the command
  line and the content of every file the compilation read. The toolchain's and the project's
  directories enter the key as what they are, not where they are. So an unchanged file compiles
  once, for every neojac with the same Clang, every install of the toolchain and every copy of the
  project; a new neojac with the same Clang compiles no C again.
- C modules build for every target [`neojac cc`](c-and-cpp.md) builds for. `wasm32-wasi` takes none
  yet (E5090).
- `neojac build --c-archive` writes a program's C modules as one static library for another build
  system to link; see [Building programs](../toolchain/build.md) (`neojac docs build`).

## What goes wrong

| Code | Cause |
|---|---|
| E5132 | The manifest has a key neojac does not know, a value of the wrong kind, a place other than `{lib}` and `{platform}` in a path, a files table's `include` that is no directory, or `frameworks` outside `[target.darwin]` in a build for another operating system |
| E5134 | The interface headers do not compile; Clang's errors are printed first |
| E5135 | A source does not compile; Clang's errors are printed first |
| E5133 | The name is something the interface cannot express, and the message says what |
| E1145 | The headers declare no such name |
| E5145 | A declaration that disagrees with the headers |
| E5136 | A wire of a whole Jac module into a C module, or one naming items of a Rust module |
| E1249 | A Jac function a wire gives C takes or gives a type C cannot pass, or is generic or `async` |
| E5183 | A C module built into a shared library is given a Jac function by a wire |
| E5200 | The C++ instances of class templates Jac classes derive do not compile |
| E1144 | A Jac module imports its own package's C module instead of taking a wire, or declares the functions of a C module of the project's own |
| E1576 | A wire from a C module of the project's own, where its files are its modules |
| E5158 | A key of a C module's table in `jac.toml` of the wrong kind |
| E1001 | A C record given where another module's record of its tag, with other fields, is expected |
| E1237 | C data a Jac module gives C of a type C cannot read |
| E1637 | A C++ value whose destructor runs code, taken from a managed place into an `own` binding |
| E1639 | What is given for a C++ pointer to a function is no def of exactly its signature, given by its name: a lambda, a bound method, another signature |
| E5090 | A C module in a build for `wasm32-wasi` |

`neojac docs E5133` prints any of these with its message.

## Differences from Python and from the reference design

- In Python, C code reaches a program as an extension module written against CPython's C API, or
  through `ctypes` or `cffi`. Here plain C is compiled into the program and called directly, with
  its types read from its headers.
- The reference design has no C modules.
