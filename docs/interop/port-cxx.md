---
description: What neojac port makes of each C++ construct - the Jac it becomes, and what it refuses.
keywords: port c++, porting C++, C++ to Jac
---
# Porting C++

`neojac port` translates a C++ source file into a Jac module that behaves as the file does, or
refuses it ([port](../toolchain/port.md)). This page is what port translates of C++ beyond
[C](port-c.md), whose mapping a C++ file's functions, statements and expressions follow. It is
printed from the table the translation itself reads (`neojac port --mapping c++`).

| C++ | Jac |
|---|---|
| `std::set<Peg *, ByRank> pegs;` and `std::vector<Peg *> loose;` of the file's own classes, `ByRank` a comparator class: `pegs.insert(p)`, `pegs.insert(pegs.end(), p)`, `pegs.erase(p)`, `pegs.find(p) != pegs.end()`, `pegs.count(p)`, `loose.push_back(p)`, `size()`, `empty()`, `clear()`, `new std::vector<Peg *>()` | A Jac list, `has pegs: list[Peg] = [];`; a set's list kept sorted by its comparator's function, its uses the module's own functions over it (`sorted_put(self.pegs, p, ByRank);`, `sorted_drop`, `sorted_has`), a vector's the list's own (`loose.append(p)`, `len(loose)`, `loose.clear()`); a pointer or a reference to one is the list. An iterator of a set used other than against `end()`, a copy, and every other member are refused |
| `std::vector<Entry> es;` of a class of the file held by value: `es.push_back(Entry(3))`, `es[0].key`, `for (Entry &e : es)`, `es.size()` | The class is an `obj` of the run and the vector a list of its objects, `es: list[Entry] = [];`; `es.append(Entry(3))` where the object is made as it is added, `es[0].key`, `for e in es`, `len(es)`. An item added other than as an object made there, a loop variable that copies the item, `std::find` over it and a copy of the vector are refused |
| `std::vector<Peg *>::iterator it = std::find(v.begin(), v.end(), p); if (it != v.end()) v.erase(it);` | The iterator is an index found by identity, `it: int = found_at(v, p); if it != len(v) { v.pop(it); }`: it names the element the iterator does wherever C++ keeps the iterator valid |
| `for (Peg *p : pegs) { }` over a set or a vector port writes as a list | `for p in sorted_walk(pegs, ByRank) { }`, each step the next after `p` in the order, as a set's iterator goes on past an element inserted or erased while it walks; `for p in loose { }` over a vector's |
| `class C { int n; public: C(int n) : n(n) { } int get() { return n; } };` | `struct C { has n: i32 = 0; static def make(n: i32) -> C { made: C = C(); made.n = n; return made; } def get -> i32 { return self.n; } }`: a C++ object is a value, as a Jac struct is, and a struct is made from its fields |
| `int C::get() { return n; }`, defined outside its class | `def get -> i32;` in the struct, and `impl C.get -> i32 { return self.n; }` |
| `Bin::Bin(int n) : room(n) { }`, a constructor defined outside its class | `static def make(n: i32) -> Bin;` in the struct and `impl Bin.make(n: i32) -> Bin { ... }`; of a class written as an `obj`, `def init(n: i32);` and `impl Bin.init(n: i32) { ... }` |
| `Money operator+(Money o) const`, `bool operator==(Money o) const`, `int operator[](int i) const`, `int operator()(int k) const`, `explicit operator bool() const`, of a class of the file; `a + b`, `-a`, `a == b`, `b < a`, `c[0]`, `a(3)`, `if (a)` | `def __add__(o: Money) -> Money`, `def __eq__(o: Money) -> bool`, `def __getitem__(i: i32) -> i32`, `def __call__(k: i32) -> i32`, `def __bool__ -> bool`; `a + b`, `-a`, `a == b`, `b < a`, `c[0]`, `a(3)`, `if bool(a)`: a member operator is the Jac operator method of its meaning (`+ - * / %`, `== != < <= > >=`, `& \| ^ << >>`, unary `- + ~`, `[]`, `()`, `bool`). One whose result is a reference a caller may write through, one the class overloads, and `->`, unary `*` and `&`, `=`, `++`, `--`, `!`, `+=` and the other compound assignments, a conversion to what is no `bool` and `new` are refused |
| `if (Item *it = find(k)) { ... }`, `if (int n = count(); n > 2) { ... }`, `switch (int s = next(); s) { ... }`, `while (int v = next()) { ... }` | `do { it: Item \| None = find(k); if it is not None { ... } }`, `do { n: i32 = count(); if n > 2 { ... } }`, `do { s: i32 = next(); switch s { ... } }`: what the statement declares, in a block of its own around it that ends where the statement ends, as C++ ends its scope; a `while`'s, in the loop's block, made again on each pass, `while True { v: i32 = next(); if not v != 0 { break; } ... }` |
| `static const int steps[] = {1, 2, 3}; for (int s : steps) { ... }`, a range `for` over an array | `for was_1 = 0 while was_1 < 3 with was_1 += 1 { s: i32 = steps[was_1]; ... }`: an index over the array, each pass's variable its item, as C++ steps a pointer from the first item to past the last; a variable that is a reference through which the body may write the item is refused |
| `namespace geo { int sides(); }`, a namespace with no name, `using namespace geo;` | `def sides -> i32`: a namespace's declarations are the module's own names, as Clang resolved each use; `using` writes nothing, and two declarations of one name in different namespaces are refused |
| `struct Totals { struct Line { int count; }; };`, a nested class | `struct Line { ... }` before `struct Totals { ... }`: a record of the module by its own name |
| `friend class Statement;` | Nothing: a Jac module's classes reach each other's members |
| `virtual ~Shape() { ... }` of a class with virtual functions | `def destroy { ... }`, which ends with `super.destroy();` where the base declares a destructor: C++'s destructor, run where `delete` runs it |
| `Shape *s = new Square(2.0);` of a class with virtual functions, or of one the run makes with `new` anywhere; `int *xs = new int[n];` | `s: Shape = Square(2.0);` (`s: dyn Shape = Square(2.0);` where `Shape` is an interface): the object, which Jac counts and frees when nothing holds it; `xs: ptr[i32] = ptr[i32](op_new_array(u64.wrap(n) * u64(4)));`: C++'s own `operator new[]`, from `libcxx`, for an array of numbers or pointers |
| `delete s;`, `delete[] xs;` | `s.destroy();` where the class or a base declares a destructor, and nothing where none does; `op_delete_array(ptr(xs));`, C++'s own `operator delete[]` |
| `struct Slot { int tag; Inner *inner; };`, in memory C allocates, holding a pointer to an object of a class port writes as an `obj`: `s->inner = new Inner(5);`, `Inner *in = s->inner;`, `s->inner = NULL;` | `has inner: ptr = ptr();`: the address C holds the object at. `s[0].inner = held_at(held[Inner](hold(Inner(5))));`, `in: Inner \| None = held[Inner](s[0].inner) if not s[0].inner.is_null() else None;` (`held[Inner](s[0].inner)` where it is never null), `s[0].inner = ptr();`. The class is held from its `new` to its `delete` |
| `reinterpret_cast<Vt *>(this)` and `reinterpret_cast<Tab *>(vt)` of a class whose first member is a C record (`class Tab { Vt base; int n; };`) | `addressof(self.base)`: the member's own address, the record kept in the object; `held[Tab](base=vt)`: the `Tab` C holds whose member `base` is at `vt` (TypeError where C holds none). The class is held from its `new` to its `delete`. Only where the reading lays the member at offset 0; any other conversion between an object's pointer and a record's is refused |
| `struct State { bool busy; unsigned short turns; };` and `State *GetState() { return reinterpret_cast<State *>(&busy); }` in a class with the fields `busy` and `turns`: a record that views an object's own fields | `def GetState -> Gate { return self; }`: every `State *` is the object itself, and `state->turns` its field at that offset, `state.turns`; the record is not written. Only where every field of the record lies at the offset of a field of the object of the same type, by the reading's layouts; a view's pointer converted in any other way, deleted, or the record used by value, is refused |
| `Kid *k = new Kid(4); k->twice(); delete k;` of a class whose base is a library class (`class Kid : public tally::Keeper<Kid>`) | `k: Kid = held[Kid](hold(Kid(4)));`: the object, held for C++ from its `new` until its `delete`, which is `release(held_at(k));`: the C++ part ends there, and `destroy` runs with it; a pointer to it converted to its library base is the object (`base: Keeper[Kid] = k;`) |
| `C c(1);`, `C c;`, `C d = c;`, `c.get()`, `this->n`, `true` | `c: C = C.make(1);`, `c: C = C();`, `d: C = c;`, `c.get()`, `self.n`, `True` |
| `C(1, 2)` as a value | `C.make_i32_i32(1, 2)`: the constructor a library class's interface binds, or a ported class's `make` |
| `::operator new[](n * sizeof(T))`, `::operator delete[](p)`, `::operator new(n)`, `::operator delete(p)` | `op_new_array(n * u64(8))`, `op_delete_array(p)`, `op_new(n)`, `op_delete(p)`: C++'s replaceable allocation functions, from `libcxx`, so that memory a file that stays C++ allocates is freed by the port as C++ frees it, and the reverse; where C++ would throw `std::bad_alloc` they raise `MemoryError` |
| `template <class T> T *filled(size_t n, T v) { ... sizeof(T) ... }`, `filled<int>(3, 4)`, `filled(2, 0.5)` | `def filled[T](n: u64, v: T) -> ptr[T] { ... u64(sizeof(T)) ... }`, `filled[i32](3, 4)`, `filled[float](2, 0.5)`: a function template of the file is a Jac generic, written once from its pattern and checked for each instance the program calls, with the type arguments C++ deduced written at the call |
| `static int bump_by(Counter &c, int step) { ... }`, `hooks.on_bump(bump_by)`, `Apply(Bump, t, x)`, `t.Scaled(Inc, x)`: a function of the file given where a library's function takes a pointer to a function, of C++ types or of C types alone | `def bump_by(c: Counter, step: i32) -> i32 { ... }`, `hooks.on_bump(bump_by)`: the Jac function by its name, which the library keeps and calls as it called the C++ function; an exception it raises crosses back to the Jac caller of the library's call, and ends the program where the library is built without exceptions |
| `class Drop : public Pool<Drop> { int plus(int x); ... }`, `Pool<Drop>::call(&Drop::plus, 5)`: a member function of the file's class given where a library takes a pointer to a member function | `Drop.call(Drop.plus, i32(5))`: the method by its class, which the library calls on the object it holds |
| `template <typename Callable> static int run(Callable cb, int start)`, `Hooks::run(bump_by, 2)`, `Box<int>::keep(3, bump_by)`: a library's member template whose template argument C++ deduces from the function given | `Hooks.run(bump_by, 2)`, `Box[i32].keep(3, bump_by)`: the template by its own name, with no type arguments: the instance is the one the function given makes |
| `a == b`, `v[i]`, `s += t` on a class a library gives | `a.op_eq(b)`, `v.op_index(i)`, `s.op_iadd(t)`: the member its interface binds for the operator, `op_` and the operator's name, a conversion `op_to_` and its type |
| `NULL` where C++ takes it as the integer it is (an argument of `...`) | `0`, of the type C++ gives it; where it becomes a pointer, `None` or the null address as C's `NULL` is |
| `reinterpret_cast<File *>(f)`, `reinterpret_cast<uintptr_t>(p)` | `ptr[File](f)`, `u64.wrap(int(p))`: C's cast of a pointer to another pointer or to an integer, and back; one of a reference or of a pointer to an object of a class with virtual functions is refused |
| `const_cast<int *>(p)`, `const_cast<Item &>(it)` | `p`, `it`: the same place at the type without `const`, which Jac's types do not carry |
| `total({1, 2, 3})`, `DefineClass(env, "Tally", {PrototypeMethod<Tally, &Tally::Add>("add")})`: a list in braces C++ makes an `std::initializer_list` of | `total([i32(1), i32(2), i32(3)])`: a Jac list of the items, which a library's interface takes where C++ takes an initializer list |
| `auto next = [&rd]() { return rd() << 1; };`, `next()` | `next: Callable[[], u32] = lambda -> u32 { return rd() << 1; };`, `next()`: a Jac closure, which shares the variables it names, as a capture by reference does. A capture by copy, `[base](int k) { return base + k; }`, is a local made where the lambda is made, which the closure has: `base_copy: i32 = base;` before `lambda (k: i32) -> i32 { return base_copy + k; }`, and a `mutable` lambda changes it. A capture by copy in a loop (a Jac closure shares the one variable every pass makes), of what is no number or pointer, or where C++ makes the lambda only sometimes, one that makes a variable, and a lambda with `auto` parameters are refused |
| `std::call_once(flag, []() { opened++; });` in `open_once()` | `def open_once_call_once { opened += 1; }`, `std_call_once(flag, open_once_call_once)`: a lambda with nothing captured, given to a library's function template that deduces its type argument from it, is a def of the file, named by the function it is in and the template (`_2`, `_3` for a second and a third), given by its name; one that captures is refused |
| `const Ref Agg::*which = &Agg::fn;`, `(self->*which).Value()` | `which: Callable[[Agg], Ref] = lambda (of: Agg) -> Ref { of.fn };`, `which(self).Value()`: a pointer to a member that is const through it is the function that reads the member; one a write may go through, and one to a member function, are refused |
| `template <class T, int (*method)(const Info &)> int checked(int n) { ... method(i) ... }`, `checked<Gauge, &Gauge::read>` | `def checked_Gauge_Gauge_read(n: i32) -> i32 { ... Gauge.read(i) ... }`, `checked_Gauge_Gauge_read`: a function template with a pointer to a function among its parameters is written once for each instance the program makes, as C++ makes it, named by the template and its arguments; each is a named function, which C may hold and call |

## Overloads

Jac has one function to a name, so port names each member of a C++ overload set, a class's
constructors included, by the interface types of its parameters, joined by `_`: `scaled(double)`
is `scaled_f64`, `scaled(int, int)` is `scaled_i32_i32`, and a second constructor `C(int)` is
`C.make_i32`. A name with one member keeps its name. Clang says which member a call names, and
a C++ module's native import names its members the same way.

## Static members

A static member function is a `static def` of its struct (`static def boxes(n: i32) -> i32`), or
its `impl` when it is defined outside the class, and a call names it by its class: `C::boxes(13)`
is `C.boxes(13)`, and inside the class an unqualified `per_box()` is `C.per_box()` too. A static
data member is a `static has` of its struct, with the value its class gives it or, when the file
defines it outside the class (`int C::shelf = 40;`), the value that definition gives it; a use
names it by its class (`C.shelf`). One of a C record's type is that record, and its address
is the record's (`&C::OPS` is `addressof(C.OPS)`); the address of one of any other type is
refused. A static member function is a named function as a value, so a field of a C record
takes it as a callback (`Ops(version=1, twice=C.Twice)`).

## Library classes

A class of a C++ library the project holds as a C module of headers (node-addon-api's
`Napi::Object`), and of archives to link where it has them (LLVM's `llvm::Module`), is used
as it is: port imports it from the header's module by the name its interface gives it
(`import from "node_modules/node-addon-api/napi" { Object }`). Of a library that lists one
header, every name of its directory is that header's; of one that lists several, each name is
its own header's (`toolchain.llvm.include.llvm.IR.Module ++> app.units { Module }`). A
member the library defines in its headers (inline, or a template's) is called through the
interface's shim, and one it defines out of line at its symbol in its archives. A class of
the C++ standard library is libcxx's, by its template form: `std::vector<int>` is
`std_vector[i32]`, `std::lock_guard<std::mutex>` is `std_lock_guard[std_mutex]`, `std::string`
is `std_string`. A local or field of one whose destructor runs code is bound `own`, so it is
dropped where its scope ends, as C++ destroys it. Port reads a library's interface for what
the source names, its classes and the members its calls name, from the library's headers
parsed once ([C modules](c-modules.md#what-a-program-binds-of-a-c-module)); and the source
for the platforms the library's archives are built for.

Each constructor, method, operator and conversion a call names is the member the class's
interface binds for that very declaration, by the name the interface gives it, on each target:
`std::lock_guard<std::mutex> g(m)` is `std_lock_guard[std_mutex].make(m)`; an operator is
`op_` and its name (`v[i]` is `v.op_index(i)`, `a == b` is `a.op_eq(b)`), and a conversion
`op_to_` and its type (`int n = c;` is `n: i32 = c.op_to_i32();`). A member the interface binds
under another's name stands for it where their parameters are the same to Jac
(`push_back(const int&)` and `push_back(int&&)`); a member the interface does not bind is
refused, with the interface's reason. A parameter that is a reference to such a class
(`const C&`, `C&`) is a borrow of it, `c: &C`. A store through the reference a member gives
(`v[i] = x`, `v.at(i) = x`) is the store the interface binds beside it, `v.op_index_set(i, x)`,
`v.at_set(i, x)`. A construction by a constructor template is the instance the library's
reading makes for it, named by its parameters as any constructor: `std::string s(p)` is
`std_string.make_ptr_i8(p)`. A class made with `signed char` is refused: as a template's
argument Jac's `i8` is plain `char`.

A call of a library class's member template names the instance by its type arguments, as Jac
types: `v.As<Napi::Object>()` is `v.As[Object]()`, `c.to<double>()` is `c.to[float]()`. Member
templates of one name are named as an overload set is, by the types of the parameters the
template does not make: `o.Set("k", fn)` is `o.Set_ptr_i8[Function]("k", fn)`. The program's
build makes each instance it names.

An instance of a header library's class template is named by its template form, its arguments
Jac types: `Napi::Reference<Napi::String>` is `Reference[String]`, `tally::Box<int>` is
`Box[i32]`, and a member template's argument may be one (`v.As<Napi::Buffer<char>>()` is
`v.As[Buffer[i8]]()`); the program's build makes each instance the library does not. As a
template's argument `i8` is plain `char` (`Napi::Buffer<char>` is `Buffer[i8]`), and an
instance made with `signed char` is refused; a pointer is `ptr[T]` (`std::vector<napi_value>`
is `std_vector[ptr[napi_value__]]`). A free function of
the library is named as its interface names it (an overload set's member by its parameters,
`twice_i32`), wherever in the library's directory it is defined, and the wire names the set by
its C++ name (`tally.tally ++> app.use { twice }`).

A call of an instance of the library's function template is named by its template arguments,
as a member template's is: `tally::kept(c)` is `kept_[Counter](c)`, the template named as an
overload set's member is, by the parameters it does not make, so that a function of its name
that is no template is named by its own (`tally::kept("four")` is `kept_ptr_i8("four")`);
the program's build makes the instance.

A member that has both a form taking a class by `const T&` (or by value) and one taking it by
`T&&` gives the second as `<name>_move`: `a = b` is `a.op_assign(b)` (or the copy's name among
`operator=`'s overloads, such as `op_assign_std_string`), `a = std::move(b)` is
`a.op_assign_move(b)`, which leaves `b` as the class's move leaves it, and `v.push_back(p)` of
a temporary is `v.push_back_move(p)`. `std::move(x)` and `std::forward<T>(x)` are `x` where a
library class's parameter of type `T&&` takes them, and refused anywhere else.

A record a system header declares that C could declare too (`struct stat`,
`napi_property_descriptor`, `sqlite3_module`) is C's, as in a C file: the file's import block
binds it with its fields, and a local of it C++ leaves unset (`struct stat st;`) is made zeroed.

## A unity build

A file its module compiles only inside another (a source that `#include`s it) is read as that
source reads it, and ports with it: when either is refused, so is the other (E4010 for the file
included, E4043 for the source that includes it), since one without the other is compiled nowhere.
In a unity build a function or a variable one file declares `static` is still every file's, so
the module of the file that defines it gives it to the others.

## Classes written as an `obj`

A class with virtual functions is an `obj`, and so is a class the run makes with `new` anywhere
(`new Addon(env)` in one file makes `Addon` an `obj` in every file of the run), if its base is
one too. Such a class is held by reference as C++ holds it by
pointer: `Shape *`, `Shape &` and `const Shape &` are all `Shape`, and a call of a virtual
function dispatches as C++'s does. A class of pure virtual functions and other functions, with
no data member, no constructor and nothing static, whose base, if it has one, is such a class
too, is an [interface](../language/interfaces.md): its functions with a body are its defaults,
and a pointer or a reference to it is `dyn Shape`. Its one base, if it has one, is its base in Jac, from another
file's module where that file declares it. Its constructor is its `init`, a base class
initializer `super.init(...)` (and `super.init()` where C++ runs the base's default
constructor), and `new Square(2.0)` is `Square(2.0)`. Its destructor is `def destroy`, ending
with `super.destroy();` where a base declares one, and `delete s;` is `s.destroy();`: the
destructors run where `delete` runs them, the subclass's first, and Jac frees the object when
nothing holds it. A pure virtual function is `abst`, and `Base::area()` called on an object is
`Base.area(s)`, which does not dispatch. Through an interface every call dispatches, so its
`Shape::name()` called on `this` in a subclass is `super.name()`, the interface's own
definition, and called on another object it is `Shape.name(s)` where no subclass gives its own
`name`, and refused where one does. A function that hides a base's function of the same name
that is not virtual is refused: C++ calls the base's through a pointer to the base, where a Jac
method of that name overrides it.

An object made by `new` and given where C takes a `void *` (a callback's user data) is lent to
C: `hold(Tally())`, a counted reference C holds. `static_cast<Tally *>(ctx)` of that address is
`held[Tally](ctx)`, the object again, and `delete static_cast<Tally *>(ctx);` is
`held[Tally](ctx).destroy(); release(ctx);`: the destructors run there, once, and C's
reference goes. Where the address of an object of such a class goes to C at any point of its
life (decided per class across the run), C holds the object from its `new` to its `delete`:
`hub: Hub = held[Hub](hold(Hub()));`, each conversion of it to `void *` is `held_at(hub)`, its
address with no count of its own, and `delete hub;` is `hub.destroy(); release(held_at(hub));`.
A local of such a class is refused.

A member whose destructor runs code (`std::vector<int> xs;`) is a field with no ownership
annotation, a managed place: `destroy` ends it after the destructor's body, `del self.xs;`,
members in reverse declaration order and then `super.destroy();`, as C++ ends them at the
`delete`. A class with such members and no destructor of its own is given that `destroy`.
A member of a library class with no default constructor (`tally::Counter kept;`, which each
constructor initializes) is a field with no default, which `init` sets.

A local of such a class made by a constructor, `TempConverter conv(this);`, is
`conv: TempConverter = TempConverter(self);` where no class of it declares a destructor, so
nothing runs where its scope ends, and `&conv` is `conv`. Every copy of such an object (a copy
or move constructor, a copy assignment, a parameter, a result or a field by value) is refused,
so the local is the one object, and the Jac reference names it.

A pointer to such an object that may be null is `T | None`: a local, parameter, field or
result the run gives null or tests against null is (decided across the run), and so is every
one its value goes to, so no `T | None` reaches a place typed `T`. `NULL` is `None`, `p == NULL`
is `p is None`, `if (p)` is `if p is not None`, and a member of one that holds None raises
AttributeError where C++ would read through the null pointer.

An object of such a class held by value where its destructor would run, copied, a pointer to
one that may be null given to C as a `void *` or held by a C struct, a call
of a member function on `this` in its constructor or destructor (C++ dispatches there as the
class being made), an overloaded virtual function, more than one base or constructor and a
`return` in its destructor are refused.

A reference to an object of a class port writes as an `obj` is the object. A reference to
anything else, a number, a pointer, a record port writes as a struct or a C record, is its
address, a `ptr[T]` that `addressof` makes, read and written through `[0]` as C's pointer is:
a C++ reference is an alias nothing checks, as a pointer is. `void bump_by(int &n, const int &step)`
is `def bump_by(n: ptr[i32], step: ptr[i32])`, its body's `n += step` is `n[0] += step[0]`, and its
caller gives places, `bump_by(addressof(k), addressof(step))`; a constant one given a value is
given the address of a local that holds it (`bump_by(addressof(k), addressof(was_1))` after
`was_1: i32 = 2;`). `int &r = k;` is `r: ptr[i32] = addressof(k);`, `Counts &k = c->tally();`
is `k: ptr[Counts] = c.tally();`, `Counts &tally() { return counts; }` is
`def tally -> ptr[Counts] { return addressof(self.counts); }`, `tally_at(1) = 20;` of a
function giving `int &` is `tally_at(1)[0] = 20;`, and a member `int &at;` is
`has at: ptr[i32]`, which the constructor sets to the place it is given. A reference to an object
of a library class is the borrow above.

## What is refused

Anything not in the table or in C's is refused with E4001: inheritance from a class port does
not write as an `obj`, the file's own class templates, a function template with a value, a pack
or a default among its parameters or whose body applies an operator to a value of its type
parameter, a header library's function template whose instance the call names by what is
no class or number type, a
standard library class the library keeps to itself (`std::__wrap_iter`) named but through a
local a call gives it to, operators of the file's own classes but those the table maps,
a non-member operator, `std::move` but as a
library class's `T&&` argument, the destructor of a class
port does not write as an `obj`, an rvalue reference to what is no class object, a reference
to a number a field of an `obj` holds, a reference to a temporary made where C++ evaluates it
only sometimes, a member operator that takes a reference to what is no class object, lambdas,
a range `for` over an array whose variable is a reference to
its item, a conversion to a virtual base or to a base at another address than a library
object's own, exceptions, a placement `new` (into storage the
program gives) and an explicit destructor call (no Jac form keeps an object in raw memory), `new[]` and
`delete[]` of anything but numbers and pointers, a static data member another file defines, a member
of a library class its interface does not bind (a member template's instance whose arguments
are no class or number type among them), a member of a library class with no default
constructor in a class port writes as a struct, and a field of a C++ class a system header
declares that C could not declare.
