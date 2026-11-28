#!/usr/bin/env python3
"""Probe the native interop patterns needed by the Rune UI plan, without Rune.

Requires an installed neojac. Creates and removes temporary standalone projects.
These probes establish binding/lifetime patterns, not actual Rune compatibility.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


BUILDERS_RS = """pub struct Element { label: String, children: usize }
pub fn element() -> Element { Element { label: String::new(), children: 0 } }
impl Element {
    pub fn child(mut self, _: Element) -> Element { self.children += 1; self }
    pub fn count(&self) -> usize { self.children }
    pub fn label(mut self, s: impl Into<String>) -> Element {
        self.label = s.into(); self
    }
    pub fn label_str(mut self, s: &str) -> Element {
        self.label = s.to_string(); self
    }
    pub fn title(&self) -> &str { &self.label }
    pub fn keep(self, f: impl Fn() -> i64 + 'static) -> Saved {
        Saved { el: self, f: Box::new(f) }
    }
}
pub struct Saved { el: Element, f: Box<dyn Fn() -> i64> }
impl Saved {
    pub fn fire(&self) -> i64 { (self.f)() + self.el.children as i64 }
}
"""

CALLBACK_RS = """use std::ffi::c_void;
pub struct Action {
    context: *mut c_void,
    fire: extern "C" fn(*mut c_void) -> i64,
}
#[unsafe(no_mangle)]
pub extern "C" fn action_new(
    context: *mut c_void, fire: extern "C" fn(*mut c_void) -> i64,
) -> *mut Action {
    Box::into_raw(Box::new(Action { context, fire }))
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_fire(a: *const Action) -> i64 {
    let a = unsafe { &*a };
    (a.fire)(a.context)
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_free(a: *mut Action) {
    drop(unsafe { Box::from_raw(a) });
}
"""

BUILDERS_JAC = """import from native { element }
with entry {
    e = element().child(element()).label_str("Rune-like builder");
    print(e.count(), e.title());
}
"""

INTO_JAC = """import from native { element }
with entry { e = element().label("label"); print(e.title()); }
"""

RETAINED_JAC = """import from native { element }
with entry {
    n = 7;
    s = element().keep(lambda -> int { return n; });
    print(s.fire());
}
"""

CALLBACK_JAC = """import from adapter { action_new, action_fire, action_free }
obj Handler { has call: Callable[[], int]; }
def dispatch(context: ptr) -> int { return held[Handler](context).call(); }
with entry {
    n = 41;
    context = hold(Handler(call=lambda -> int { return n + 1; }));
    action = action_new(context, dispatch);
    print(action_fire(action));
    action_free(action);
    release(context);
}
"""

LOCK_RS = """use std::{ffi::c_void, time::Duration};
#[unsafe(no_mangle)]
pub extern "C" fn after_sleep(
    ctx: *mut c_void, callback: extern "C" fn(*mut c_void) -> i64,
) -> i64 {
    std::thread::sleep(Duration::from_millis(250));
    callback(ctx)
}
"""

LOCK_JAC = """import threading;
import time;
import from adapter { after_sleep }
glob ready: threading.Event = threading.Event();
obj State { has value: int = 0; }
def read_state(ctx: ptr) -> int { return held[State](ctx).value; }
def work(state: State) { ready.set(); time.sleep(0.02); state.value = 1; }
with entry {
    state = State();
    ctx = hold(state);
    worker = threading.Thread(target=work, args=(state,));
    worker.start(); ready.wait();
    print("worker_progress_during_rust_wait", after_sleep(ctx, read_state));
    worker.join(); print("worker_after_join", state.value);
    release(ctx);
}
"""


def write_crate(project, name, source):
    crate = project / name
    (crate / "src").mkdir(parents=True)
    (crate / "Cargo.toml").write_text(
        f'[package]\nname = "{name}"\nversion = "0.1.0"\nedition = "2024"\n'
    )
    (crate / "src/lib.rs").write_text(source)


def run(command, cwd, timeout):
    result = subprocess.run(
        command, cwd=cwd, capture_output=True, text=True, timeout=timeout
    )
    return {
        "exit_code": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def build_and_run(neojac, project, name, expected, timeout):
    executable = project / (name + (".exe" if os.name == "nt" else ""))
    build = run([neojac, "build", f"{name}.jac", "-o", str(executable)], project, timeout)
    result = {"build": build, "status": "failed"}
    if build["exit_code"] != 0:
        return result
    execution = run([str(executable)], project, timeout)
    result["run"] = execution
    if execution["exit_code"] == 0 and execution["stdout"] == expected:
        result["status"] = "supported"
    return result


def binding_probe(neojac, project, name, method, expected, timeout):
    check = run([neojac, "check", f"{name}.jac"], project, timeout)
    result = {"check": check, "status": "failed"}
    if check["exit_code"] == 0:
        result.update(build_and_run(neojac, project, name, expected, timeout))
        return result
    diagnostic = check["stdout"] + "\n" + check["stderr"]
    if "error[E1030]" in diagnostic and f"has no method '{method}'" in diagnostic:
        result["status"] = "binding_gap"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--neojac", default="neojac")
    parser.add_argument("--timeout", type=int, default=240, help="Seconds per subprocess")
    parser.add_argument("--report", type=Path, help="Optional JSON evidence file")
    args = parser.parse_args()
    neojac = shutil.which(args.neojac)
    if neojac is None:
        parser.error(f"neojac executable not found: {args.neojac}")

    report = {"scope": "Standalone Rust interop patterns; does not build Rune", "probes": {}}
    with tempfile.TemporaryDirectory(prefix="neojac-rune-interop-") as directory:
        root = Path(directory)
        report["compiler"] = run([neojac, "version"], root, args.timeout)
        builders = root / "builders"
        builders.mkdir()
        write_crate(builders, "native", BUILDERS_RS)
        for name, source in [
            ("builders", BUILDERS_JAC), ("into", INTO_JAC), ("retained", RETAINED_JAC)
        ]:
            (builders / f"{name}.jac").write_text(source)
        probes = report["probes"]
        probes["owned_builders_and_borrowed_text"] = build_and_run(
            neojac, builders, "builders", "1 Rune-like builder", args.timeout
        )
        probes["impl_into_string"] = binding_probe(
            neojac, builders, "into", "label", "label", args.timeout
        )
        probes["retained_rust_closure"] = binding_probe(
            neojac, builders, "retained", "keep", "7", args.timeout
        )
        callbacks = root / "callbacks"
        callbacks.mkdir()
        write_crate(callbacks, "adapter", CALLBACK_RS)
        (callbacks / "callback.jac").write_text(CALLBACK_JAC)
        probes["retained_callback_with_held_jac_closure"] = build_and_run(
            neojac, callbacks, "callback", "42", args.timeout
        )

        reexports = root / "reexports"
        reexports.mkdir()
        write_crate(
            reexports, "dep",
            "pub struct Element { n: i64 }\n"
            "pub fn el() -> Element { Element { n: 5 } }\n"
            "impl Element { pub fn count(&self) -> i64 { self.n } }\n",
        )
        write_crate(reexports, "native", "pub use dep::{el, Element};\n")
        with (reexports / "native/Cargo.toml").open("a") as manifest:
            manifest.write('[dependencies]\ndep = { path = "../dep" }\n')
        (reexports / "reexports.jac").write_text(
            "import from native { el }\nwith entry { print(el().count()); }\n"
        )
        check = run([neojac, "check", "reexports.jac"], reexports, args.timeout)
        result = {"check": check, "status": "failed"}
        if check["exit_code"] == 0:
            result.update(build_and_run(neojac, reexports, "reexports", "5", args.timeout))
        elif "error[E1145]" in check["stderr"] and "has no 'el'" in check["stderr"]:
            result["status"] = "binding_gap"
        probes["public_rust_reexports"] = result

        transitive = root / "transitive"
        transitive.mkdir()
        write_crate(
            transitive, "dep",
            "#[derive(Clone, Copy)]\npub struct Color { red: f32 }\n"
            "pub fn color() -> Color { Color { red: 0.5 } }\n"
            "impl Color { pub fn red(&self) -> f32 { self.red } }\n",
        )
        write_crate(transitive, "native", "pub fn color() -> dep::Color { dep::color() }\n")
        with (transitive / "native/Cargo.toml").open("a") as manifest:
            manifest.write('[dependencies]\ndep = { path = "../dep" }\n')
        (transitive / "transitive.jac").write_text(
            "import from native { color }\nwith entry { print(color().red()); }\n"
        )
        result = build_and_run(neojac, transitive, "transitive", "0.5", args.timeout)
        diagnostic = result["build"]["stdout"] + result["build"]["stderr"]
        if "error[E5190]" in diagnostic and "error[E0433]" in diagnostic:
            result["status"] = "transitive_type_shim_gap"
        probes["transitive_rust_value_type"] = result

        locking = root / "locking"
        locking.mkdir()
        write_crate(locking, "adapter", LOCK_RS)
        (locking / "locking.jac").write_text(LOCK_JAC)
        result = build_and_run(
            neojac, locking, "locking",
            "worker_progress_during_rust_wait 0\nworker_after_join 1", args.timeout,
        )
        if result["status"] == "supported":
            result["status"] = "runtime_lock_gap"
        elif result.get("run", {}).get("exit_code") == 0 and result["run"]["stdout"] == (
            "worker_progress_during_rust_wait 1\nworker_after_join 1"
        ):
            result["status"] = "worker_progress_supported"
        probes["jac_worker_during_blocking_rust_call"] = result

    for name, result in probes.items():
        print(f"{name}: {result['status']}", flush=True)
    print(report["compiler"]["stdout"], flush=True)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"Evidence: {args.report}")
    return int(report["compiler"]["exit_code"] != 0 or any(
        result["status"] == "failed" for result in probes.values()
    ))


if __name__ == "__main__":
    raise SystemExit(main())
