---
description: Using npm packages and Node's built-in modules from a native Jac program - imports by quoted name, how their names are checked from TypeScript declarations, how values cross, Node's loop, and neojac node, npm and npx.
keywords: npm, npm package, Node.js, JsObject, JsNull, js_error, js, node:, Node-API, TypeScript declarations, js_add, js_truthy, js_item, js_method, js_iter, js_unpack, js_array, js_invoke, js_with_length, js_promise, js_for_in, js_typeof, js_meta, js_global, js_mod, js_shl, js_band, js_new_target, js_rest, js_delete, js_prototype, js_as_method, js_async_generator, new.target, extends, CommonJS, require
---
# npm and Node

A native Jac program imports an npm package, or one of Node's built-in modules, by its quoted
name. Node then runs inside the program's own process, and what the module gives is used from Jac
directly.

```jac
import from "node:path" { basename, join }
import from "node:url" { URL }
import from "node:util" { format }

with entry {
    print(join("docs", "interop"), basename("/x/y.txt"));
    print(format("%s is %d", "x", 5));
    u = URL.new("https://example.org:8080/docs?q=jac");
    print(u.hostname, u.searchParams.get("q"), type(u).__name__);
    port: int = int(u.port);
    print(port + 1);
}
```

```output
docs/interop y.txt
x is 5
example.org jac JsObject
8081
```

Node is neojac's own: nothing needs installing on the machine. A package from the registry is
listed in the project's `jac.toml` and installed with `neojac install`, by npm on that Node.

This page is about JavaScript a native program calls. A space whose host is `node` or `browser`,
whose own Jac is compiled to JavaScript, is described in [Apps](../apps/index.md)
(`neojac docs apps`).

## Installing packages

A project's npm packages are an npm tree of its `jac.toml`: a `[npm."<directory>"]` table, which
is the `package.json` of that directory ([Packages](../toolchain/packages.md)):

```sh
neojac install --npm nanoid lodash --tree eco/app    # the first packages name the directory of the tree they make
neojac install --npm @types/lodash               # declarations, for a package that ships none
```

```toml
[npm."eco/app".dependencies]
nanoid = "^5.1.0"
lodash = "^4.17.21"
"@types/lodash" = "^4.17.0"
```

They are installed in `eco/app/node_modules`, and `jac.lock` records what npm resolved. On a fresh
clone, `neojac install` installs them again. `main.jac`, in that project:

<!-- example: not checked: needs nanoid and lodash installed in node_modules -->
```jac
import from "lodash" { default as _ }
import from "nanoid" { customAlphabet, nanoid }

with entry {
    pairs: list[list[int]] = _.chunk([1, 2, 3, 4], 2);
    make = customAlphabet("abc", 8);
    id: str = make();
    print(pairs, len(nanoid(10)), len(id));
}
```

```text
[[1, 2], [3, 4]] 10 8
```

## How an import is resolved

- `import from "pkg" { a, b }` imports the module as an ES `import` of that specifier does on Node:
  Node's own resolution and export conditions, from the directory of the project's npm tree: its
  only tree, or the one the module's space names in `jac.toml`.
  It is settled as the program starts, before its entry code runs.
- Each name is the module's export of that name. A CommonJS module's `module.exports` is its
  `default`: `import from "lodash" { default as _ }` is the form to write, and `_.chunk` its
  function. Its properties are not named exports, as in Node's ES modules, so
  `import from "lodash" { chunk }` raises `ImportError: cannot import name 'chunk' from 'lodash'`
  as the program starts. Checking catches that only where the package has declarations
  (`@types/lodash` makes it E1145); without them the import passes `neojac check`.
- `import "pkg";` imports a module for its effect.
- `node:` names Node's built-in modules (`node:path`, `node:fs/promises`, `node:events`, ...).
- The program reads its packages from the tree's `node_modules` in the project as it runs,
  wherever the program itself is. An app's artifact carries them with it
  ([Building apps](../apps/building.md)). Node starts the first time the program imports a JavaScript module.

## A project's own JavaScript

A JavaScript or TypeScript file of the project is a module of it, named by its path from
`archwire.jac` as a Jac module is (`kit/loud.js` is `kit.loud`). A Jac module takes its exports
through a [wire](../language/modules-wiring.md), as it takes another Jac module's:

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    kit.loud ++> page { shout, default as pick }
    kit.loud as loud ++> page;
    kit.marks --> kit.loud { mark }
}
```

- `{ shout }` binds the export `shout`, `{ default as pick }` the default export, and a wire with
  no names the module's namespace, under the name `as` gives it. A module wired whole under a
  dotted name and no `as` is loaded for its effect.
- A wired name the file does not export is E1145, read from the file by TypeScript. A CommonJS
  file states no exports, so any name is taken of it.
- The file writes its own imports, of packages and of other files of the project. Each import of
  another file of the project is declared by a `-->` wire, which TypeScript holds to the source
  ([Declared wires](../language/modules-wiring.md#declared-wires---)).
- Under an `archwire.jac` the file is not imported by its path: `import from "./kit/loud.js"
  { shout }` is E1144, whose message gives the wire to write. A path import stays for what is no
  module: a stylesheet or an asset a browser space's bundler takes.
- **A file imports the space's Jac modules** as JavaScript modules: `tone.jac` is the module
  `tone.js` beside it, so `kit/echo.js` writes `import { tone, bump } from "../tone.js";`, which
  the wire `tone --> kit.echo { tone, bump }` declares, and its names are held to the Jac module.
  A module's [default](../language/modules.md#a-modules-default) is its default export, and
  only that: `default def reset` is JavaScript's `default`, not also an export `reset`, as
  `export default function reset` is in JavaScript (a wire naming `reset` is E1145, and its face
  need not declare it), while a Jac module still imports it by its name. What it
  imports is the module's forwarder, which gives exactly the module's names: its public
  functions, and its globals of a function type, by their faces as JavaScript calls them (below),
  its classes, other globals and types as they are, and nothing of its own (`:priv` names, the
  module's machinery). In a laid tree ([A project's own suites](../toolchain/test.md#a-projects-own-suites))
  the forwarder of a ported module has the source's own name and extension (`util.ts`,
  `main.tsx`, `counter.mts`), a TypeScript module typed by the module's face where the source was
  TypeScript, and the face is laid with the emission in the laid tree's `.jac/`, not among the
  tree's files; a value the module never assigns again is declared in the forwarder's own text
  (`export const LIMIT = $m.LIMIT`), so that a tool reading the text finds it, and any other
  global is given live from the module. The Jac source itself stands at its place too, a link
  to the project's file, and the source maps name it there, so a test runner reports a ported
  test's failure at `tests/login.spec.jac:24:5`. The laid tree's top
  links the project's entries beside the tree, so a path that leaves the tree (`../../.env`)
  reaches the project's own file. In a node space the
  forwarder stands at that place;
  in a browser space the bundler resolves the import to it ([Vite](../apps/ui-bindings.md#vite)),
  and the module starts as the bundle imports it.
- **A `.d.ts` beside a Jac module of its stem** (`kinds.d.ts` beside `kinds.jac`) is that
  module's face to TypeScript, as a C header beside a module is its face to C: TypeScript reads
  the module's types there, and a type a TypeScript file imports of the module is held to it. It
  is no module of the project (not a module `kinds.d`), and an app or a laid tree carries it
  beside the module's JavaScript. [`neojac port`](../toolchain/port.md) writes it of a module it
  made from TypeScript, as TypeScript's own declaration output for the source. A `.d.ts` file of
  the project's own holds no code, and is never ported.
- **A face is held to its module.** `neojac check` has TypeScript read it, and each name it
  declares must be one the module gives (E2313), each name the module gives one it declares
  (E2314), and each of the same kind, a value or a type (E2315). A module with no face of its
  own still has one for TypeScript, its forwarder's names, each `any`.
- **A CommonJS file** (`.cjs`, or a `.js` where Node reads the place as CommonJS) that `require`s
  a Jac module is given it as CommonJS: its exports, and for `require` itself the module's
  default where it has one.
- **A global is live, but a function's and the default.** What a file imports of a module's
  `glob` is the global as it is when read, as an ES module's export is: a global the module
  assigns again is seen anew. A global whose declared type is a function type
  (`glob scale: Callable[[int], int] = twice;`) is given through its face, and the module's
  `default` as itself, each as it stands once the module has started, as `export default` and
  `module.exports =` are. A program that assigns such a global again while a file imports it is
  refused (E2311): the file would keep the first. A CommonJS file's exports are live, all of them:
  each is read from the module when used, and what JavaScript assigns to one replaces it, as a
  CommonJS `exports` object takes it.
- **A module JavaScript runs through its forwarder is named by the forwarder**: its `js_meta()`
  `url`, `filename` and `dirname` are the forwarder's place (`lib/util.js`, not the emitted
  `lib/util.mjs`), as a CommonJS module's `__filename` is the file that runs, so a ported
  module's `__filename` and a worker started on it (`new Worker(js_meta().filename)`) find it.
  Its `js_meta().main` is true where Node ran the forwarder as its entry (`node lib/twice.js`),
  as `require.main === module` and `import.meta.main` are of the file Node runs; a module
  started on demand by another's import is not main. A worker that loads the forwarder starts
  the program in its own thread.
- **Any other member of `js_meta()` is the module's own `import.meta`**, in the text of the
  module's emission: `js_meta().env.MODE`, `js_meta().hot` and `js_item(js_meta().env,
  "VITE_API_URL")` are emitted as `import.meta.env.MODE`, `import.meta.hot` and a read of
  `import.meta.env`, which a bundler such as Vite rewrites in the module where it stands. Port
  writes a source's `import.meta.env` so, and refuses `import.meta.glob(...)` (E4005): a bundler
  expands its patterns from the module's own place, which in a port holds the Jac and not the
  sources the patterns name.
- **A Jac module's `with entry` code runs once JavaScript first reaches the module**; the space's
  entry module's runs at the end of its loading.
- A node space carries the file, and every file of the project it imports, beside its own modules,
  each at its path in the project, as it is: Node runs it, so what it imports must resolve on
  Node. A browser space's bundler reads it where it is. A native program imports it from where it
  is, and an app's artifact carries it at the same path.

## How names are checked

neojac reads a package's TypeScript declarations: its own `.d.ts` files, or those of
`@types/<pkg>` when it ships none. It resolves the package as an ES import does, under the
`import` condition, so a package with separate ES and CommonJS builds is checked against its ES
build's declarations.

- A name the declarations don't export is refused where it is imported (E1145).
- A package with no declarations is dynamic: its names are not checked, and a name it lacks is an
  `ImportError` as the program starts.
- Node's built-in modules are not checked: `import from "node:path" { nope }` builds, and raises
  `ImportError` as the program starts.
- Only the imported names are checked. An attribute of a JavaScript value (`_.nope`) is looked up
  as the program runs, an `AttributeError` when the object has no such property.
- Types are not checked. The declarations' parameter and return types are not applied to a call,
  whether the function is a named import (`nanoid` of `import from "nanoid" { nanoid }`) or a
  member of a default import (`_.kebabCase`): `nanoid("ten")` passes `neojac check`, and so does
  `n: int = _.kebabCase("A B")`. A call's result is a JavaScript value, converted where a Jac type
  is wanted ([below](#javascripts-values-in-jac)); that one is a `TypeError` as the program runs
  (`expected int, found str`). Annotate what a call returns with the type it is.
- A build reads the declarations again when they change.
- The host's own names (`Date`, `RegExp`, `Symbol`, `isNaN`) are its declarations' globals. A name
  that is Jac's wins: `Number` is Jac's interface of the number types, so `Number.isNaN(x)` is
  E1030. JavaScript's `Number` is `globalThis.Number`, as every global is `globalThis`'s:
  `globalThis.Number.isNaN(x)`, `globalThis.Number.MAX_SAFE_INTEGER`.

neojac reads declarations with TypeScript 6.0.3, which it fetches the first time it needs it: that
first check needs the network.

## JavaScript's values in Jac

An object, function or symbol JavaScript gives is a `JsObject`. Its properties are its attributes
(`o.n`) and its items (`o["n"]`); calling a function read from an object, either way, calls it with
that object as `this`. `C.new(args)` is JavaScript's `new C(args)`. Iterating it iterates it as
JavaScript does, and `len()` reads its `length`.

A primitive is the Jac value it is:

| JavaScript | Jac |
|---|---|
| `undefined` | `None` |
| `null` | `JsNull`, from the runtime's `js` module (`import from js { JsNull }`) |
| a boolean | `bool` |
| a number | `int` when it is whole and an int holds it (`2**60` is `1152921504606846976`), else `float` (`-0` is `-0.0`, `2**63` is `9.223372036854776e+18`) |
| a BigInt | `int`; `OverflowError` past 64 bits |
| a string | `str`; `ValueError` for one holding a lone surrogate |

A `JsObject` fits wherever a Jac type is wanted, and becomes a Jac value as it arrives there,
copied: an array a `list` of what its items become, a plain object (whose prototype is
`Object.prototype` or `null`) or a `Map` a `dict`, a `Uint8Array` (a `Buffer` among them)
`bytes`. Any other object is a `TypeError` where another type is wanted. A cycle the copy reaches
is one value, reached again.

On a JavaScript host an array JavaScript gives Jac is JavaScript's own, and crosses back as
itself, not as a copy: what a JavaScript function returns, a property or an item read of a
JavaScript object, a method's result, what a promise resolves to, and an argument JavaScript calls
a Jac function's face with. Jac holds it as an `any` or a `list` with no copy, and JavaScript
given it again gets the same array (`===`), so a `WeakSet` or a `Map` keyed by it finds it. An
array a Jac list makes is a new one each time it crosses; `js_array(items)` of `js` makes
JavaScript's own array of Jac's items, which crosses as itself.

A `JsObject` equals only itself: `a == b` is whether they are the same JavaScript value, so two
objects with the same properties are not equal. `copy.copy` of one is that same value.

## Jac's values in JavaScript

| Jac | JavaScript |
|---|---|
| `None` | `undefined` |
| `JsNull` | `null` |
| `bool`, `float`, `str` | a boolean, a number, a string |
| `int` | a number; `OverflowError` past 2**53, where a number stops being exact |
| `bytes`, `bytearray` | a new `Buffer` of its bytes |
| `list`, `tuple` | a new array of what its items become |
| `dict` | a new plain object when its keys are all strs (each an own data property, `__proto__` among them), else a new `Map` |
| a function or lambda | the function itself, as JavaScript calls it (below) |
| any other Jac object | a JavaScript object wrapping it |
| a `JsObject` | what it holds |

A Jac function or object stays one JavaScript value for as long as JavaScript holds it, and comes
back to Jac as itself: `ee.off("x", cb)` removes the listener `ee.on("x", cb)` added.

**A Jac function is one function to both sides.** What JavaScript holds of it, its face, is a
JavaScript function, one for each Jac function, so JavaScript sees the same function each time it
is handed it; it is no `Proxy`, its prototype is `Function.prototype`, and its
`prototype.constructor` is the face. On a JavaScript host a generator function's face is a
generator function, an async function's an async function and an async generator's an async
generator function (`Object.prototype.toString` gives `[object AsyncFunction]`), and the Jac function's own prototype is its face, so a property either side
sets on it is the other's (JavaScript's `f.tag = "x"`,
Jac's `setattr(f as any, "tag", "x")`), and it is constructible where the function is, as in
JavaScript: `new f(...)` constructs an object of `f.prototype`, `self` the new object, and a
subclass's `super(...)` reaches it, where an async function or a generator function is not
constructible. A module's `default` that is a function crosses as its face, as a CommonJS
module's exports do. A function whose first parameter is `self` is constructible natively too:
`new P(3)` of `def P(self: any, x: any) { self.x = x; }` makes the object. Natively the face
holds what JavaScript sets on it, and a native function takes no attribute of Jac's.

On every host the face's `name` is the function's, a nested `def`'s own name among them (`add`,
where a lambda's is empty), and its `length` is the count of its positional parameters before
`*args`, `self` not counted where JavaScript gives it as `this`, as mocha reads `length` to tell
a test that takes `done`: `def add(x: int, y: int = 1, *rest: any)` has `length` 2. On a
JavaScript host a function's text to JavaScript (`String(f)`, `f.toString()`) is its own emitted
JavaScript where JavaScript's arguments bind to its parameters as they stand (no keyword-only
parameter, `*args`, `**kwargs`, default or `self`), so a library that sends a function's text to
run elsewhere, as Playwright's `page.evaluate(() => ...)` sends it to a browser page, sends code
that runs there: `def twice(x: int) -> int` reads `function twice(x) { ... }`. Elsewhere it is the
face's, written with the function's own parameter list, as a test runner that reads a hook's
parameters reads it: `def add(x: int, y: int = 1, *rest: any)` is `function (x, y, ...rest)`,
with no default's text (a Jac default is Jac's to evaluate). Natively a function's text is
`function () { [native code] }`.

**JavaScript's arguments are bound by the function's parameters**, on every host: its positional
parameters by position, its `*args` the arguments past them, a parameter left out its default
(None where it has none, as `undefined` is). Arguments past what it names are dropped where it
has no `*args`, as JavaScript drops them, so a callback that `array.map` gives three arguments
may name one.

**Keyword-only parameters are one object to JavaScript**, its last argument, taken by
JavaScript's own pattern: `def opened(x: int, *, page: str, n: int = 2)` is, to JavaScript,
`function (x, { page, n })`, and its `**kwargs` is the pattern's rest (`{ a, b, ...more }`). A
name the object lacks, or holds as `undefined`, takes its default, None where it has none, as
JavaScript's pattern gives `undefined`; a name it holds that the function does not take goes to
`**kwargs`, or nowhere. Where none of them is required the pattern defaults to `{}`
(`function ({ a, b } = {})`), so a call with no object takes every default; where one is, a call
with no object throws JavaScript's `TypeError`, as the pattern does. The object counts in `length`
where one is required. A function with `*args` takes no such object (JavaScript has no parameter
after a rest), and its keyword-only parameters take their defaults.

```jac
import from "node:vm" { runInThisContext }

def opened(x: int, *, page: str, n: int = 2) -> str {
    return f"{x} {page} {n}";
}

def summed(*, a: int = 1, b: int = 2, **more: any) -> int {
    return a + b + len(more);
}

with entry {
    calls = runInThisContext(
        "(f, g) => [f.length, g.length, f(1, { page: 'p' }), f(2, { page: 'q', n: 5, more: 0 }), "
        "g(), g({ b: 5, c: 1 })].join(' / ')",
    );
    print(calls(opened, summed));
}
```

```output
2 / 0 / 1 p 2 / 2 q 5 / 3 / 7
```

**A Jac call of a JavaScript function with keyword arguments** gives them, on every host, as one
object after the positional arguments, which the function takes by its own pattern:
`take("x", a="a")` of `(x, { a, b = 'b' }) => x + a + b` is `"xab"`, and a method's call
`o.m(1, k=3)` gives `m` the arguments `1, { k: 3 }`. What the function gives back to JavaScript crosses as an
argument does: a function as its face, a list as a new array, a dict as an object, and of a
coroutine a promise of that.

**An async generator crosses as JavaScript's own**: where a Jac async generator reaches
JavaScript (an argument, a result), JavaScript's `for await` drives it, its `next(v)`, `return(v)`
and `throw(e)` answer as an async generator's do (`{ value, done }`, a call made before the last
one settles waits its turn), and it is an `[object AsyncGenerator]`. `js_async_generator(g)` of
`js` gives that face in Jac: `js_method(js_async_generator(g), "next")` is JavaScript's
`g.next()`. Natively a value JavaScript's `next(v)` sends is a `RuntimeError`, since a native
async generator takes none. **A coroutine crosses as a promise** of its result, on every host:
natively it runs at once to its first wait, as an async function's body does, and on as each
promise it awaits settles; its exception is the promise's rejection. A Jac `async for` takes
JavaScript's async iterables, anything with a `Symbol.asyncIterator` (an async generator, a
stream), on every host.

<!-- example: not checked: runs in a node space -->
```jac
import from "node:vm" { runInThisContext }
import from js { js_async_generator, js_method }

async def count(n: int) -> AsyncIterator[int] {
    for i in range(n) {
        yield i;
    }
}

async def total(it: any) -> int {
    t = 0;
    async for v in it {
        t += v;
    }
    return t;
}

async def main {
    js_gen = runInThisContext("(async function* () { yield 1; yield 2; yield 3; })");
    print(await total(js_gen()));
    sum = runInThisContext(
        "(async (g) => { let t = 0; for await (const v of g) t += v; return t + ' ' + Object.prototype.toString.call(g); })",
    );
    print(await sum(count(4)));
    g = js_async_generator(count(2));
    first = await js_method(g, "next");
    print(first.value, first.done);
}

with entry {
    await main();
}
```

```text
6
6 [object AsyncGenerator]
0 False
```

```jac
import from js { JsNull }
import from "node:vm" { runInThisContext }

obj Thing {
    has x: int = 1;
}

with entry {
    kind = runInThisContext(
        "(x) => x === null ? 'null' : Array.isArray(x) ? 'array' : x instanceof Map ? 'map' : "
        "Buffer.isBuffer(x) ? 'buffer' : typeof x",
    );
    keyed: dict[any, any] = {1: "a"};
    print(kind(None), kind(JsNull), kind(True), kind(5), kind(1.5), kind("s"));
    print(kind([1]), kind((1, 2)), kind({"a": 1}), kind(keyed), kind(b"ab"), kind(Thing()));
    back = runInThisContext("(x) => x");
    t = Thing(x=7);
    print(back(t) is t, back(None) is None, back(JsNull) is JsNull);
    arr = runInThisContext("[1, 2, 3]");
    xs: list[int] = arr;
    d: dict[str, any] = runInThisContext("({ a: 1, b: [2] })");
    print(xs, d, arr[0], len(arr), [x * 2 for x in arr]);
    print(
        runInThisContext("1.5"),
        runInThisContext("2"),
        runInThisContext("2n ** 40n"),
        runInThisContext("undefined"),
    );
    o = runInThisContext("({ n: 3, f() { return this.n; } })");
    print(o.n, o["n"], o.f(), o["f"]());
}
```

```output
undefined null boolean number number string
array array object map buffer object
True True True
[1, 2, 3] {'a': 1, 'b': [2]} 1 3 [2, 4, 6]
1.5 2 1099511627776 None
3 3 3 3
```

A function whose first parameter is named `self`, outside a class, is called from Jac with the
object first, as any function is (`bump(o, 2)`). Called by JavaScript (handed to a JavaScript
function, stored on a JavaScript object, or imported by a JavaScript file), `self` is
JavaScript's `this`: `{ n: 1, bump }.bump(2)` calls it with the object as `self`. A lambda takes
no `this`, as a JavaScript arrow function takes none.

## JavaScript's own operators: the `js` module

Jac's operators mean what Jac says of Jac's types. Where a program needs what JavaScript does
with values of any type (code `neojac port` made of untyped JavaScript, or of TypeScript where a
value TypeScript took on trust reaches it), the runtime's `js`
module gives JavaScript's own operations, each a function. On a JavaScript host each is the
operator it names; natively each runs in the program's Node.

| Function | JavaScript |
|---|---|
| `js_truthy(x)` | `!!x`: false for `undefined`, `null`, `false`, `0`, `NaN` and `""` |
| `js_add(a, b)`, `js_sub(a, b)`, `js_mul`, `js_div`, `js_pow` | `a + b` (a string where either is one), `a - b`, `*`, `/`, `**`, converting as JavaScript does |
| `js_lt`, `js_le`, `js_gt`, `js_ge` | `<`, `<=`, `>`, `>=`: strings by their UTF-16 code units, else as numbers |
| `js_mod(a, b)` | `a % b`: the remainder, with the dividend's sign |
| `js_shl`, `js_shr`, `js_ushr`, `js_band`, `js_bor`, `js_bxor` | `<<`, `>>`, `>>>`, `&`, `\|`, `^`: each operand made a 32-bit integer (both BigInts, or neither), `>>>`'s result unsigned |
| `js_inc(x)`, `js_dec(x)`, `js_number(x)` | What `x++` and `x--` make `x`; `+x` |
| `js_same(a, b)` | `a === b` |
| `js_array(items)` | JavaScript's own array of `items`, which crosses to JavaScript as itself, not as a copy as a Jac list does; natively a `JsObject` |
| `js_typeof(x)` | `typeof x` |
| `js_item(o, k)`, `js_set_item(o, k, v)` | `o[k]`; `o[k] = v`, whose value is `v` |
| `js_delete(o, k)` | `delete o[k]` in strict code: `True`, a `TypeError` where the property cannot be removed |
| `js_rest(o, keys)` | The `...rest` of the pattern `{ a, b, ...rest } = o` whose other names `keys` lists: a new object of `o`'s own enumerable properties but those |
| `js_method(o, name, ...)` | `o[name](...)`, called on `o`: `name` a string or a symbol (`Symbol.iterator`), an array's or a string's own method among them |
| `js_invoke(f, ...)` | `f(...)`, called on no object: a Jac function whose first parameter is `self` takes JavaScript's `this` there, so it gets `None`, and the arguments bind the parameters after it; any other function is called as a Jac call of it is. What a port writes for a call of a value whose function it cannot know |
| `js_with_length(f, n)` | `f`, whose JavaScript `length` is `n`, whatever its signature counts: a function that takes its arguments as `*args` and binds its parameters from them says so (`function (a, b) { return arguments.length; }`, whose `length` is 2). The method `js_as_method` makes of it has that `length` too |
| `js_promise(co)` | The promise JavaScript's `await` takes of `co`: of a Jac coroutine, one that runs it at once to its first wait, as JavaScript runs an async function where it is called, its rejection JavaScript's unhandled rejection where nothing handles it; on a JS host, of any other value `Promise.resolve`'s. `await js_promise(f())` waits as JavaScript's `await f()` does, a microtask after the promise settles, where Jac's `await f()` runs the coroutine in place |
| `js_iter(x)`, `js_for_in(o)` | `x[Symbol.iterator]()`, what `for ... of` steps through; the keys `for (k in o)` visits |
| `js_unpack(o, n, rest)` | The array pattern `[a, , c, ...more] = o`: `o` iterated as JavaScript iterates it, a list of its first `n` items (`None` past its end) and, where `rest`, a list of the items after them last. An iterator the pattern leaves unfinished is closed (its `return()`); a `TypeError` where `o` is not iterable. `js_unpack(new Set([10, 20, 30]), 2, True)` is `[10, 20, [30]]` |
| `js_meta()` | The calling module's `import.meta`: its `url`, `filename`, `dirname` and `main`, the forwarder's place where JavaScript runs the module through one, and every other member the module's own (`js_meta().env`), as a bundler rewrites it ([above](#a-projects-own-javascript)) |
| `js_new_target()` | `new.target` of the call that reached the function it is written in: the function JavaScript called with `new`, else `None` ([below](#a-class-with-a-javascript-base)) |
| `js_global(name)` | The global `name` read where the call is written |
| `js_as_method(f, key)` | An object literal's method of `key` made of `f`, which takes the object, JavaScript's `this`, as its first parameter: `{ m(x) { ... } }` is `("m", js_as_method(m, "m"))` among `Object.fromEntries`' entries. Its `name` is the key's, JavaScript cannot construct it (`new o.m()` is a `TypeError`), and of a generator function it is a generator method |
| `js_prototype(f)` | `f.prototype`: of a Jac function, that of the face JavaScript calls with `new` (JavaScript's `f.prototype.m = ...` is `js_prototype(f).m = ...`); on a JS host only, a `RuntimeError` natively |
| `js_async_generator(g)` | A Jac async generator as JavaScript's own async generator, which JavaScript's `next`, `return` and `throw` drive ([above](#jacs-values-in-javascript)); anything else as it is |
| `js_error(e)` | What JavaScript threw that the Jac exception `e` is |
| `JsNull` | `null` |

```jac
import from js {
    js_add,
    js_band,
    js_bor,
    js_bxor,
    js_for_in,
    js_lt,
    js_method,
    js_mod,
    js_same,
    js_shl,
    js_shr,
    js_truthy,
    js_typeof,
    js_ushr,
}

with entry {
    print(js_add(1, "a"), js_add(2, 3), js_lt("10", "9"), js_lt(10, 9));
    print(js_truthy([]), js_truthy(""), js_typeof(None), js_same(0.0, -0.0));
    print(js_method([3, 1, 2], "join", "-"), list(js_for_in({"a": 1, "b": 2})));
    print(js_mod(-7, 2), js_mod(7.5, 2), js_shl(1, 33), js_shr(-8, 1), js_ushr(-1, 0));
    print(js_band("6", 3), js_bor(4, "3"), js_bxor(5, 1));
}
```

```output
1a 5 True False
True False undefined True
3-1-2 ['a', 'b']
-1 1.5 2 -4 4294967295
2 7 4
```

## A class with a JavaScript base

On a JavaScript host, a class whose base is a JavaScript class (a global such as `Error`, or one an
npm package exports) is made by JavaScript: it is a JavaScript `class ... extends`, and its objects
are JavaScript's, so `instanceof`, a stack trace and the base's own methods see what they expect.

- **Its `init` is the constructor**, and `super.init(...)` is `super(...)`, which makes the
  object. `init` calls it once, as a statement of its own body (E2253), and reads or sets `self`
  only after it (E2252): what an argument needs is worked out before it.
- **Its `has` fields are the object's**, its methods the class's, and the base's are inherited as
  JavaScript inherits them.
- **It derives from the JavaScript class alone** (E2251).
- **`js_new_target()`** of `js` is JavaScript's `new.target` where it is written: the class or
  function JavaScript called with `new`, and `None` where it was called without `new` or by Jac.
- A raised instance is the JavaScript exception, caught by its class as any Jac exception is.

<!-- example: not checked: runs in a node space -->
```jac
import from js { js_new_target }

class AppError(Error) {
    has code: int = 0;

    def init(m: str, code: int) {
        super.init(m);
        self.code = code;
        print("made by new:", js_new_target() is not None);
    }

    def describe -> str {
        return f"{self.message} ({self.code})";
    }
}

def plain -> any {
    return js_new_target();
}

with entry {
    e = AppError("bad", 7);
    print(e.describe(), isinstance(e, Error), plain());
    try {
        raise AppError("thrown", 2);
    } except Error as err {
        print("caught", err.message);
    }
}
```

```text
made by new: True
bad (7) True None
made by new: True
caught thrown
```

### A class over a value

On a JavaScript host a class's base may be a global of type `any`, as a JavaScript class
`extends` an expression: JavaScript makes the class over the value the global holds, a JavaScript
class or a function JavaScript constructs (a Jac function by its face, `self` the new object).
Such a class, and every class derived from it, is made where its statement runs, as Python makes
a class: in module code, in order with the module's other statements, so a class over a global
made after it is a `NameError`, as reading the global there is. A base of another type is E2312.
Natively a base is a class.

<!-- example: not checked: runs in a node space -->
```jac
glob Plain: any = globalThis.Set;

obj Tally(Plain) {
    def count -> int {
        return self.size;
    }
}

def counter(self: any, start: int) {
    self.n = start;
}

glob Counter: any = counter;

obj Up(Counter) {
    def twice -> int {
        return self.n * 2;
    }
}

with entry {
    t = Tally();
    t.add(1);
    t.add(2);
    t.add(2);
    u = Up(4);
    print(t.count(), isinstance(t, Plain), u.twice(), isinstance(u, Counter));
}
```

```text
2 True 8 True
```

## Exceptions

A JavaScript exception reaching Jac is a `TypeError` for a `TypeError`, a `ValueError` for a
`RangeError`, and a `RuntimeError`, its message prefixed with the error's name, for anything else.
`js_error(e)` is what was thrown, a `JsObject` whose `.name`, `.code` and other properties read as
in JavaScript, or `None` for an exception that did not come from JavaScript. A Jac exception thrown
into JavaScript is a `TypeError`, a `RangeError` (for a `ValueError`) or an `Error` named after its
class, with its message; it is the same Jac exception again if it comes back.

```jac
import from js { js_error }
import from "node:vm" { runInThisContext }

with entry {
    for src in [
        "null.x",
        "new Array(-1)",
        "(() => { const e = new Error('nope'); e.code = 'E_NOPE'; throw e; })()",
    ] {
        try {
            runInThisContext(src);
        } except Exception as e {
            print(type(e).__name__, "|", e, "|", js_error(e).name);
        }
    }
    try {
        runInThisContext("(() => { const e = new Error('x'); e.code = 'ENOENT'; throw e; })()");
    } except RuntimeError as e {
        print(js_error(e).code);
    }
    catcher = runInThisContext(
        "(f) => { try { f(); } catch (e) { return e.constructor.name + ': ' + e.message; } }"
    );
    print(catcher(lambda (*rest: any) -> any { raise ValueError("bad value"); }));
    try {
        runInThisContext("({})").missing;
    } except AttributeError as e {
        print("AttributeError:", e);
    }
    try {
        runInThisContext("(x) => x")(2 ** 53 + 1);
    } except OverflowError as e {
        print("OverflowError");
    }
}
```

```output
TypeError | Cannot read properties of null (reading 'x') | TypeError
ValueError | Invalid array length | RangeError
RuntimeError | Error: nope | Error
ENOENT
RangeError: bad value
AttributeError: 'Object' object has no attribute 'missing'
OverflowError
```

## Node's loop

Node's event loop runs as it does in `node`:

- The program's code between two waits is one task of the loop. What its calls queue (promise
  reactions, `process.nextTick` callbacks) runs when it waits or ends.
- `await` of a `JsObject` that is a promise, in an async function, runs the loop until the promise
  settles, and gives its value or raises its rejection. Waiting inside a Jac function that
  JavaScript called is a `RuntimeError`: the loop cannot run there.
- A rejection no handler took is reported as Node reports it, and ends the program.
- When the entry code ends normally, the loop runs out: timers and callbacks still pending run,
  then `beforeExit` and `exit`, as Node's main ends.
- `sys.exit()` and an uncaught Jac exception end the program as `process.exit()` does: `exit`
  handlers run, the loop does not. An uncaught JavaScript exception, and `process.exit()` called
  from JavaScript, end it as they end Node.
- Node is used from the thread that started it. A call from another thread is a `RuntimeError`.

```jac
import from "node:events" { EventEmitter }
import from "node:timers" { setTimeout }

with entry {
    ee = EventEmitter.new();
    seen: list[any] = [];
    cb = lambda (*args: any) -> any {
        seen.append(args[0]);
        return None;
    };
    ee.on("tick", cb);
    ee.emit("tick", 7);
    ee.off("tick", cb);
    ee.emit("tick", 9);
    print(seen, ee.listenerCount("tick"));
    setTimeout(lambda -> None { print("timer fired") }, 5);
    print("end of entry");
}
```

```output
[7] 0
end of entry
timer fired
```

## neojac node, npm and npx

`neojac node` runs Node 26 with its own command line, and `neojac npm` and `neojac npx` run the npm
it ships:

```sh
neojac node -e 'console.log(process.version)'
neojac node app.ts                 # TypeScript's types stripped, as Node does
neojac npm ls
neojac npx tsc --version
```

- Node is built from source by neojac, and neojac carries it once, as the libraries a Jac program
  that imports from npm links: its own C++ and libuv compiled by neojac, V8, ICU with every
  locale's data, and the OpenSSL, zlib, Zstandard, SQLite and libffi the toolchain also gives
  CPython. neojac runs it as a part of itself, in its own process: the first time Node is needed,
  it links those libraries into a shared library in its cache, says `building this neojac's Node`,
  and loads it ([The build cache](../toolchain/cache.md#what-neojac-writes-out-of-itself)). Its
  built-in modules are all there, `node:worker_threads`,
  `node:zlib`'s Brotli and `node:sqlite`'s sessions among them, and so is `Temporal` (dates,
  durations, time zones' rules and other calendars).
- `node` is a name in the cache that links back to neojac (`2/names/<id>/node/node`, alone in its directory), which started
  by that name is that Node; it is the path `process.execPath` names, by which npm and
  `child_process` start Node again. `neojac node`, `npm` and `npx` put its directory
  first on `PATH`, so a script npm runs finds `node` there.
- npm is the one Node ships, which neojac carries (`lib/node/npm/`) and writes out in its cache the
  first time it is run. In a Jac project, `neojac npm`
  and `neojac npx` run in an npm tree of `jac.toml`, in its directory, and `jac.toml` and `jac.lock`
  take what they wrote there ([Packages](../toolchain/packages.md#running-npm)). Where there is no
  `jac.toml`, they are npm as it is anywhere.
- Node exports Node-API, Node's C++ API, V8's and libuv's (what their headers mark for export), as
  Node's own Windows build does. So the native addons packages ship load as they do on Node:
  Node-API addons, and V8 addons built against the same C++ library, libc++. Their headers are
  neojac's `lib/node/include/node/`, which a C module's table names `{lib}/node/include/node` and
  which neojac's own compilers read in its cache, beside the pages `neojac docs --path` names,
  whether or not they have been written out there; build one with
  [`neojac cc`](c-and-cpp.md) (`-shared -fPIC` on Linux,
  `-bundle -undefined dynamic_lookup` on macOS). An addon of Node's C++ API and V8's (`node.h`,
  `v8.h`) builds with `neojac c++` as node-gyp builds one: in C++20, with the module's name
  defined.
- A project's own addon is a C module's: `neojac absorb --record` writes its table from its
  node-gyp build, and neojac builds it from then on ([Recording a
  build](../toolchain/packages.md#recording-a-build)). `neojac port` takes its C++ to Jac, native
  code that the C module holds and no npm tree's space takes, and the addon is then built from
  that Jac with the C that stays, exporting Node-API's entry points
  ([port](../toolchain/port.md#in-a-project)). Built from the Jac, it builds for any target:
  `neojac build package.json --target linux-aarch64` makes the tree's addons for that platform
  from macOS, where an addon still built from C and C++ is built only on the system it is for
  (E5090).
- An addon neojac builds defines Node-API's entry, `napi_register_module_v1` (`NAPI_MODULE_INIT`
  defines it). One that registers itself from a static constructor instead, as V8's
  `NODE_MODULE`, NAN and older Node-API headers make one, is refused by name (E5090): neojac does
  not build that form yet.
- A C library a package vendors (`deps/sqlite3`, a C module of its own) is linked into the addon
  by the addon's row, `links = ["deps/sqlite3"]`, which the record writes, and never left to
  Node: Node exports libuv's functions, and an addon that left a vendored copy of one of them
  undefined would run on Node's. A build that leaves such a symbol undefined is refused (E5270)
  ([Extension modules](../toolchain/packages.md#extension-modules)).
- The vendored library is the one the addon calls, on every system: an addon exports Node-API's
  two entry points and nothing else, and every other function in it is local to it, so a call of
  a vendored `uv_version` reaches the vendored one, where on Linux it would otherwise reach
  Node's. A name another library must find in it goes in the row's `exports`, which then are all
  it exports: a SQLite loadable extension in the tree gives `sqlite3_extension_init`.

```sh
neojac c++ -std=c++20 -DNODE_GYP_MODULE_NAME=hello -bundle -undefined dynamic_lookup \
    -I "$(dirname "$(neojac docs --path)")/lib/node/include/node" hello.cc -o hello.node
neojac node -e 'console.log(require("./hello.node").hello(14))'
```

## Platforms and size

neojac carries Node for Linux (x86_64 and arm64) and macOS on Apple silicon. On Windows,
`neojac node` says that neojac carries no Node. A program can import JavaScript only when it is built
for the platform neojac runs on, with that platform's Node; a build for another platform refuses
each such import (E5090).

A program that imports JavaScript links Node, so it is large: over 100 MB.

## What is rejected

| Code | Condition |
|---|---|
| E1145 | A name the package's declarations don't export |
| W1100 | A package that is not installed, or not among the packages of the tree the import resolves in: `cannot find module` |
| E1287, E1288 | The module's space names a tree `jac.toml` does not declare, or none of several |
| E5160 | The tree's packages are not installed as `jac.toml` and `jac.lock` say |
| E5090 | A JavaScript import in a build for a platform without the toolchain's Node; an addon that registers itself from a static constructor; an addon built from its C and C++ for another system than this one |

As the program runs: `ImportError` for an export an undeclared package or a built-in module
lacks, `AttributeError` for a property an object lacks, `OverflowError` for an int past 2**53 sent
to JavaScript.

## Differences from Python and from the reference design

- Pyodide's `JsProxy` is the nearest thing in Python. As there, a missing property is an
  `AttributeError` rather than `undefined`, and `C.new(...)` is `new C(...)`.
- `import from "lodash" { chunk }` fails for a CommonJS package whose exports Node cannot list,
  exactly as `import { chunk } from "lodash"` fails in an ES module on Node: import its `default`.
- `str()` of a `JsObject` is JavaScript's `String()` of it: an array prints as `1,2,3`. Convert it
  to a Jac value first (`xs: list[int] = arr`) to print it as a list.
