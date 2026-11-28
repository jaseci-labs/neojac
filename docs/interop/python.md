---
description: Using CPython's standard library and PyPI packages from a native Jac program - how an import reaches Python, how it is checked, neojac install and remove, neojac python, C extensions, and sys.monitoring.
keywords: Python, CPython, PyPI, dependencies.pypi, .jac/venv, C extension, sys.monitoring, --monitor, python3.15
---
# Python

A native Jac program imports a Python module as it imports a Jac one. The module runs on CPython
3.15, which neojac carries and links into the program, and what it gives are Python objects the
Jac code uses directly.

```jac
import ast;
import pickle;

with entry {
    (name, port) = ast.literal_eval("('demo', 8080)");
    print(name, port + 1, type(name).__name__);
    data = pickle.dumps({"name": name, "port": port});
    back = pickle.loads(data);
    print(back["port"] + 1, len(back), type(back).__name__);
}
```

```output
demo 8081 str
8081 2 dict
```

`ast` and `pickle` are CPython's modules: neojac's native standard library has neither. Nothing
else is needed: no virtual environment, no Python installed on the machine.

## Which imports are Python

An import names a Python module when it names no module of the project, of neojac's runtime or of
the native standard library, and CPython has a module of that top-level name: one of its standard
library, or a package installed in the project's `.jac/venv` (below). The order is in
[the library's index](../library/index.md) (`neojac docs library`).

- `json`, `re`, `os`, `datetime`, `heapq` and the other native modules are always the native ones.
  `importlib.import_module("heapq")` reaches CPython's when that is what you want.
- A package that exists natively is native or missing as a whole: a module or name it leaves out
  is refused (E5143, E5142) with the `importlib.import_module` call that reaches CPython's.
- `import from numpy.random { default_rng }` reads `default_rng` as Python's `from ... import`
  does: the attribute of that name, or else the submodule.
- The program starts the interpreter the first time it imports a Python module. A program that
  imports none has no CPython in it.

## How values cross

What Python gives is a `PyObject`, which Jac code uses as Python would and which becomes a Jac value
where a Jac type is wanted. It is not a type a program writes, and neither is a Python class: a
variable or a signature holding one declares `any`, or the Jac type it converts to. A Jac value passed to Python becomes the Python value it stands for: a
`list` is shared, a `dict` copied, a Jac object an instance of a Python class of its own. Python's
exceptions are Jac's and Jac's Python's, and a Jac class may derive from a Python class. All of it,
with examples, is in [Python values](python-values.md) (`neojac docs PyObject`).

## Checking

A Python module's names and signatures come from its stubs: a `<package>-stubs` distribution, the
package's `.pyi` files, or a `py.typed` package's annotations, in that order, and typeshed's for
CPython's standard library. Where the stubs declare everything a module or class has, a name it
lacks is a compile error, and so is a call its signature does not bind. The type of what an
attribute or a call gives follows from the stubs, so a chain (`np.linalg.inv(a).sum()`) is checked
through. A module with no stubs is dynamic and checks nothing. A name the stubs declare only
under another platform's `sys.platform` branch (`os.pidfd_open`, Linux's; `signal.CTRL_C_EVENT`,
Windows's) is read where it runs, as a Python object: where the platform lacks it, it is Python's
`AttributeError` there, so code that tests the platform first runs on every one. A name declared
only for another Python version is still E1030.

```jac
# expect: E1030, E1052, E1051, E1050, E1001
import ast;

with entry {
    print(ast.pars("1 + 2"));
    tree = ast.parse("1 + 2");
    print(ast.dump(tree, indnt=2));
    v = ast.NodeVisitor();
    v.visit(tree, 1);
    print(v.visit());
    count: int = ast.unparse(tree);
    print(count);
}
```

A local bound twice to values of different types holds no one type, so its uses are not checked
against either.

## PyPI packages

A project's PyPI packages are its `jac.toml`'s `[dependencies.pypi]`, each a name and a version
specifier. `neojac install` installs them into the project's own virtual environment, `.jac/venv`,
with the pip CPython bundles, and records the exact versions in `jac.lock`:

```sh
neojac install --pypi numpy     # add numpy, held to ~=X.Y of the version pip picks, and install
neojac install                  # install what jac.toml lists
neojac install --frozen         # install exactly what jac.lock pins
neojac remove --pypi numpy      # drop numpy, and what only it needed
```

```toml
[dependencies.pypi]
numpy = "~=2.5"
tabulate = "~=0.10"
```

`jac.lock` lists every distribution the install resolved, dependencies included, and a hash of
what they were resolved for. An install whose `jac.toml` still lists what the lock
was made for installs the lock's versions; otherwise it resolves again and rewrites the lock. An
install also removes from `.jac/venv` what the lock no longer lists. Commit both files.

- **Resolving again keeps the versions the lock pins.** Adding or removing one package leaves
  every other at its version. Where a pin no longer fits what is asked for, pip resolves all of
  them afresh, and the install says so.
- **A package named to `neojac install --pypi` is asked for anew:** it gets the newest version
  that fits, which is how one package is moved up.
- **A `uv.lock` beside a Python project of the repository is what pip is held to,** until it is
  reproduced or removed ([A lock another tool wrote](../toolchain/packages.md#a-lock-another-tool-wrote)).

The project's Jac programs then import the packages:

`main.jac`, in a project whose `jac.toml` lists numpy:

<!-- example: not checked: needs numpy installed in the project's .jac/venv -->
```jac
import numpy as np;
import from numpy.random { default_rng }

with entry {
    a = np.arange(12).reshape(3, 4);
    print(a.sum(), np.linalg.norm(a), default_rng(42).integers(0, 10, size=5));
    total: int = a.sum();
    print(total + 1);
}
```

```text
66 22.494443758403985 [0 7 6 4 4]
67
```

| Message | Cause |
|---|---|
| `install: no jac.toml in this directory or above` | Run it inside a project |
| `'./helpers' is not a PyPI package's name` | `--pypi` was given something other than a package's name, with a version specifier or without: a directory or an archive, which `jac.lock` could not pin |
| `jac.toml: <what TOML says is wrong>` | `jac.toml` is not valid TOML |
| `install --frozen: there is no jac.lock; run neojac install` | `--frozen` needs a lock |
| `install --frozen: jac.lock was not made for jac.toml's [dependencies.pypi], its packages' and its Python projects'; run neojac install` | `jac.toml` changed since the lock was written |
| `remove: jac.toml's [dependencies.pypi] has no <name>` | The package is not listed |
| pip's own errors, then `install: pip cannot resolve the project's PyPI packages` | pip found no distribution that satisfies a listed requirement; the install exits with status 1 |
| pip's own errors, then `install: pip cannot read what the project's Python projects depend on` | A Python project's build backend failed as pip asked it for its metadata |
| `install: <name> is asked for at <address>: jac.lock pins a package by its version on an index, by a revision of a repository or by an archive's digest, and this has none` | A requirement names a directory |

### A Python project of the repository

A repository that holds a Python project has its `pyproject.toml` as a table of `jac.toml`,
`[pypi."<directory>"]` ([Packages](../toolchain/packages.md#rust-crates-c-modules-and-python-projects)).
`neojac install` installs what each one depends on into the same `.jac/venv`, resolved together
with `[dependencies.pypi]` and pinned in the same `[pypi]` of `jac.lock`:

```toml
[pypi.backend.project]
name = "app"
version = "0.1.0"
dependencies = ["fastapi[standard]>=0.141", "httpx<1.0.0,>=0.25.1"]

[dependencies.pypi]
pytest = "~=9.0"                # the project's own list, beside it
```

- **What a project depends on is its `[project]` table's `dependencies`**, as written:
  specifiers, extras and markers are pip's to read.
- **Where its build says so instead** (`dynamic = ["dependencies"]`, or a `setup.py` and no
  `[project]` table), pip asks the project's build backend for its metadata, as
  `pip install <directory>` does. That runs the backend, which pip fetches what it requires for,
  and such a project is asked again by every `neojac install` that is not `--frozen`.
- **A dependency on another Python project of the repository** (a workspace's member) is that
  project, and is asked of no index.
- **The project itself is not installed**: its modules are the repository's source. A project
  `neojac absorb --record` recorded is asked for its requirements by its `[wheel]` table's
  metadata, and install builds nothing of it.
- **Its extension modules call the C libraries they vendor.** One neojac builds from a C module
  links the C modules its row's `links` names, and exports `PyInit_<name>` and nothing else, so
  each of its calls reaches its own copy of a function the interpreter also exports. A name
  another library must find in it by name, as `ctypes` finds a function of a library the package
  opens, goes in the row's `exports`
  ([Extension modules](../toolchain/packages.md#extension-modules)).
- **Its dependency groups and its extras are installed where `jac.toml` names them**:
  `[install.pypi."<directory>"]`'s `groups` and `extras`, which `absorb` writes from what uv
  installs by default for a project uv describes, then `[test.pypi."<directory>"]`'s
  ([Packages](../toolchain/packages.md#building-and-testing-a-python-project)), a group with the
  groups it includes. No other group or extra is installed. What a project's tools need that no
  group lists is added with `neojac install --pypi <package>`.
- **A package asked for at an address** (`name @ git+https://...`, `name @ https://.../x.whl`)
  is pinned by what was fetched from it: a repository's commit, an archive's digest.

  ```toml
  [pypi]
  resolved = ["psleak @ git+https://github.com/giampaolo/psleak@c60c155c23f1bf98991d4cf588d4f465c02bed2f", "pytest==9.2.0"]
  ```

pip's own environment variables apply to an install, so a project installs from wheels in a
directory of its own with `PIP_NO_INDEX=1 PIP_FIND_LINKS=wheels neojac install`. A package that is
listed but not installed is `W1100` (cannot find module) where it is imported.

## The interpreter

`neojac python` runs CPython 3.15's own command line, with its standard library:

```sh
neojac python -c 'import sys; print(sys.version)'
neojac python -m venv .venv
```

Run in a project that has a virtual environment (`.jac/venv`, which `neojac install` makes), it
is that environment's Python: `sys.prefix` is the project's `.jac/venv`, and the project's packages
import. The project is the one the current directory is in. Anywhere else it is the toolchain's
Python.

CPython is built from source by neojac, and neojac carries it once, as the library a Jac program
using Python links. neojac runs it as a part of itself, in its own process: the first time Python
is needed (`neojac python`, an install, a build that reads a package), it links that library into
a shared library in its cache, says `building this neojac's CPython`, and loads it
([The build cache](../toolchain/cache.md#what-neojac-writes-out-of-itself)). `python3.15` is a name
in the cache, a small program that becomes neojac, which started through it is that Python.

| In the cache | What it is |
|---|---|
| `2/names/<id>/python/python3.15` | A small program that becomes neojac, which started through it, or through a virtual environment's `python`, is that Python. It is a file of its own, so the real path of `sys.executable` is still a Python. On Windows, a launcher that runs it |
| `linked/<id>/` | CPython as the shared library neojac loads into its own process, built of the library below |
| `store/<id>/lib/cpython/lib/python3.15/` | The standard library, written out of neojac |
| `store/<id>/lib/cpython/include/python3.15/` (`Include/` on Windows) | The headers a C extension builds against |
| `store/<id>/lib/cpython/typeshed/` | typeshed's stubs of the standard library, which checking reads |
| `store/<id>/lib/cpython/<platform>/` | The interpreter as a library, which a Jac program using Python links (`python315.dll` on Windows) |

The interpreter is told by its file, as CPython's own program is. Run by its path, as
`neojac python`, as a virtual environment's `python`, as `python3` found on `PATH`, or through a
link of any name, its `sys.executable` is the path it was run by, its `sys.prefix` (the same as
`sys.exec_prefix`) is its virtual environment or else that `lib/cpython`, and its `sys.base_prefix`
is that `lib/cpython`. A file `<name>._pth` beside it, named for the name it is run by
(`python3.15._pth` beside `python3.15`), is the whole of `sys.path`, as in CPython.

A virtual environment made with it (`neojac python -m venv`, or the project's `.jac/venv`) is a
standard one: its `bin/python` (`Scripts\python.exe` on Windows) runs that environment, and
`bin/pip` installs into it. One made with `--copies` holds a copy of neojac under that name, and is that environment's Python all
the same: its `pyvenv.cfg`'s `home` names the name's directory in the cache. When the cache has been
deleted, the next neojac command in the project that needs Python makes the name again, where it
was.

In a virtual environment, `sysconfig`'s compilers are the toolchain's own: `CC`, `LDSHARED`,
`BLDSHARED` and `LINKCC` are `neojac cc`, `CXX` and `LDCXXSHARED` are `neojac c++`, and `AR` is
`neojac ar`. So pip builds a package's C extensions from source with neojac's Clang, and needs no
compiler on the machine. The `neojac` is the one `NEOJAC_EXE` names, which a neojac that starts
Python sets to itself; with it unset, the one `PATH` finds
([Environment variables](../reference/environment.md)).

The interpreter exports CPython's C API and none of the C libraries compiled into it (OpenSSL,
zlib, SQLite, libffi, ...). So C extension modules, wheels' among them, load as they do on
CPython's own builds, and a wheel that bundles its own copy of such a library binds its own. To
build one by hand, compile against the headers `sysconfig` names with [`neojac cc`](c-and-cpp.md), link it
as CPython's `LDSHARED` does, and name it with the interpreter's tag
(`sysconfig.get_config_var("SOABI")`):

| Platform | Linked with | File |
|---|---|---|
| Linux | `-shared -fPIC` | `spam.cpython-315-x86_64-linux-gnu.so` (`aarch64` on arm64) |
| macOS | `-bundle -undefined dynamic_lookup` | `spam.cpython-315-darwin.so`, a Mach-O bundle |
| Windows | `-shared -L <the interpreter's directory> -lpython315` | `spam.cp315-win_amd64.pyd`, a DLL importing the C API from `python315.dll` through the import library beside the interpreter |

```sh
include="$(neojac python -c 'import sysconfig; print(sysconfig.get_path("include"))')"
neojac cc -bundle -undefined dynamic_lookup -I "$include" spam.c -o spam.cpython-315-darwin.so
neojac python -c 'import sys; sys.path.insert(0, "."); import spam; print(spam.twice(21))'
```

With `-target`, `neojac cc` builds another platform's extension from any machine.

### What a program using Python carries

- The interpreter is linked into the program. A program built with `neojac build main.jac`
  reads the standard library where neojac wrote it out in its cache, and packages from the
  project's `.jac/venv`, at the paths they had when it was built. With the cache deleted it finds
  no standard library until a neojac command that needs Python has written it out again; an app's
  build carries its own (next).
- An app whose native space imports CPython's standard library ships it: `neojac build` writes the
  program with a `lib/` of its own beside it (`dist/<app>-<platform>/`), and the directory runs
  wherever it is moved, with no toolchain. See [Apps](../apps/index.md) (`neojac docs apps`).
- The interpreter reads CPython's environment variables as `python3` does: with
  `PYTHONMALLOC=debug` the program's Python runs under CPython's debug allocator.
- A build for Windows writes `python315.dll` beside the program.
- A build for another platform links that platform's interpreter and C libraries. neojac carries
  its own platform's, and reads another's out of that platform's neojac, which it fetches from the
  same release the first time a build names the platform.
- `wasm32-wasi` takes no Python (E5090).

## Profilers and coverage: `sys.monitoring`

A program built with `--monitor` makes its Jac functions and module code fire the events of
Python's `sys.monitoring` (`PY_START`, `LINE`, `PY_RETURN`, and `PY_RESUME` and `PY_YIELD` for
generators and coroutines) while a tool listens, as Python code fires them. That is what `cProfile`
and coverage.py's monitoring core read. Without `--monitor`, Jac code fires nothing and runs at
full speed.

```jac
import importlib;

glob seen: list[str] = [];

def on_line(code: any, line: int) {
    if code.co_filename.endswith(".jac") {
        seen.append(code.co_name + ":" + str(line));
    }
}

def traced(x: int) -> int {
    y = x + 1;
    return y * 2;
}

with entry {
    mon = importlib.import_module("sys").monitoring;
    mon.use_tool_id(4, "docs");
    mon.register_callback(4, mon.events.LINE, on_line);
    mon.set_events(4, mon.events.LINE);
    traced(2);
    mon.set_events(4, 0);
    mon.free_tool_id(4);
    print(len(seen) > 0);
}
```

Built with `neojac build main.jac -o main --monitor`, it prints `True`; built without, `False`.

- A `LINE` event fires once per statement, where CPython fires one per source line.
- A Jac function that is a tool's callback fires nothing while it runs, as Python code doesn't.
- There are no `BRANCH_*`, `CALL`, `C_RETURN`, `RAISE` or `EXCEPTION_HANDLED` events from Jac
  code, so coverage.py's branch mode sees no branches.

## What is rejected

```jac
# expect: E5143, W1100
import json.tool;
import notamodule;

with entry {
    print(notamodule);
}
```

| Code | Condition |
|---|---|
| W1100 | No module of that name: not the project's, not native, not CPython's, not installed in `.jac/venv` |
| E5142 | A name a native module leaves out on purpose (`collections.namedtuple`); the message says what to write instead |
| E5143 | A module of a package that exists natively but lacks it (`json.tool`) |
| E1030 | A name the stubs say a module, class or object has not |
| E1050, E1051, E1052 | A call the stubs' signature does not bind: an argument missing, too many, an unknown keyword |
| E1001 | A value whose stubbed type is not the type wanted |
| E2191 | A class deriving from a Python class and from something else |
| E5090 | Python on `wasm32-wasi` |

## Differences from Python and from the reference design

- In Python, `json` and `re` are CPython's modules. Here they are neojac's native ones, and a
  Python module is reached only where no native module of the name exists, or through
  `importlib.import_module`.
- A Python module's misuse is a compile error where its stubs make it one; in Python it is an
  `AttributeError` or `TypeError` as the program runs.
- In the reference design, a program runs on CPython throughout. Here only the Python modules run on CPython; the
  program is native code.
