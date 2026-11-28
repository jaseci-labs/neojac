"""Check what this repository holds with a released neojac: the one that runs
this script.

    neojac python -I scripts/check.py

It is what the Release check workflow runs on every pull request, with the
latest release; run it the same way, from anywhere, with the neojac you have
installed. It runs, one after another, and reports each:

1. The pages: `neojac docs --check`, with NEOJAC_STORE naming a directory that
   holds this checkout's docs/ and nothing else, so that neojac reads them in
   place of the pages it carries.
2. The layout: `neojac fmt --fix --check` of abstractions/, stdjac/,
   libraries/ and examples/, which lists each file the fixer would change: its
   layout, or a rule its project keeps.
3. Each package of abstractions/, stdjac/ and libraries/ (a directory holding
   a jac.toml): `neojac arch`, which holds every module of it, Jac or
   JavaScript, to its archwire.jac, and `neojac check` of each of its Jac
   modules, but those its jac.toml's [check] exclude names: a plugin's check
   holds it to what it may import.
4. Each example: `neojac check` of each of its spaces, or of each of its
   modules where it declares none.
5. The tests of each package and example that holds any: `neojac test`.

What it leaves out, it says, each with the reason.

What it cannot reach: neojac reads `rt/`, `abstractions/` and `libraries/`
from NEOJAC_STORE only all three together, and a release gives no way to have
its own `rt/` beside this checkout's other two. So a package's modules are
checked against the contracts the release carries, not this checkout's, and
an example is checked with the release's stdjac, abstractions, standard
plugins and libraries. A package's own modules, and the libraries it declares
by their place, are this checkout's.
"""

import fnmatch
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE_TREES = ["abstractions", "stdjac", "libraries"]
EXAMPLES = "examples"
LAID_OUT = PACKAGE_TREES + [EXAMPLES]

# The modules this check does not check, by their path, and the tests it does
# not run, by the directory that holds them, each with the reason.
NODE_CRATES = (
    "the latest release takes Node's crates, which it reaches, for modules of stdjac (E2231), "
    "as it does checking the copy of stdjac it carries"
)
MODULES_LEFT_OUT = {
    "stdjac/cpython_space.jac": "a CPython space's host, which the latest release checks in "
    "place only as the copy of stdjac it carries, in its runtime: read from here it refuses it (E5090)",
    "stdjac/crossing.jac": NODE_CRATES,
    "stdjac/node_space.jac": NODE_CRATES,
    "stdjac/page_files.jac": NODE_CRATES,
}
TESTS_LEFT_OUT = {
    "examples/jaclang_org": "they take about forty minutes of a processor's time, far more than "
    "this check's few minutes, and do not all build and pass against the latest release yet",
}


class Job:
    """One run of neojac: what it checks, the directory it runs in, its
    arguments, and whether it reads this checkout's pages."""

    def __init__(self, what, at, args, pages=False):
        self.what = what
        self.at = at
        self.args = args
        self.pages = pages


def neojac():
    """The neojac to check with: the one `neojac python` sets NEOJAC_EXE to,
    else the one on PATH."""
    named = os.environ.get("NEOJAC_EXE") or shutil.which("neojac")
    if not named:
        sys.exit("check: no neojac: run this as `neojac python -I scripts/check.py`")
    return named


def kept(names):
    """`names` but what neojac leaves in a project (`.jac/`) and the npm trees
    it installs."""
    return sorted(d for d in names if not d.startswith(".") and d != "node_modules")


def projects(tree):
    """Each directory under `tree` that holds a jac.toml, from the root."""
    found = []
    for at, dirs, files in os.walk(os.path.join(ROOT, tree)):
        dirs[:] = kept(dirs)
        if "jac.toml" in files:
            found.append(os.path.relpath(at, ROOT))
    return found


def modules(d):
    """The Jac modules at the top of directory `d`, from the root, that its
    jac.toml's [check] exclude does not name: each file `<name>.jac` but
    archwire.jac. A file whose name has another dot is an annex of a module
    (`store.impl.jac`, `store.test.jac`) or its file for one target
    (`window.linux.jac`), which a check of the module reads."""
    with open(os.path.join(ROOT, d, "jac.toml"), "rb") as f:
        excluded = tomllib.load(f).get("check", {}).get("exclude", [])
    return sorted(
        name
        for name in os.listdir(os.path.join(ROOT, d))
        if name.endswith(".jac")
        and "." not in name.removesuffix(".jac")
        and name != "archwire.jac"
        and not any(fnmatch.fnmatchcase(name, pattern) for pattern in excluded)
        and os.path.isfile(os.path.join(ROOT, d, name))
    )


def has_tests(d):
    for _, dirs, files in os.walk(os.path.join(ROOT, d)):
        dirs[:] = kept(dirs)
        if any(f.endswith(".test.jac") for f in files):
            return True
    return False


def spaces(n, d):
    """The spaces the archwire.jac of example `d` declares, each with what
    its check needs that a runner does not have, or "". None where neojac
    cannot say, with what it said."""
    if not os.path.isfile(os.path.join(ROOT, d, "archwire.jac")):
        return [], ""
    drawn = subprocess.run(
        [n, "arch", "--view", "spaces", "--json"],
        cwd=os.path.join(ROOT, d),
        capture_output=True,
        text=True,
    )
    if drawn.returncode != 0:
        return None, drawn.stdout + drawn.stderr
    with open(os.path.join(ROOT, d, "jac.toml"), "rb") as f:
        settings = tomllib.load(f).get("spaces", {})
    out = []
    for box in json.loads(drawn.stdout)["boxes"]:
        if box["kind"] == "space":
            tree = settings.get(box["name"], {}).get("npm", "")
            needs = (
                f"its check needs the npm tree {tree}, which `neojac install` fetches from the npm registry"
                if tree
                else ""
            )
            out.append((box["name"], needs))
    return out, ""


def planned(n):
    """Every run of neojac this check makes, in order, what it leaves out,
    and what it could not plan."""
    out = [
        Job("docs: neojac docs --check, of this checkout's pages", ".", ["docs", "--check"], pages=True),
        Job(f"layout: neojac fmt --fix --check {' '.join(LAID_OUT)}", ".", ["fmt", "--fix", "--check"] + LAID_OUT),
    ]
    left = []
    unplanned = []
    packages = [d for tree in PACKAGE_TREES for d in projects(tree)]
    examples = projects(EXAMPLES)
    for d in packages:
        if os.path.isfile(os.path.join(ROOT, d, "archwire.jac")):
            out.append(Job(f"{d}: neojac arch", d, ["arch", "--text"]))
        for m in modules(d):
            module = f"{d}/{m}"
            if module in MODULES_LEFT_OUT:
                left.append((module, MODULES_LEFT_OUT[module]))
            else:
                out.append(Job(f"{d}: neojac check {m}", d, ["check", m]))
    for d in examples:
        declared, said = spaces(n, d)
        if declared is None:
            unplanned.append((f"{d}: neojac arch --view spaces --json", said))
        elif len(declared) > 0:
            for name, needs in declared:
                if needs:
                    left.append((f"{d}: the space {name}", needs))
                else:
                    out.append(Job(f"{d}: neojac check --space {name}", d, ["check", "--space", name]))
        else:
            for m in modules(d):
                out.append(Job(f"{d}: neojac check {m}", d, ["check", m]))
    for d in packages + examples:
        if not has_tests(d):
            continue
        if d in TESTS_LEFT_OUT:
            left.append((f"{d}: its tests", TESTS_LEFT_OUT[d]))
        else:
            out.append(Job(f"{d}: neojac test", d, ["test"]))
    return out, left, unplanned


def run(n, job, pages_store):
    """Whether `job` passed, how long it took, and what it said."""
    env = os.environ.copy()
    if job.pages:
        env["NEOJAC_STORE"] = pages_store
        placed = subprocess.run([n, "docs", "--path"], env=env, capture_output=True, text=True)
        where = placed.stdout.strip()
        if placed.returncode != 0 or os.path.realpath(where) != os.path.realpath(os.path.join(ROOT, "docs")):
            said = f"neojac reads its pages at {where or 'no directory'}, not this checkout's docs/\n"
            return False, 0.0, said + placed.stderr
    began = time.monotonic()
    ran = subprocess.run([n] + job.args, cwd=os.path.join(ROOT, job.at), env=env, capture_output=True, text=True)
    took = time.monotonic() - began
    said = ran.stderr if job.args[0] == "arch" else ran.stdout + ran.stderr
    return ran.returncode == 0, took, said


def main():
    if len(sys.argv) != 1:
        sys.exit("usage: neojac python -I scripts/check.py")
    n = neojac()
    version = subprocess.run([n, "--version"], capture_output=True, text=True).stdout.strip()
    print(f"check: {version}, at {n}", flush=True)
    began = time.monotonic()
    jobs, left, unplanned = planned(n)
    failed = []
    for what, said in unplanned:
        print(f"FAIL  {what}\n      " + said.rstrip("\n").replace("\n", "\n      "), flush=True)
        failed.append(what)
    with tempfile.TemporaryDirectory(prefix="neojac-check-") as pages_store:
        os.symlink(os.path.join(ROOT, "docs"), os.path.join(pages_store, "docs"))
        for job in jobs:
            ok, took, said = run(n, job, pages_store)
            print(f"{'ok  ' if ok else 'FAIL'}  {job.what} ({took:.1f}s)", flush=True)
            if not ok:
                failed.append(job.what)
                print("      " + said.rstrip("\n").replace("\n", "\n      "), flush=True)
    for what, why in left:
        print(f"left out  {what}: {why}")
    total = time.monotonic() - began
    ran = len(jobs) + len(unplanned)
    print(f"check: {ran} checks, {len(failed)} failed, {len(left)} left out, in {total:.0f}s")
    for what in failed:
        print(f"failed  {what}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(f"### Checked with {version}\n\n{ran} checks, {len(failed)} failed, in {total:.0f}s.\n\n")
            f.writelines(f"- failed: {what}\n" for what in failed)
            f.writelines(f"- left out: {what}: {why}\n" for what, why in left)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
