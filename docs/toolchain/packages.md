---
description: A project's packages and manifests from every ecosystem in jac.toml and jac.lock - Jac packages ([packages]), libraries and plugins alike, by a version, a directory or a repository, the installed packages of eco/jac and what a version requirement means, what a library is and what it may not hold, npm trees ([npm."<dir>"]), each the package.json of its directory, written where it stands, Rust crates ([cargo."<dir>"]), C modules ([c."<dir>"]) and Python projects ([pypi."<dir>"]) written where they stand, PyPI packages, neojac install, remove, absorb, npm and cargo, what is tracked, and what is refused.
keywords: packages, [packages], libraries, Jac library, Jac package, version, version requirement, installed package, jac.lock, eco, eco/jac, npm tree, package.json, package-lock.json, node_modules, install, remove, absorb, frozen, Cargo.lock
---
# Packages

A project says which packages it takes, from every ecosystem, in `jac.toml`, and `jac.lock` records
exactly what was installed. The files another ecosystem's tools read (`package.json`,
`package-lock.json`) are not written by hand and not tracked: neojac writes them from `jac.toml`
and `jac.lock` before it runs a tool, and takes back what the tool changed as it ends.

| Ecosystem | In `jac.toml` | In `jac.lock` | Installed in |
|---|---|---|---|
| Jac | `[packages]`, each package by its version or by where it is | `[jac.<name>]`, for each installed one, whoever installed it | `eco/jac/<name>`, for one declared by a version or a repository |
| npm | `[npm."<directory>"]`, one for each tree of packages | `[npm."<directory>"]` | `<directory>/node_modules` |
| PyPI | `[dependencies.pypi]`, and what each Python project below depends on | `[pypi]` | `.jac/venv` ([Python](../interop/python.md#pypi-packages)) |
| Rust | `[cargo."<directory>"]`, a crate's or a workspace's `Cargo.toml` | `[cargo."<directory>"]`, its `Cargo.lock` | nothing: cargo builds from the crate's directory |
| C and C++ | `[c."<directory>"]`, a C module's `cmodule.toml` | | nothing |
| A Python project | `[pypi."<directory>"]`, its `pyproject.toml`, with `[wheel."<directory>"]` and `[test.pypi."<directory>"]` | | nothing of its own: what it depends on is in `.jac/venv` |

```sh
neojac install                        # everything jac.toml lists
neojac install --frozen               # exactly what jac.lock pins, as on a fresh clone
```

## Jac packages

A Jac package is a directory with a `jac.toml` and its modules. It is one of two kinds, which its
own `jac.toml` says, and never both ([Principles](../language/principles.md)):

| | Library | Plugin |
|---|---|---|
| Its `jac.toml` says | `kind = "library"` | `kind = "plugin"`, and what it fills ([Plugins](../apps/plugins.md#writing-a-plugin)) |
| It is declared in `[packages]` by | Each package whose modules import it | The project that binds it, and no other package |
| It is named by | A module's `import` | A binding in `jac.toml`, never an import |
| It may declare | Libraries | Libraries |

A package declares each package it uses in its `[packages]`: by its version, a string, or by
where it is, a table that names a directory or a repository at a revision. The table does not say
which kind a package is: the package's own `jac.toml` does.

```toml
[project]
name = "shop"

[packages]
grid = "1.2"
shapes = { path = "../shapes" }
units = { git = "https://example.com/units.git", rev = "v1.2.0" }
```

| A declaration | Means | The package is |
|---|---|---|
| `"1.2"` | Version 1.2.0 or later, below 2.0.0 ([Versions](#versions)) | [Installed](#installed-packages) in the project's `eco/jac/<name>` |
| `{ path = "..." }` | The package in that directory, from the directory of this `jac.toml` | Used where it is |
| `{ git = "...", rev = "..." }` | The package at that revision of a repository | [Fetched](#fetching-and-pinning) by `neojac install` into `eco/jac/<name>` |

and its modules import the library's under its name:

<!-- example: not checked: needs the library beside the project -->
```jac
import shapes;
import from shapes.area { square }

with entry {
    print(square(3), shapes.NAME);
}
```

The library is a project like any other, published as it stands:

```toml
# ../shapes/jac.toml
[project]
name = "shapes"
kind = "library"
version = "0.1.0"

[packages]
units = { git = "https://example.com/units.git", rev = "v1.2.0" }

[dependencies.pypi]
numpy = ">=2"
```

- **A package's `version` is three numbers,** `MAJOR.MINOR.PATCH`, as
  [Semantic Versioning](https://semver.org) has it, with an optional pre-release (`1.3.0-rc.1`).
  One that is written and is not that is E2228.
- **A package may say the oldest neojac it builds with,** `neojac = "0.4"` in its `[project]`.
  It is a least version and no more: no author knows which later neojac will break a package. A
  release of neojac older than that refuses the package where it says so (E2229). A neojac built
  from source is no release, and refuses none.
- **`shapes.area` is `area.jac` in the library's directory,** and `import shapes;` its
  `__init__.jac`. Inside the library, its modules import each other as a project's do: by the
  wires of the library's own `archwire.jac`.
- **A module imports the libraries its own package declares.** `shapes` uses `units`, so `shapes`
  declares it. A module of the project that imports `units` is E2219 until the project declares it
  too: what a dependency brought is not the project's to use by accident.
- **A program holds one copy of a package.** Where the project declares `units`, the copy is the
  one the project names, and otherwise the one the first package to declare it names. Every other
  declaration of `units` has to hold of that copy, or the build is refused (E2220): a version
  requirement of its version, and a place by being the same directory, however it is written. A
  path relative to the package that declares it, an absolute one and one through a link that name
  one directory are one place, and the copy is read where it was first reached. A class belongs to
  its module, so two copies would be two types.
- **A library depends on no plugin.** Its `[packages]` declares none and its `jac.toml` binds no
  abstraction (E2221), and none of its modules imports one (E2218). It uses the language's
  abstractions (`root`, `by llm()`), and the project that uses it says what carries them out. The
  one binding it makes is of its own browser space's `ui`, to a plugin neojac ships.
- **A library may hold pages: browser spaces its own `archwire.jac` declares**, each served at the
  `base` its `jac.toml` gives it. Every app whose program loads a module of the library builds
  them into the project's `.jac/build/` and carries them inside its program, as it carries the
  library's code, and serves them; no app names them
  ([A package's browser spaces](../apps/archwire.md#a-packages-browser-spaces)). stdjac's sign-in
  pages are such a space.
- **A library's name is its own.** A directory or a module of the project named as a declared
  library is E2222: an import would name either.
- **A plugin declares libraries the same way,** in its own `[packages]`, and no plugin: only a
  project declares one (E2221), and a plugin it declares is one it binds or lists (E2227,
  [Plugins](../apps/plugins.md#binding-a-plugin)).
- **A plugin's modules import its abstraction's contract, `common.contract`, the libraries it
  declares and the standard library,** and nothing else of neojac's: no module of stdjac, and no
  other abstraction's contract (E2233). A library a plugin declares is held to the same: it
  imports `common.contract` and the contract of the abstraction that plugin fills
  ([Plugins](../apps/plugins.md#what-a-plugin-imports)). neojac's own libraries are such
  libraries, each declared by its place in neojac's tree: `sqlfile`, which its `sqlite` and
  `accounts` plugins declare, and `accountbook`, which `accounts` does.
- **No package declares an abstraction** (E2217). The abstractions are neojac's own, each a directory
  of its `abstractions/` ([Plugins](../apps/plugins.md#the-abstractions)).
- **`[libraries]` and `[plugins]` are no tables of a `jac.toml`** (E2226): a package's packages
  are in `[packages]`.

### Versions

- **A requirement is the least version asked for:** `"1"`, `"1.2"` or `"1.2.3"`. It is satisfied
  by that version and every later one in which its left-most number that is not zero is
  unchanged:

  | Requirement | Satisfied by |
  |---|---|
  | `"1.2"`, `"1.2.0"` | 1.2.0 or later, below 2.0.0 |
  | `"1"` | 1.0.0 or later, below 2.0.0 |
  | `"0.4"` | 0.4.0 or later, below 0.5.0 |
  | `"0.0.3"` | 0.0.3 alone |

- **There is no other form:** no range, no exact version, no exclusion (E2228). An exact version
  is what a lock pins. A release that breaks its users and has to live beside the one before it
  takes a new name (`shapes2`), since a program holds one copy of a name.
- **A pre-release** (`1.3.0-rc.1`) satisfies only a requirement that names a pre-release of the
  same version (`"1.3.0-rc.1"`).
- **A package asked for by version states one.** One whose `jac.toml` has no `version` satisfies
  no requirement.

neojac says what a version and a requirement are because the compiler checks one against the
other. It does not choose a version: that is a package manager's work.

### Installed packages

A package declared by its version is an installed one. The compiler finds it in the project's
`eco/jac/<name>`, a directory holding the package's files with its `jac.toml` at the top, and
does not ask how it came to be there: a package manager is a program of its own, which puts
packages in that directory ([Writing a package manager](package-managers.md)).

- **The directory is the project's:** the one being built. A package's own requirements are found
  there too, never in the package's directory. So one directory holds one version of each name,
  libraries and plugins alike.
- **It may be a link** to a directory a package manager keeps elsewhere. The compiler reads
  through it, and writes nothing in it.
- **Beside it is a record of what installed it,** `eco/jac/<name>.json`:

  ```json
  { "format": 1, "installer": "jacpm", "from": { "registry": "https://packages.example.org" } }
  ```

  `installer` is the name of the program that put the package there, `from` is that program's
  own, which neojac does not read, and `format` is the record's format, 1. An installed package
  with no record is refused (E5163), and so is a record of another format (E5164): a package
  someone keeps by hand is declared by `path`.
- **An installer touches only the packages whose record names it.** `neojac install` leaves
  another's packages and records as they are, and does not fetch over one (E5165).
- **Nothing is machine-wide:** no directory outside the project is searched, and no environment
  variable adds one.
- **What is not there is said where it was asked for** (E5161), with what was asked and by which
  package, and so is a copy whose version does not satisfy a declaration (E2220).
- **A project builds against its own checkout of a package** by declaring it by `path`. The
  project's declaration decides the copy the whole program holds, so an installed package that
  asks for `units = "0.3"` uses the project's `units = { path = "../units" }`, whose version has
  to satisfy that.

### Fetching and pinning

A package declared by its directory is used where it is. One declared by a repository is fetched by
`neojac install`:

```text
$ neojac install
neojac install: the library units at 6c8f55b32d8a in eco/jac/units
```

- **It is fetched into `eco/jac/<name>`,** which is not tracked: `neojac install` adds `eco/jac/`
  to the project's `.gitignore`. neojac is the installer of what it fetches, and records it as
  any installer does: `eco/jac/<name>.json` names `neojac`, and its `from` holds the repository,
  the revision asked for and the commit. A build that finds it missing, or fetched for another `git` or
  `rev` than `jac.toml` now has, is E5161, and `neojac install` is the fix.
- **`jac.lock` pins the commit,** as it pins every installed package ([below](#the-lock)). A `rev`
  that is a branch is pinned at the commit it named when it was first fetched, and stays there
  until `jac.toml` asks for another `rev`.
- **`neojac install --frozen`** fetches exactly the commits `jac.lock` pins, and fails for a package
  it pins nothing for, or whose files are not the ones it pinned.
- **Every package the project's packages declare is fetched too,** each once, into the same
  directory.

### The lock

`jac.lock` holds one entry for each installed package the program needs, whoever installed it. A
package declared by its directory has none.

```toml
[jac.grid]
version = "1.4.0"
digest = "sha256:9f2c5a0f6f1d7c1f3f0f8a4a1c6c4a0d6f6b6f0c3a8a3c1e7b2d5e9f4a1b0c3d"
installer = "jacpm"

[jac.grid.from]
registry = "https://packages.example.org"

[jac.units]
version = "0.1.0"
digest = "sha256:ebe3029117f00a21e55d5167bcfea5d77279d74f1eb847daf0195c67eca3aecd"
installer = "neojac"

[jac.units.from]
git = "https://example.com/units.git"
rev = "v1.2.0"
commit = "6c8f55b32d8a611f0d288e5035357a17934bfd9b"
```

- **`neojac install` is the one writer of `jac.lock`.** It pins each installed package from what
  is in `eco/jac/` and from the record beside it: the package's `version`, its `installer`, the
  installer's `from`, and a `digest` of its files. A package manager reads the entries that name
  it, to install exactly what they pin.
- **The digest is SHA-256,** and any program can compute it. For each file of the package, a line:
  its path from the package's directory, with `/` between its parts, a zero byte, the SHA-256 of
  the file's bytes in hexadecimal, and a newline. The digest is `sha256:` and the SHA-256 of
  those lines, in the order of their paths. A link to a directory inside a package is not
  followed.
- **`neojac install` pins a package again** when its version or its `from` changed. It refuses
  one whose files changed under the same version from the same place (E5166): that is not the
  package that was pinned.
- **A declared package that is not installed stops it** (E5161): it names every one, with who
  asks for it and for what.
- **`neojac install --frozen` writes nothing.** Every package the program needs is installed and
  pinned, and its version, its record and its files are what is pinned, or it stops (E5166),
  naming the package and what installed it.
- **What nothing declares any more is no longer pinned.** neojac removes the package if it
  fetched it, and leaves another installer's where it is.
- **On a fresh clone,** the project's package manager installs what `jac.lock` pins for it, and
  `neojac install --frozen` fetches neojac's own and verifies them all.
- **The lock's format is 2.** A lock of another format is E5164.

### What a project's packages are: neojac packages

```text
$ neojac packages
grid 1.4.0: a library, found, in eco/jac/grid, which 'jacpm' installed
    the project asks for version 1.2 or later, below 2.0.0
cells: a package, missing, in eco/jac/cells
    the library 'grid' asks for version 0.3 or later, below 0.4.0: not met

Interfaces: auth 4, bundler 1, files 2, jobs 1, limits 1, llm 1, mail 1, schedule 2, store 1, transport 2, ui 1

eco/jac/grid/jac.toml:7:1: error[E5161]: the package 'cells' is not installed as the library 'grid' asks, version 0.3 or later, below 0.4.0: nothing is at 'eco/jac/cells'
```

- **It prints the project's Jac packages as the compiler finds them:** each one's name, version
  and kind (and what a plugin fills), where its copy is and what installed it, every package that
  asks for it and for what, and whether it is found, missing, or wrong.
- **Then the version of each abstraction's interface** in this neojac, which is what a plugin's
  `interface_ver` has to be ([Plugins](../apps/plugins.md#the-abstractions)), and every problem
  with its place in a `jac.toml`: the ones `neojac check` reports.
- **It reads and changes nothing:** it fetches no package, writes no lock, hashes no file.
- **It exits 1 when a package is missing or a check fails,** so a script can ask whether a
  project's packages are installed.
- **`--json` prints the same as one document,** for a program to read
  ([Writing a package manager](package-managers.md#neojac-packages---json)).

### What a package needs of npm and PyPI

A library or a plugin says what it needs of other ecosystems as a project does, and
`neojac install` installs it with the project's own:

- **Its `[dependencies.pypi]`** is resolved together with the project's, into the project's
  `.jac/venv`, and pinned in `jac.lock`'s `[pypi]`.
- **The `dependencies` of its `[npm."<directory>"]` tables** are written into every npm tree of
  the project, with the tree's own. Two askers of one npm package agree on its range (E5162).
- **Neither is written into the project's `jac.toml`.** What `neojac npm` takes back from a tree is
  the project's own packages.

## npm trees

An npm tree is one package and the packages it depends on: one `package.json`, one lock, one
`node_modules`, in one directory. A tree is named by that directory, from the project's root with
`/` between its parts (`.` is the root itself), and `jac.toml`'s `[npm."<directory>"]` table is the
`package.json` there, key for key, with npm's own names for its keys:

```toml
[npm."eco/web"]
private = true
type = "module"

[npm."eco/web".dependencies]
nanoid = "^5.1.0"
lodash = "^4.17.21"

[npm."eco/web".devDependencies]
"@types/lodash" = "^4.17.0"
```

```sh
neojac install --npm nanoid lodash --tree eco/web    # add packages, making the tree if it is new
neojac remove --npm lodash                           # take one out
```

`--tree` names the tree's directory, as a path from where the command is run. A project's only
tree needs no naming.

A tree may be any directory of the project. One made for a Jac project's own pages is by
convention `eco/<name>`, beside the project's modules and apart from them. One taken in from a
repository that already had a `package.json` is wherever that file stands, its sources beside it:
`[npm."frontend"]`, or `[npm."."]` for a package at the root.

### Workspaces

A tree whose `package.json` has `workspaces` is a workspace: several packages installed as one.
Its root is a tree, and so is each member, a table for each:

```toml
[npm."."]
name = "shop"
private = true
workspaces = ["frontend", "packages/*"]

[npm."frontend"]
name = "frontend"

[npm."frontend".dependencies]
emails = "*"

[npm."packages/emails"]
name = "emails"
```

- **Which directories are members is npm's own answer.** neojac asks the workspace mapper npm
  itself uses, which reads the root's `workspaces` and finds the `package.json` files it reaches.
  A `package.json` it does not reach (a test fixture, a template) is no tree, and none is made
  of it.
- **A workspace has one lock,** the root's, and `jac.lock` holds it under the root's name. A
  member has none.
- **It is installed as one.** `neojac install` runs npm at the root, once, and prints the
  members with it. A space that names a member (`npm = "frontend"`) finds its packages as Node
  does, from the member's directory upward, and is built only when the workspace is installed as
  `jac.toml` and `jac.lock` say (E5160).
- **`neojac npm` in a member's directory** is npm run in that workspace. What it writes to any of
  the workspace's `package.json` files, and to the root's lock, is taken back.
- **Every member is a table.** A member npm finds that `jac.toml` holds none for is E5159:
  `neojac absorb` of the root's directory takes each in.
- **A member links another by `workspace:`**, as pnpm's and yarn's users write it. It is
  `jac.toml`'s own form, and the one place a tree's table is not its `package.json` key for key:

  ```toml
  [npm."frontend".dependencies]
  emails = "workspace:*"
  ```

  npm does not read `workspace:`, so the `package.json` neojac writes has the range npm links a
  member by: `*` for `workspace:*`, `workspace:^` and `workspace:~`, and the range itself for
  `workspace:<range>`. What npm writes back there is taken as the link it was written from, so
  the table keeps it. The package named must be one of the same workspace (E5170), and a link
  in another form, a path or an alias, is E5171.
- **An app's artifact does not carry a member's packages yet.** An app whose node space runs on a
  member's tree is refused (E5090).

### Which tree a space's imports use

A project with one tree uses it everywhere: for every space, and for a program of no space. A
project with several says which is each space's, in `jac.toml`:

```toml
[spaces.site]
npm = "eco/web"

[spaces.phone]
npm = "eco/mobile"
```

A space naming a tree `jac.toml` does not declare is E1287, and a module importing from npm where
nothing says which of several trees is its own is E1288.

## A tree's directory

A tree's directory is where its tools run. Here the tree is `eco/web`:

```text
shop/
    jac.toml
    jac.lock
    main.jac
    eco/
        web/
            vite.config.ts        yours, tracked
            index.html            yours, tracked
            package.json          written by neojac from jac.toml
            package-lock.json     written by neojac from jac.lock
            node_modules/         installed by neojac install
            .jac/                 the tree's spaces, compiled
```

- **What you write there** is what a tool's own configuration is written in, and any file of
  yours that imports the tree's packages: a bundler's configuration, `tsconfig.json`,
  `index.html`, a stylesheet that imports a package. A tool finds a file's packages by looking in
  the directories above the file, so such a file is under its tree.
- **What neojac writes there** is not tracked. The first time it writes a tree it adds the three
  to the project's `.gitignore`, by their paths from the root:

  ```text
  /eco/web/package.json
  /eco/web/package-lock.json
  /eco/web/node_modules/
  ```

  `.jac/` is ignored as the project's own is.
- **A JavaScript space is compiled there**, into `<directory>/.jac/build`, so that its modules
  find the tree's packages and its `tsconfig.json` as any file of the tree does.
- **`eco/` is not the project's source**: a file under it is in no layer of `archwire.jac`
  ([Projects](projects.md#what-is-not-the-projects-source)). A tree anywhere else stands among
  the project's files, and its JavaScript and TypeScript are modules of the project.

## Rust crates, C modules and Python projects

A crate's `Cargo.toml`, the `Cargo.lock` beside it, a [C module](../interop/c-modules.md)'s
`cmodule.toml` and a Python project's `pyproject.toml` are tables of `jac.toml` and `jac.lock`
too, each named by its directory from the project's root:

```toml
[cargo.adder]
[cargo.adder.package]
name = "adder"
version = "0.1.0"
edition = "2024"

[c.geom]
sources = ["geom.c"]

[c.geom.target.linux]
libs = ["m"]

[pypi.backend]
[pypi.backend.project]
name = "app"
version = "0.1.0"
dependencies = ["fastapi>=0.141"]
```

- **A table is the manifest's own text**, its tables named under the directory's. Comments are
  kept, and the file neojac writes from it is the file that was taken in, byte for byte.
- **The files are written where they stand**, `adder/Cargo.toml` and `geom/cmodule.toml`, not
  under `eco/`: cargo finds a crate's sources, and its workspace, from where its manifest is.
  neojac writes them before any command looks for them, making a directory that holds nothing
  else, and lists each in the project's `.gitignore`.
- **`neojac absorb <directory>`** takes in every `Cargo.toml`, `cmodule.toml` and `pyproject.toml`
  under a directory, into the `jac.toml` of the project each is in. A workspace is a table for
  its root and one for each member.
- **A `pyproject.toml`'s table is the project's manifest as its own tools read it**: its build
  backend's, pytest's, a linter's. `neojac install` installs what it depends on, beside what
  `[dependencies.pypi]` lists ([Python](../interop/python.md#a-python-project-of-the-repository)).
- **A Python project the repository holds is installed already, to pip.** Where what `neojac
  install` resolves depends on one of them (a test group's package that depends on the project
  itself), pip is given that project as installed, at its name and version, and takes it; no
  release of it is fetched, and `jac.lock` pins none. The program imports the project as neojac
  builds it, one copy.
- **`neojac cargo`** writes the project's manifests first, and takes back what cargo changed as it
  ends (`cargo add`, `cargo update`): a crate's manifest, never another kind's.
- **A C module's `cmodule.toml` beside a module `jac.toml` holds is `jac.toml`'s own copy.** No
  tool but neojac writes one, so neojac writes it from the table and never takes it back: an
  absorb, a record and `neojac cargo` write it again where it differs. A `cmodule.toml` a tree
  has before `jac.toml` holds its directory is taken in as any manifest is.

A program with no `jac.toml` above it keeps its manifests as files: a loose `main.jac` beside a
`geom/cmodule.toml` builds as it did.

## Extension modules

A Python package's module may be native code that a build makes: `spamlib._tally` built from a
Rust crate, `probe._probe_osx` from a C library. No file of the project is that module, so
`jac.toml` says which unit is:

```toml
[extensions."spamlib/_tally"]
cargo = "."
features = ["python"]
recorded = ["linux-aarch64", "macos-aarch64"]
```

- **It is named by the module's path** from the project's root, and names the crate
  (`cargo`, with the `features` it is built with) or the C module (`c`) of the project it is built
  from, by the directory of that unit's table, or the Jac module (`jac`) by its file.
- **`recorded` lists the platforms its build was recorded on**, and it is built on those. One
  with no list, written by hand, is built on every platform. A project or a tree all of whose
  extension modules are recorded for other platforms is refused there (E5172): what its build
  compiles on this one is not known until it is recorded on it
  ([A record is of one platform](#a-record-is-of-one-platform)).
- **It is a module of the project.** A file that imports it is wired from it. Until the table is
  there, an import of a name the package does not give, in a Python project that builds and has
  no `[wheel]` table, is the module the build makes, with no wire and no error: a plain `neojac
  absorb` of such a tree exits 0, with the tree's build as its open item
  ([Open items](#open-items)), and `neojac absorb --record` writes the table and the wire.
- **`neojac absorb --record` writes the table**, for a module linked from a crate or from C,
  from what the repository's own build does ([Recording a build](#recording-a-build)).
- **neojac builds it** with the Python project it is a module of
  ([Building and testing a Python project](#building-and-testing-a-python-project)): a crate as
  a shared library with those features, a C module's sources linked into one, each linked as an
  extension of neojac's CPython and named with the ending that interpreter loads. On Windows it
  is refused (E5090). A crate's build is given that CPython wherever neojac runs cargo (a
  build, a record, a port's reading, `neojac cargo`): PyO3's build script finds it by
  `PYO3_PYTHON`, and a build for another target is given that target's CPython by PyO3's cross
  variables, so no Python need be on `PATH`.
- **Under an npm tree it is a Node addon**, built from a C module where the tree's own code looks
  for it, `<path>.node`: `neojac build <directory>/package.json` builds the tree's, and
  `neojac test` builds them before the tree's suite. It exports Node-API's entry points
  (`napi_register_module_v1`, `node_api_module_get_api_version_v1`), as one under a Python tree
  exports `PyInit_<name>`, whatever it is built from, and nothing else (below). The version entry
  is optional: an addon without it is Node-API version 8 to Node. An addon that registers itself
  from a static constructor (V8's `NODE_MODULE`, NAN, older Node-API headers' `NAPI_MODULE`)
  defines no entry and is refused by name (E5090); `NAPI_MODULE_INIT` defines the entry.
  `--target <platform>` builds the tree's addons for a Linux or macOS platform, each from the Jac
  its C module's files are ported to, which builds for any target; one built from C and C++ is
  built on the system it is for (E5090), and its row must be recorded for the platform (E5172).
- **A C module some of whose sources were ported is built from their Jac.** The extension module
  or the addon links the Jac its C module's `jac` lists with the sources that stay
  ([C modules](../interop/c-modules.md#the-manifest)), so a recorded addon whose C++ `neojac port`
  made Jac is built from the Jac and loads in Node as the C++'s did.

  ```toml
  [extensions."build/Release/kvstore"]
  c = "src"
  ```

- **One built from a Jac module is that module, as Python's.** Its public functions and its
  `obj`s are the extension module's: a function's parameters and result cross as a native
  space's do ([Python](../interop/python.md)), a Jac exception is the Python exception of its
  name, and an `obj` is a Python class, whose objects Python makes, calls and reads the fields of.
  `neojac build native/eggs.jac` builds it alone, and `neojac build pyproject.toml` with its
  project; it links nothing of the interpreter, whose C API the Python that imports it gives it.

  ```toml
  [extensions."spamlib/_eggs"]
  jac = "native/eggs.jac"
  ```

  With `def halve(n: int) -> int`, which raises `ValueError` for an odd `n`, and
  `obj Basket { has owner: str, eggs: list[int] = []; def add(n: int) -> int; }` in
  `native/eggs.jac`, `from spamlib import _eggs` gives `_eggs.halve(8) == 4`, a `ValueError`
  from `_eggs.halve(3)`, and `_eggs.Basket("ann").add(5) == 1`.

  What Python sees of a class is its face:

  - **Its `:priv` members are not Python's**, nor are `init` and `postinit` (Python makes an
    object by calling the class): reading or setting one is `AttributeError`, and `dir()` of an
    object lists its other members, fields with no default among them.
  - **A class's `static has __module__: str`** is its Python class's `__module__`; without one it
    is the module's name.
  - **A class whose own `init` is `:priv` has no constructor for Python**: calling the class
    raises `TypeError` (`cannot create 'spamlib._eggs.Sealed' instances`, PyO3's text), while
    Jac makes it as before and hands it to Python. An instance of a `:priv` class that Python
    gets keeps the face's rules: its `:priv` members hidden, its module, no constructor.
  - **A class that defines no `__repr__` has Python's default repr**, `<spamlib._eggs.Basket
    object at 0x...>`, the address Python's own, as an extension's class has; Jac's generated
    repr would show its `:priv` fields. A Jac module Python imports keeps Jac's repr.
  - **A Jac exception crosses as itself**: one the program raises reaches Python holding the Jac
    object, with its `args` and its fields (`e.code`), and is that object again where it comes
    back into Jac; Python makes one (`_eggs.Fault(5)`) by the class's `init`. One that derives
    only from `BaseException` (`obj Halt(BaseException) {}`) crosses as itself too, as Python's
    `BaseException` subclasses do, and the next call into the module runs as before.
  - **An `obj` that defines `__buffer__` and `__release_buffer__` exports its memory** to Python,
    as PEP 688 says: `memoryview(obj)` and `bytes(obj)` read it. A Jac `memoryview` reaching
    Python is Python's view of the same memory, with its format, item size, shape, strides and
    read-only flag; a view of a `bytearray` is refused (`BufferError`), since its bytes move as
    it grows.
  - **A value crosses checked**: a sized int out of its type's range is `OverflowError` (`-1` for
    a `u32` parameter), a Python `set` or `frozenset` is a Jac `set`, and a `list[u32]` the
    module gives is a Python list of its items.

  `neojac port` writes such a module from a crate's PyO3 bindings
  ([Porting Rust](../interop/port-rust.md)): `#[pyclass]` with its `#[pymethods]` is an `obj`
  holding the crate's value in a `:priv` field, with `__module__` `builtins` as PyO3 gives it,
  and a `#[pyclass]` with no `#[new]` an `obj` whose `init` is `:priv`. A Rust panic that ends a
  method reaches Python as PyO3's `pyo3_runtime.PanicException`, a `BaseException`, holding the
  panic's message, as PyO3 catches each call; Rust's own line on stderr is not written.
  The extension is built from that module once its `[extensions]` row names it by `jac`
  (`jac = "src/py.jac"`) in place of the crate's `cargo`. Port writes that row where the crate
  ports whole, the port of the file that holds `#[pymodule]`, and keeps of the crate's
  `[cargo."<directory>"]` table only its package and the dependencies its Jac imports
  ([port](port.md)).

- **It links its own C module and the C modules its `links` names, and no others.** A row
  built from a C module may list the other C modules of the project its link takes, each by the
  directory of its table: `links = ["deps/sqlite3"]` (`neojac absorb --record` writes it from the
  link it recorded). Each one's objects are made a library and given to the link, as a build
  system gives a static library, whether the extension is built from the C module's C and C++ or
  from their Jac. The archwire's flows say which names move between files, not what is linked.
  An extension that leaves undefined a symbol one of the project's C modules defines is refused
  after its link and removed (E5270): the process that loads it would resolve the symbol from its
  own copy, as Node gives libuv's.

  ```toml
  [extensions."build/Release/kvstore"]
  c = "src"
  links = ["deps/sqlite3"]
  ```

- **It exports its entry points and nothing else**, on every
  target, whether it is built from C and C++ or from Jac: `PyInit_<name>` under a Python tree,
  Node-API's pair under an npm tree, or the names its row's `exports` lists. Every other
  definition in it is local to it, those of the C modules its `links` names among them, whatever
  their sources and flags would export: so each of its calls reaches its own function. On Linux a
  shared library's reference to a function it defines would otherwise bind to the host's function
  of that name: an addon vendoring a C library that defines `uv_version` would call Node's.
  A library its host loads by its own convention, not as an extension module or an addon, names
  what it gives in `exports`: a SQLite loadable extension in an npm tree, which SQLite looks up
  by `sqlite3_extension_init`, or a library Python's `ctypes` opens.

  ```toml
  [extensions."test/plug"]
  c = "test/plug"
  exports = ["sqlite3_extension_init"]
  ```

## Building and testing a Python project

A Python project the repository holds is built from `jac.toml` alone, with no build backend:

```toml
[pypi."."]                            # pyproject.toml, as it stands

[wheel."."]                           # what its wheel holds: written by `neojac absorb --record`
files = ["spamlib/__init__.py", "spamlib/core.py", "spamlib/py.typed"]

[extensions."spamlib/_tally"]
cargo = "."
features = ["python"]

[test.pypi."."]                       # how its tests are run: yours to write
command = ["pytest", "tests", "--import-mode=append"]
```

```text
$ neojac build pyproject.toml
.jac/build/pypi/top/site
$ neojac test
pyproject.toml: pytest tests --import-mode=append
...
============================== 33 passed in 1.11s ==============================

1 of 1 suite of the project's own passed in 1.84s
```

- **`[wheel."<directory>"]` is what the project's wheel holds of its files**, each by its path
  in the wheel. `root` is where those paths start below the project's directory (`src`), and is
  left out where that is the directory itself. Only the project's build backend knows the list,
  so `neojac absorb --record` writes it from the wheel that backend makes, and no build reads the
  directory for it: a module added later is added to `files`, or the build is recorded again.
- **`neojac build <directory>/pyproject.toml` makes that wheel's contents** in a directory of
  `.jac/build/pypi/`, and prints it: the listed files, each extension module whose path is the
  project's ([Extension modules](#extension-modules)), and a `.dist-info` with its `METADATA`,
  `WHEEL`, `RECORD`, `entry_points.txt` and licenses.
- **Its metadata is its `[project]` table's.** What the project's build states instead
  (a `setup.py`'s `name` and `version`, a field `dynamic` lists) is recorded beside the files,
  `[wheel."<directory>".metadata]`, each field by its name in `METADATA`, and is used in place of
  the table's.
- **A module of the wheel may be Jac**: `files` lists it by its `.jac` file
  (`fastlib/api.jac`), as `neojac port` writes it when it ports the module. The build emits the
  project's cpython space ([archwire](../apps/archwire.md#a-space-of-a-tree)) and puts in the wheel
  Python's own module for it, a sourceless `fastlib/api.pyc`, which starts where Python first
  imports it, with the runtime it needs under a name of the wheel's own (`_jac_fastlib.py`). Its
  bytecode is the interpreter's, so such a wheel's tag is that interpreter's
  (`cp315-cp315-<platform>`). A Python file of another cpython space, the `_dev` space's tests,
  imports it as the package's, in its own process, as it imports the package's Python modules.
- **A module only another platform's program loads is that platform's wheel's.** Where
  `fastlib/api.jac` imports `fastlib/_plan9.jac` under `comptime if target().os == "plan9"`, the
  space's program for this platform never loads `_plan9`, so this platform's wheel holds no code
  of it and is tagged for its platform (`Root-Is-Purelib: false`); the wheel built for the
  platform whose program loads it holds it. A `.pyc` belongs to the program its space emitted it
  for, so one platform's cannot stand in another's.
- **`tag` is recorded where the build names one the interpreter would not**: `cp38-abi3`, for
  extension modules built against CPython's stable ABI.
- **`[test.pypi."<directory>"]` is the project's own suite**: `command`, run by `neojac test`
  after the Jac tests, in the project's directory, with `.jac/venv` first on `PATH`. It names the
  `groups` (`[dependency-groups]`) and the `extras` (`[project.optional-dependencies]`) of the
  `pyproject.toml` that the command needs, which `neojac install` installs with the rest, after
  those `[install.pypi."<directory>"]` names (below).
  `absorb` writes it for a project that configures pytest, or holds pytest's `conftest.py` in its
  directory or one directory down, and has no test command of its own:
  `command = ["pytest", "--import-mode=append"]`, with `groups = ["test"]` where `test` is the
  one dependency group that names pytest ([jac.toml](../reference/jac-toml.md#testpypidirectory)):
  the import mode keeps the package's directory beside the tests off the front of Python's path
  (below). Where
  the tree's tests are Jac, it runs over what its spaces emit
  ([Testing](test.md#a-projects-own-suites)).
- **`[install.pypi."<directory>"]` is what `neojac install` installs of the project beyond its
  dependencies**, whether or not a test needs it: its `groups` and its `extras`, for every Python
  project, one that ships no wheel included (a workspace's root, whose scripts import what its
  `dev` group installs). `absorb` writes `groups` for a project uv describes (a `uv.lock` beside it
  or at its workspace's root) as uv installs it by default: `[tool.uv] default-groups`, every
  group where that is `"all"`, and `["dev"]` where it is unset and the project has a `dev` group
  ([jac.toml](../reference/jac-toml.md#installpypidirectory)).

  ```toml
  [install.pypi."."]
  groups = ["dev"]
  extras = ["blobfile"]
  ```
- **A module of the tree has the name Python gives it**: a module under the wheel's `root` is
  named from there (`src/fastlib/api.jac` is `fastlib.api` where `root = "src"`), and one outside
  it, a test, from the tree's directory (the template's `backend/app/models.jac` is
  `app.models`). A Jac module's Python name is the one its
  Python siblings import it by, and the one the wheel holds it under.
- **The suite runs against what was built.** The build is first on Python's path, and the
  directory a Python is started in is not on it (`PYTHONSAFEPATH`), in the command and in every
  Python it starts. A package's directory beside the tests holds no extension module, so pytest
  is told not to put it first either: `--import-mode=append`, or `importlib`.
- **A suite that fails fails the run**, with its own output as it printed it.
- **The project's wheel is a package of the archwire**: a `cpython` space that holds the project
  by its directory, and `package <name> { ship <space>; }`. `neojac absorb --record` writes both,
  named for the project, and `neojac build` packs the built directory into `dist/`
  ([archwire](../apps/archwire.md#packages)).

## Running npm

`neojac npm` and `neojac npx` run in a tree: the one whose directory they are run in or under
(the nearest, where one tree's directory holds another's), or the project's only tree. neojac writes the tree's `package.json` and lock first, and when npm ends
it takes what npm wrote back into `jac.toml` and `jac.lock`:

```text
$ neojac npm pkg set description="A shop"
neojac: jac.toml took what npm wrote in eco/web
```

Only the tree's table changes. The rest of `jac.toml`, its comments with it, is as it was.

In a tree some of whose files `neojac port` made Jac, `neojac npm run`, `run-script`, `test` and
`start`, and `neojac npx`, run in the tree as its space emits it, laid in
`.jac/test/spaces/<space>/<tree>/`: the tree's own files, a forwarder of each ported source's own
name at its place, and what the space emits in the laid tree's `.jac/`
([neojac test](test.md#a-projects-own-suites)). So `neojac npm run build` and
`neojac npx vite build` build the ported tree by its own configuration. npm's other commands
(`install`, `pkg`, `ls`) run in the tree itself.

In a directory that is no Jac project (no `jac.toml` in it or above it), `neojac npm` is npm as it
is anywhere, on that directory's own `package.json`.

### What a package's script builds

A package that compiles as it is installed (a Node addon by `node-gyp`, a Python package from its
source distribution) is built with neojac's own compilers, not with whatever the machine has:

- **npm's scripts, and a Python build backend, are given `CC`, `CXX` and `AR`**: `neojac cc`,
  `neojac c++` and `neojac ar` of the neojac that is running, each left as it is where the
  environment already names one. `neojac install`, `neojac npm` and `neojac npx` all do.
- **neojac's cargo is first on `PATH`**, with the rest of what `neojac cargo` gives a build,
  where the toolchain has Rust. PyO3's build script among them is given neojac's own CPython,
  the one `neojac python` runs, by `PYO3_PYTHON`: a Python package built from a crate's source
  distribution is built for the interpreter it is installed for, with no Python on `PATH`.
- **What a build needs besides is the machine's**: `make` for `node-gyp`, and on macOS the
  `libtool` that node-gyp makes a static library with.

A tree's own addon is recorded once and built from `jac.toml` from then on
([Recording a build](#recording-a-build)).

## Taking in a repository: neojac absorb

`neojac absorb` takes the manifests a repository already has into `jac.toml`, each where it
stands, and writes the project's `archwire.jac`. No source file changes.

```sh
neojac absorb --check          # what this repository is: nothing is written
neojac absorb                  # make it a project
neojac absorb --record         # and run its build, to write what that links
neojac absorb crates           # the manifests under crates/, into the project this directory is in
```

A directory with no `jac.toml` in it or above it becomes a project: `absorb` makes the file.

### Which manifests are the project's

Each ecosystem answers for its own:

| Manifest | Becomes | Its workspaces, asked of |
|---|---|---|
| `package.json`, with its `package-lock.json` | `[npm."<directory>"]` | npm's own workspace mapper ([Workspaces](#workspaces)) |
| `pyproject.toml` | `[pypi."<directory>"]` | The members and exclusions `[tool.uv.workspace]` lists |
| `Cargo.toml`, with its `Cargo.lock` | `[cargo."<directory>"]` | `cargo metadata` |
| `cmodule.toml` | `[c."<directory>"]` | A C module has none |

- **The first manifest of an ecosystem met from the top is a tree**, and under it only the
  workspaces its own tool names are trees too.
- **Any other manifest under a tree is data**: a test fixture's `package.json`, a template's.
  Nothing under its directory is taken, and the directory is added to `jac.toml`'s
  `[project] exclude`, so its files are no modules of the project
  ([Projects](projects.md#what-is-not-the-projects-source)).
- **Nothing moves.** A manifest names its files by path, so it stays beside them. From then on
  neojac writes it there from its table, and lists it in `.gitignore`.
- **A directory with a `jac.toml` of its own is another project**, and is passed by.
- **What a build left is no source of the project.** Each directory git's own ignore list names
  (`.gitignore`, `.git/info/exclude` and the global excludes, as git reads them) that holds a
  source file of a language neojac reads, a `build/` that a Python build copied the package
  into, is added to `[project] exclude`, and `absorb` says so ("what a build left: ...").
  Nothing under `node_modules`, `eco`, `.jac` or `replaced-by-neojac`, at any depth, nor under
  any directory whose name starts with `.`, is what a build left: an installed package, in a
  tree's own `web/node_modules/` too, holds JavaScript, and git lists each ignored package by its
  path once anything under `node_modules` is tracked. A repository that is no git's gets none.

### The archwire it writes

Where the project has no `archwire.jac`, `absorb` writes one with a single layer,
`layer all { *; }`: nothing of the project's layering is known yet. It then writes a wire for
every import between the project's files, as each language's own engine reads them
([Declared wires](../language/modules-wiring.md#declared-wires---)), which is what
`neojac fmt --fix archwire.jac` does.

It declares a space for each npm tree that is a program's
([A space of a tree](../apps/archwire.md#a-space-of-a-tree)), named for its package, in the
`graph spaces` block that is there or in a new one: a `node` space for a package that names a
`main` or `exports` (`space store: node { "store"; }`), and a `browser` space, with
`[spaces.<space>.ui] plugin` the `ui` plugin its dependencies name, for a tree a bundler builds.
A tree that names no bundler, no `main` and no `exports`, and is no workspace's root (a package of
email templates a server renders), is a `node` space with the `ui` plugin its dependencies name,
`react` for one that depends on React. Once a Python project has its space ([Recording a build](#recording-a-build)), its tests and
scripts are a second `cpython` space, `<space>_dev`, which each later absorb grows with what came
since. An npm package's files that run in Node and that the package does not ship (its tests,
its benchmarks: what its `files` leaves out) are a second `node` space the same way,
`<space>_dev: node { test.* | benchmark.*; }`, and so are a browser tree's Node files that import
its modules. A Python tree that ships no wheel, with neither a `[project]` nor a `[build-system]`
table (a uv workspace's root), has its own Python files in a `cpython` space all the same,
`<dir>_dev`, named for the tree's directory (`space shop_dev: cpython { hooks.* | scripts.*; }`
for the root of a repository in `shop/`); a workspace member's files
stay the member's. A tree a space already
holds, and a name already taken, are left alone.

What still stands between the archwire and a check that passes is printed as the diagnostics
every command would give, and `absorb` then exits with status 1. The files it wrote stay.

### Open items

What no manifest says, and only a program of the repository or a person knows, is an **open
item**. `absorb` lists each at its file, and does not guess:

| Kind | Reported for | What closes it |
|---|---|---|
| `build` | A `setup.py` beside a `pyproject.toml`, or a `pyproject.toml` whose build backend is in the repository (`backend-path`); any other Python project that builds a wheel and has no `[wheel]` table yet, whose build backend says what the wheel holds, so that no space holds its Python until a record does; a `binding.gyp` beside a `package.json` | `neojac absorb --record` ([Recording a build](#recording-a-build)): a Python project's module linked from a crate or from C, what its wheel holds and the space that holds its Python, and an npm tree's addon linked from C |
| `lock` | `uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile.lock`; `bun.lock`, `pnpm-lock.yaml`, `yarn.lock` | The same versions pinned by pip or npm in `jac.lock` ([A lock another tool wrote](#a-lock-another-tool-wrote)) |
| `form` | `pnpm-workspace.yaml`, and a key of a `pnpm` table in `package.json` that npm has no counterpart of (`packageExtensions`) | The form npm reads. `pnpm.overrides` and a `workspace:` dependency are no open item: absorb rewrites the one ([below](#what-absorb-rewrites)) and `jac.toml` holds the other ([Workspaces](#workspaces)) |
| `tests` | A Python project with no test command of its own that neither configures pytest nor holds a `conftest.py`; one that does where several dependency groups name pytest, or none does | `[test.pypi."<directory>"]`, the command that runs its tests, or its `groups` ([Building and testing a Python project](#building-and-testing-a-python-project)) |

```text
$ neojac absorb --check
spamlib is a Python project (pyproject.toml) and a Rust package (Cargo.toml)

  jac.toml     [pypi."."]   pyproject.toml, as it stands
               [cargo."."]  Cargo.toml, as it stands
  archwire.jac one layer, and a wire for every import between its files

open items
   1  setup.py: a program that builds this project: no manifest says what it compiles, or into which module
   2  pyproject.toml: no manifest says how this tree's tests are run

nothing written
```

### A lock another tool wrote

A lock neojac's engines do not read is not copied into `jac.lock`. Its pins are what
`neojac install` holds the engine to, and `jac.lock` records what the engine then installed.

| Lock | Read as | Held by |
|---|---|---|
| `uv.lock` | Each package a registry gives, at its version | pip |
| `pnpm-lock.yaml` (format 9) | Each package and the versions of its dependencies; the range each is asked for by is read from the registry, where the lock leaves it out | npm |
| `bun.lock` (format 1) | Each package, the ranges it asks for its dependencies by, and the versions they get | npm |

`poetry.lock`, `pdm.lock`, `Pipfile.lock`, `yarn.lock` and `bun.lockb` are not read, and stay
open items.

```text
$ neojac install
neojac install: cffi: pinned 2.0.0 by another tool's lock, which has no wheel for this Python and does not build (.jac/pins/cffi-2.0.0.log): 2.1.1 is used
neojac install: 73 PyPI distributions in .jac/venv
neojac install: the npm tree ., with its workspaces frontend, packages/mail
$ neojac absorb --check
...
locks
  bun.lock: 530 of 531 pins reproduced by npm
  uv.lock: 72 of 73 pins reproduced by pip

open items
   1  bun.lock: 1 of its pins is not what npm installs: ajv-formats (pinned 3.0.1, 2.1.1 installed): accept each by name in jac.toml, [lock.npm] accept
   2  uv.lock: 1 of its pins is not what pip installs: cffi (pinned 2.0.0, 2.1.1 installed): accept each by name in jac.toml, [lock.pypi] accept
```

- **Every pin the engine can install is the version installed,** though a newer one fits what
  the project asks for.
- **The lock stays an open item until every difference is accepted by name:**

  ```toml
  [lock.pypi]
  accept = ["cffi"]

  [lock.npm]
  accept = ["ajv-formats"]
  ```

  A name accepted is no longer held to the other lock's pin. `absorb` lists it beside the count,
  `and cffi accepted as installed`.
- **While the other lock stands, it is what `jac.lock` is resolved under.** `jac.lock`'s
  `[held_to]` names each such lock with a hash of its bytes, and a `neojac install` after one
  changed resolves again under it. Where it and `jac.lock` disagree on a version, the other
  lock's is taken.
- **Once it is reproduced, the other lock goes.** With each of its pins reproduced or accepted,
  `neojac absorb` moves it to [`replaced-by-neojac/`](#what-neojac-replaced-replaced-by-neojac).
  `jac.lock` pins the same versions, and `neojac install --frozen` installs them, with the lock
  there or not.
- **`absorb` reads and compares; it resolves nothing.** Before the first `neojac install` the
  item says that an install resolves with the pins.

What pip does with a `uv.lock`:

- **A name the lock pins at two versions,** one for each of two platforms, is left to pip.
- **A pin with no wheel for neojac's CPython is built from its source,** with the toolchain's
  compilers and cargo. The first install under a lock takes as long as those builds do; pip
  keeps the wheels.
- **A pin that cannot be installed is not held.** pip picks that package's version, and
  `neojac install` names the package, the pin, the version used and the log of the build that
  failed (`.jac/pins/`).

What npm does with a `pnpm-lock.yaml` or a `bun.lock`:

- **npm resolves by the lock's pins, and lays the tree out itself.** neojac hands them to npm as
  a `yarn.lock`, the one other lock npm reads while it resolves: each thing npm will ask for (a
  name and a range, as a `package.json` has them), with the version and the integrity the lock
  gives it. The file stands beside the tree only while npm resolves; what was handed over is
  kept as `.jac/pins/<lock>-yarn.lock`.
- **The tree is resolved from nothing:** its `node_modules`, and its workspaces', are removed
  first, since npm keeps what is installed over what a lock says. `jac.lock` then holds the
  `package-lock.json` npm wrote, and the install that follows runs the packages' scripts.
- **A pin is handed over only where npm would take it:** the package npm asks for by that name,
  at a version the range admits. pnpm installs a peer a range does not admit, and npm does not;
  such a pin is a difference, named in the item.
- **One range has one version.** Where the lock gives one name and range two versions, for two
  packages that ask alike, npm is handed the one given more often, and the other is a
  difference.
- **A package another package carries inside its own archive** (`bundleDependencies`) is not
  compared: the other tools do not list it.
- **pnpm's lock is YAML,** which neojac reads itself, with the YAML reader of the LLVM it is
  built on: one document, its values by YAML 1.2's core schema. Nothing is fetched to read it.
  A package's ranges come from the registry the tree's own `.npmrc` names, as npm asks it.
- **A lock in another format is said,** `its format is 6.0, and neojac reads 9`, and npm
  resolves without its pins. So it does where npm cannot install the pins together: the install
  says so, with npm's log.

### What neojac replaced: `replaced-by-neojac/`

Once `jac.toml`, `jac.lock` or a record stands in for a file of the repository, absorb moves the
file into `replaced-by-neojac/`, a folder at the project's top that holds each one at the place
it stood. The folder is what can be removed: delete it, and the clean-out is done.
[`neojac port`](port.md#in-a-project) moves there each source it ports, and a C header with its
source once no C that stays reads it.

```text
moved to replaced-by-neojac/
  pyproject.toml  jac.toml holds it, and neojac writes it where it stood
  Cargo.toml      jac.toml holds it, and neojac writes it where it stood
  setup.py        the record stands in for it, and `neojac absorb --record` puts it back for its run
  MANIFEST.in     the record stands in for it, and `neojac absorb --record` puts it back for its run
  uv.lock         jac.lock reproduces its pins

neojac writes these from jac.toml and jac.lock now, and git still tracks them
  git rm --cached Cargo.toml pyproject.toml
```

| File | Moved by | What stands where it was |
|---|---|---|
| A manifest `jac.toml` holds, and its ecosystem's own lock that `jac.lock` holds (`package-lock.json`, `Cargo.lock`) | The absorb that first takes it, as it stood | The one neojac writes, which `.gitignore` lists |
| A build's own files: `setup.py`, `MANIFEST.in`, `binding.gyp` and every other gyp file gyp loaded (a `.gypi` it includes, a vendored library's `.gyp`) | An `absorb --record` whose record says all the build made | Nothing |
| Another tool's lock: `uv.lock`, `pnpm-lock.yaml`, `bun.lock` | An absorb, once each of its pins is reproduced or accepted | Nothing |

- **A manifest is kept as it stood, and neojac's stands in its place.** neojac writes the file
  where it was before any command reads it, since npm, pip and cargo read it there. git goes on
  tracking a path it already tracks, so absorb prints the command that stops it. neojac changes
  nothing of git's index.
- **A moved file's wires go with it.** Where `archwire.jac` wired a file absorb moves (a
  `setup.py` that imports the package is `_buildinfo --> setup`), the wire is dropped as the file
  moves, so that no wire names a file that is not there (E2097).
- **A build's own files move only when the record is whole**
  ([Recording a build](#recording-a-build)): every native module of the build is an
  `[extensions]` table and the wheel is a `[wheel]` table. Where the record leaves something
  unsaid, they stay.
- **A record on another platform needs them again.** They are still the only description of what
  a platform not yet recorded compiles. `neojac absorb --record` puts them back from the folder
  for its run and moves them again after it, so keep the folder, in version control, until every
  platform the project is built for is recorded: the `recorded` lists of `[extensions]` say
  which are.
- **A lock is moved when nothing of it is open**: each pin reproduced, or accepted by name
  ([A lock another tool wrote](#a-lock-another-tool-wrote)). One neojac does not read stays.
- **The folder is no part of the project.** A manifest in it is no tree, a program in it is no
  source and has no wire, `neojac port` reads nothing there, and
  [`neojac launch`](launch.md#launching-an-app) does not send it: the platform builds an
  extension module from its `[extensions]` table alone, so its `recorded` must name the
  platform's machines (E5172 otherwise).
- **`--check` moves nothing** and lists what an absorb would move. `--json` has `replaced`, each
  with its `path` and what stands in for it, `by`: `jac.toml`, `jac.lock`, `record` or `pins`.
  It has `tracked` as well, the manifests git still tracks.
- **What goes with them is what only they offered**: an install from the repository's source by
  pip or npm, which reads `pyproject.toml`, `setup.py` or `binding.gyp`, and whatever reads a
  manifest from the repository itself, a dependency scanner or an editor before any neojac
  command has run.

### What absorb rewrites

A manifest is taken as it stands, but for a form its own engine does not read and another
engine's form says exactly. absorb rewrites those once, and says so:

```text
rewritten
  package.json: pnpm.overrides is written as npm's `overrides`
  package.json: devDependencies.@types/react is 19.2.2, as the override has it, and was ^18.2.65: npm takes no override that its own package asks otherwise of
```

- **`pnpm.overrides` becomes npm's `overrides`.** A plain name and a name with a range are the
  same key in both; pnpm's `parent>child` is npm's nesting, `{ parent = { child = "..." } }`.
- **What the root itself asks for of an overridden package becomes the override's value.** pnpm
  lets an override replace its own package's dependency, and npm refuses one that contradicts it
  (`EOVERRIDE`), so the root's own range is set to what pnpm installs.
- **It is left alone, and stays an open item,** where npm has no counterpart: an override that
  removes a dependency (`"-"`), one to a `link:`, `catalog:` or `workspace:` target, or a root
  that already has `overrides` of npm's own.
- **A `package.json` absorb rewrote, and one with a `workspace:` link, is no longer the bytes it
  was**: `git diff` shows the change, which is the rewrite.

### Recording a build

What a build program compiles is in no manifest, and is not read out of the program: neojac runs
it and watches.

```text
$ neojac absorb --record
...
recorded
  [extensions."spamlib/_tally"]  the crate ., with pyo3/extension-module, python
```

- **It installs an npm tree's packages as `jac.toml` says first**, where a build of it
  (node-gyp's) needs them, so that a fresh clone records in one run.
- **It runs the project's own build**, the wheel its build backend makes, on neojac's CPython in
  a virtual environment of its own (`.jac/absorb/`), with the toolchain's `cc` and `cargo`
  [recording each run](../interop/c-and-cpp.md#recording-what-a-build-ran). That needs what the
  build needs: the network, for the packages its backend asks for.
- **A native module the wheel holds is traced to what linked it**: the library whose bytes it is,
  the run of cargo whose target directory that library is in, and so the crate and the features
  it was built with. `jac.toml` gains `[extensions."<path>"]`
  ([Extension modules](#extension-modules)), and the `build` open item is closed.
- **What the wheel holds of the project's files is `[wheel."<directory>"]`**
  ([Building and testing a Python project](#building-and-testing-a-python-project)): each file
  of the wheel is found in the project by its bytes, under one directory. A wheel that holds a
  file the project has none of (one its build generated), a file it installs outside its
  packages, or entry points its `[project]` table does not state, is reported, and its table is
  not written. Every Python project with a build is recorded, one with no native code too.
- **The project's space and its package are declared in `archwire.jac`**, once its wheel is
  recorded: `space <name>: cpython { "<directory>"; }` and `package <name> { ship <name>; }`,
  named for the project, in the `graph spaces` block that is there or in a new one. A project a
  space already holds, and a name a space, an app or a package already has, are left alone.
- **A build that finds everything already made runs no compiler**, so the record is kept from
  one run to the next. Where a module was built before any record was kept, absorb says so:
  remove what the build left (`build/`, `target/`) and record again.
- **The features are cargo's arguments as given**, a dependency's feature among them
  (`pyo3/extension-module`): nothing is left out for being the build tool's own.
- **A module linked from C becomes a C module of the project**: its sources are the units
  compiled into the library, in the order they were linked, with the directory they share as the
  module's. The flags every unit was given are the module's `include`, `defines` and `cflags`,
  and what one unit alone was given is in its `[files."<source>"]`. The interpreter's own headers
  are named as the toolchain's (`{lib}/cpython/include/python3.15`), and the frameworks and
  libraries of the link are the module's. The table's `name` is the last part of the extension
  module's path (`_probe_osx` for `probe/_probe_osx`): the key by which a wire names the C
  module, apart from its directory ([The manifest](../interop/c-modules.md#the-manifest)). A
  table recorded before without one is given it; a library's own name is kept.

  ```toml
  [c.probe]
  name = "_probe_osx"
  sources = ["_probe_osx.c", "arch/all/errors.c", "arch/osx/cpu.c"]
  include = ["{lib}/cpython/include/python3.15"]
  defines = ["PROBE_POSIX=1", "PROBE_MACOS=1"]

  [c.probe.target.darwin]
  frameworks = ["CoreFoundation", "IOKit"]

  [extensions."probe/_probe_osx"]
  c = "probe"
  recorded = ["macos-aarch64"]
  ```

- **An npm tree with a `binding.gyp` is recorded by its node-gyp build**, npm's own, run in the
  tree with its packages installed (`neojac install` first). Each addon it links
  (`build/Release/<name>.node`) is traced as a Python project's module is. node-gyp builds
  against the toolchain's Node, whose headers are in `{lib}/node/include/node`, and fetches
  nothing for them; they are named as the toolchain's. node-gyp
  runs `make`, which the system has to have. A tree some of whose files `neojac port` made Jac
  is built in its laid tree ([A project's own suites](test.md#a-projects-own-suites)), where its
  scripts find what they found, and what the build made there is recorded as one run in the tree.
  The record stands in for every build file gyp read, as gyp's own Makefile lists them: each
  `.gyp` and `.gypi` of the tree it loaded moves aside with `binding.gyp`, so no file left in the
  tree names one that a port moved, and the next record puts them all back for its run.
- **An addon is where the build put it.** On Linux node-gyp links `build/Release/obj.target/<name>.node`
  and copies it to `build/Release/<name>.node`: the module is the copy nearest the tree's root,
  found by its bytes, so it has one path on every system.
- **A static library the link took is a C module of its own.** Each of its members is the object
  a recorded run compiled, found by its bytes, so whichever archiver made the library need not
  be neojac's (on macOS node-gyp uses the machine's `libtool`). The extension's row lists each
  such module in `links`, in the order of the link; recording again on another platform keeps the
  modules the row listed already, first.
- **A library loaded by its own convention is given its `exports`.** Where the library a recorded
  run linked defines none of its tree's entry points (no `PyInit_<name>` under a Python tree, not
  Node-API's pair under an npm tree), the row's `exports` lists the names the library exported
  that its own C module's objects define (a SQLite loadable extension's
  `["sqlite3_api", "sqlite3_extension_init"]`); recording again on another platform keeps the names
  the row listed already, first.
- **A C module's `headers` are the headers of its directory its build read**, written for each
  recorded platform under its `[target.<os>]` table, so that the module's interface on each
  platform is what that platform's build compiled against (`arch/osx/init.h` on macOS, never
  `arch/aix/init.h`); a header of a C module inside it is that module's
  ([C modules](../interop/c-modules.md#the-manifest)). A header under another C module the link
  took, or under a header library the build includes, is that module's, never the recorded
  module's own: a record on a second platform writes the tables the first wrote, though git
  tracks a header library's files there.
- **A header library a recorded build includes is a C module of the project too**, from an
  installed package as from the project's own files (node-addon-api's `napi.h`): a
  `[c."<directory>"]` table with its `headers` and no sources, and `language = "c++"` where its
  headers are C++ though they end in `.h` ([C modules](../interop/c-modules.md#c-sources)). The
  record names it after the module that includes it.
- **What a build compiled from a copy is recorded as the file of the project it is a copy of.**
  node-gyp compiles `sqlite3.c` from its build directory: the table names `deps/sqlite3`, and a
  header directory of such copies is the directory they were copied from. What is "of the
  project" is what was there before the build ran: what git does not ignore, where the project is
  git's, and otherwise every file of the tree as the build found it, so a copy with no `.git`
  records as its repository does. A file the build wrote again, or made (an amalgamation it
  extracts into `build/`), is the build's; a compiled file that is no copy of one of the
  project's is reported, and the module is not taken.
- **An option for the linker (`-Wl,...`) is the module's `ldflags`**
  ([C modules](../interop/c-modules.md#the-manifest)). What only says which system the build is
  for (`-arch`, `-mmacosx-version-min`), where it writes its dependency files (`-MMD`, `-MF`),
  and where it put its own output (`-L./Release`, a directory a recorded run made a file in) is
  not recorded, nor is an include directory that does not exist and from which the compile read
  nothing.

  ```toml
  [c.src]
  sources = ["kvstore.cpp"]
  include = ["{lib}/node/include/node", "../node_modules/node-addon-api", "../deps/sqlite3"]
  cxxflags = ["-O3", "-fvisibility=hidden", "-flto", "-std=c++20"]
  ldflags = ["-Wl,-search_paths_first", "-Wl,-dead_strip"]

  [c."deps/sqlite3"]
  sources = ["sqlite3.c"]
  defines = ["SQLITE_DQS=0", "SQLITE_ENABLE_FTS5"]

  [extensions."build/Release/kvstore"]
  c = "src"
  links = ["deps/sqlite3"]
  recorded = ["macos-aarch64"]
  ```

- **What a table cannot say is reported, and the module is not taken**: an object no recorded run
  compiled, a source or a header directory outside the project and the toolchain, a flag of the
  link that is none of a library, a framework or how an extension links, and a crate built with
  `--no-default-features` or `--all-features`.
- **The build's own leavings stay**: `build/`, `target/`, an `.egg-info`, which the repository's
  `.gitignore` usually names already. neojac adds `.jac/` to it.
- **It is a program of the repository that runs**, as it does under `pip install`: record a
  repository you would build.

#### A record is of one platform

A build compiles what its program decides for the system it runs on, so a record says what one
platform's build did: `macos-aarch64`, `linux-x86_64`. `neojac absorb --record`, run again on
another, adds that platform's record to the same tables.

```toml
[c.probe]                              # what every recorded platform compiles
sources = ["arch/all/errors.c", "arch/posix/init.c"]
include = ["{lib}/cpython/include/python3.15"]
defines = ["PROBE_POSIX=1"]

[c.probe.target.darwin]                # what macOS's build adds
sources = ["_probe_osx.c", "arch/osx/cpu.c"]
defines = ["PROBE_MACOS=1"]
frameworks = ["CoreFoundation", "IOKit"]

[c.probe.target.linux]                 # what Linux's adds
sources = ["_probe_linux.c", "arch/linux/mem.c"]
defines = ["PROBE_LINUX=1"]

[extensions."probe/_probe_osx"]
c = "probe"
recorded = ["macos-aarch64"]

[extensions."probe/_probe_linux"]
c = "probe"
recorded = ["linux-aarch64"]
```

- **Each extension module lists the platforms it was recorded on** (`recorded`), and is built
  on those. A build that links different modules on different systems, as `probe`'s does, has a
  table for each.
- **What every recorded platform's build compiled is the C module's own**, and what only some
  did is under a target table: an operating system's (`[target.linux]`), an architecture's
  (`[target.aarch64]`), or one platform's (`[target."linux.aarch64"]`), the narrowest that all
  of them share. The build reads them back as the same lists
  ([C modules](../interop/c-modules.md#the-manifest)).
- **Sources, header directories, defines, libraries and frameworks are shared one by one.** A
  list of arguments (`cflags`, `cxxflags`, `ldflags`) is shared only as far as every platform's
  begins alike, and the rest of each is its target's, so a platform's arguments are read back
  in the order its build gave them, repeats included.
- **`frameworks` are always macOS's**, under `[target.darwin]`.
- **Recording a platform again replaces its record** and leaves the others': a table is taken
  apart into each recorded platform's lists, and put together again with the new one.
- **A platform that is not recorded is refused** (E5172). The tables say nothing of what its
  build compiles; a source list that happens to hold for it is not known to.
- **An extension module built from a crate has one crate and one list of features.** A platform
  whose build links another is reported, and its table is left as it was.
- **A key a record does not write stays where it is**: an `export`, `archives` you added.

- **`--check` writes nothing.** It finds the trees, the data and the open items. It does not
  read the sources for their imports, so what the wires would say it does not judge.
- **`--json` prints the same as one document**: `trees` (each with its `ecosystem`, `directory`,
  `manifest`, `table`, `lock` and the tree it is a `member_of`), `data`, `open` (each with its
  `kind`, the file it is `at`, and what it `says`), `locks` (what of each other tool's lock is
  reproduced), and after an `absorb` that wrote, `wrote` and the count of `problems`.
- **A step that fails leaves every file as it was**: a manifest that cannot be taken whole
  (E5156, E5157) is refused, and nothing of the others stays written.
- **Absorbing again changes nothing**, and takes in what was added since.

A Python project `neojac absorb` takes in is installed for, built, tested and packed
([Building and testing a Python project](#building-and-testing-a-python-project)), and an npm
tree's addon is recorded, built and tested with the tree's suite. An npm package is not packed
yet, and no space holds one.

## What keeps the two in step

- **What neojac writes is `jac.toml` and `jac.lock`, and nothing else.** A tree's `package.json`
  holds what its table holds, in the order the table has it.
- **npm resolves, neojac records.** `jac.lock`'s `[npm."<directory>"]` is the lock npm wrote, key for key.
  Written back, it is the same file byte for byte.
- **What one side cannot hold is refused, never dropped.** JSON's `null` has no value in TOML
  (E5156), and TOML's dates, `inf` and `nan` have none in JSON (E5155).
- **A build checks what is installed.** A tree whose `node_modules` was not installed from
  `jac.toml` and `jac.lock` as they are now is E5160, and `neojac install` is the fix. It runs npm
  only for a tree that is not as pinned. A tree whose table names no package (no dependency
  table with an entry, and no `workspaces`) is ready with nothing installed, and a member of a
  workspace is ready as its workspace is.

## What goes wrong

| What neojac says | Why |
|---|---|
| `install: jac.toml declares no npm tree: name the directory of the one to make, --tree <directory> (eco/web, say)` | `--npm` in a project with no tree yet |
| `install: jac.toml declares the npm trees eco/web, eco/mobile: say which, --tree <directory>` | `--npm` in a project with several |
| `install: --tree names a directory of the project, and '../web' is outside it` | A tree is a directory of the project |
| `npm: jac.toml declares the npm trees eco/web, eco/mobile: run it in the directory of the one it is for` | `neojac npm` where no tree's directory is, in a project with several |
| `install --frozen: jac.lock pins nothing for the npm tree 'eco/web'; run neojac install` | `--frozen` before the tree was ever locked |
| E5155, E5156, E5157, E5158 | A value or a form one file cannot hold of the other: `neojac docs E5156`. E5157 is also a `Cargo.toml` or `cmodule.toml` whose text cannot be moved under a table's name as it is |
| E5159 | A workspace npm finds that `jac.toml` holds no table for: `neojac absorb` of the root's directory |
| E5160 | A tree not installed as pinned: `neojac install` |
| E5161 | A package that is not installed as a declaration asks: one declared by a version that is not in `eco/jac/`, or one from a repository that is not fetched (`neojac install`) |
| E5162 | Two askers of one npm package, at different ranges |
| E5163, E5164, E5165 | An installed package with no record of what installed it, a record or a `jac.lock` of another format, and a package another installer put where `neojac install` is asked to fetch one |
| E5166 | An installed package that is not what `jac.lock` pins: its files changed, or under `--frozen` its version or where it came from |
| E5167 | A Python project built or tested with no `[wheel."<directory>"]`: `neojac absorb --record` |
| E5168 | `[wheel."<directory>"]` lists a file the project no longer has |
| E5169 | `neojac build` given a `pyproject.toml` that `jac.toml` holds no `[pypi."<directory>"]` for |
| E5172 | A build on a platform none of the project's extension modules is `recorded` for |
| E5170 | A `workspace:` link to a package that is no tree of the same workspace |
| E5171 | A `workspace:` link in a form npm is given no range for: a path, an alias |
| `install --frozen: jac.lock pins nothing for the package 'units' as jac.toml asks for it; run neojac install` | `--frozen` after `jac.toml` came to ask for a package, or for another `git` or `rev` of one |
| E2216, E2219, E2220, E2221, E2222 | A package that is not where it is declared or is neither a library nor a plugin, a library imported that the package does not declare, a declaration that does not hold of the copy the program holds (another place, or a version that does not satisfy it), a library or a plugin that declares or binds a plugin, a library whose name the project's tree also has: `neojac docs E2219` |
| E2226, E2227, E2228, E2229 | A `[libraries]` or a `[plugins]` table, a plugin a project declares and never uses, a version or a requirement that is not one, a package that needs a later neojac |
| E2217, E2233 | A package that declares an abstraction; a plugin, or a library a plugin declares, that imports a module of stdjac or the contract of an abstraction it does not fill |
| E1287, E1288 | A space's tree is not declared, or not named among several |
