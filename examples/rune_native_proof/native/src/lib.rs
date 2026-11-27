//! Native linking baseline. General typed bindings and ownership are separate gates.

use std::ffi::c_void;

use rune::{AppSpec, Cx, El, Env, Runtime, col, el, text};

#[derive(Default)]
struct State {
    on: bool,
    context: *mut c_void,
    callback: Option<extern "C" fn(*mut c_void) -> i64>,
    received: i64,
    retained: Option<std::rc::Rc<Callback>>,
}

fn view(state: &State, _: &mut Cx<State>) -> El {
    let theme = rune::tok::theme(true);
    let retained = state.retained.clone();
    col()
        .w_full()
        .h_full()
        .gap(12.0)
        .fill(theme.bg)
        .child(text(if state.on { "Rune: on" } else { "Rune: off" }).color(theme.text))
        .child(
            el().key("switch")
                .label("Toggle")
                .size(120.0, 40.0)
                .center()
                .fill(rune::tok::accent(0, true))
                .child(text("Toggle").color(theme.text))
                .on_press(move |state: &mut State| {
                    state.on = !state.on;
                    if let Some(callback) = &retained {
                        state.received = callback.fire();
                    } else if let Some(callback) = state.callback {
                        state.received = callback(state.context);
                    }
                }),
        )
        .child(
            rune_kit::Switch::new(state.on)
                .label("Rune-kit switch")
                .build(&rune_kit::Kit::neutral(true)),
        )
}

fn check(context: *mut c_void, callback: extern "C" fn(*mut c_void) -> i64) -> i64 {
    let state = State {
        context,
        callback: Some(callback),
        ..State::default()
    };
    let mut runtime = Runtime::new(state, view, (320.0, 240.0), Env::new(true, 1.0));
    runtime.frame(0.0);
    println!(
        "center_before={:?}; state=false",
        runtime.find("switch").expect("switch layout")
    );
    let (x, y) = runtime.find("switch").expect("switch was laid out");
    runtime.pointer_down(x, y);
    runtime.pointer_up(x, y);
    runtime.frame(1.0 / 60.0);
    assert!(runtime.state.on, "retained input handler must update state");
    println!(
        "center_after={:?}; state=true",
        runtime.find("switch").expect("switch layout")
    );
    runtime.state.received
}

/// The caller owns the callback context until this synchronous function returns.
/// The Rune runtime and all of its retained closures are dropped before return.
#[unsafe(no_mangle)]
pub extern "C" fn rune_check(
    context: *mut c_void,
    callback: extern "C" fn(*mut c_void) -> i64,
) -> i64 {
    std::panic::catch_unwind(|| check(context, callback)).unwrap_or(-1)
}

pub fn run_app() {
    rune::run(AppSpec::new(
        "Jac/Rune native baseline",
        (320.0, 240.0),
        State::default,
        view,
    ));
}

use std::{
    cell::RefCell,
    collections::HashMap,
    rc::Rc,
    sync::atomic::{AtomicU64, Ordering},
};
pub(crate) struct Callback {
    context: *mut c_void,
    fire: extern "C" fn(*mut c_void) -> i64,
    release: extern "C" fn(*mut c_void),
}
impl Callback {
    pub(crate) fn fire(&self) -> i64 {
        (self.fire)(self.context)
    }
}
impl Drop for Callback {
    fn drop(&mut self) {
        (self.release)(self.context);
    }
}
thread_local! {
    static WINDOWS: RefCell<HashMap<i64, Runtime<State>>> = RefCell::new(HashMap::new());
}
static NEXT_ID: AtomicU64 = AtomicU64::new(1);

/// Transfers one held context to a UI-thread-owned registration, even on failure.
/// Both callbacks must contain their own exceptions and must not unwind.
#[unsafe(no_mangle)]
pub extern "C" fn retained_open(
    context: *mut c_void,
    fire: extern "C" fn(*mut c_void) -> i64,
    release: extern "C" fn(*mut c_void),
) -> i64 {
    let callback = Rc::new(Callback {
        context,
        fire,
        release,
    });
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let raw = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let id = i64::try_from(raw).expect("registration IDs exhausted");
        let mut runtime = Runtime::new(
            State {
                retained: Some(callback),
                ..State::default()
            },
            view,
            (320.0, 240.0),
            Env::new(true, 1.0),
        );
        runtime.frame(0.0);
        WINDOWS.with(|windows| {
            windows.borrow_mut().insert(id, runtime);
        });
        id
    }))
    .unwrap_or(-1)
}

/// Missing, closed, and other-thread handles reject without reading a Jac pointer.
#[unsafe(no_mangle)]
pub extern "C" fn retained_click(id: i64) -> i64 {
    std::panic::catch_unwind(|| {
        // Remove before dispatch so reentrant operations cannot borrow the registry.
        let Some(mut runtime) = WINDOWS.with(|windows| windows.borrow_mut().remove(&id)) else {
            return -2;
        };
        let (x, y) = runtime.find("switch").expect("switch layout");
        runtime.pointer_down(x, y);
        runtime.pointer_up(x, y);
        runtime.frame(1.0 / 60.0);
        let result = runtime.state.received;
        WINDOWS.with(|windows| {
            windows.borrow_mut().insert(id, runtime);
        });
        result
    })
    .unwrap_or(-1)
}

/// Must run on the registering UI thread before the Jac runtime retires.
#[unsafe(no_mangle)]
pub extern "C" fn retained_close(id: i64) -> i64 {
    std::panic::catch_unwind(|| {
        let runtime = WINDOWS.with(|windows| windows.borrow_mut().remove(&id));
        if runtime.is_none() {
            return -2;
        }
        drop(runtime); // final closure/state owner releases the Jac hold here
        0
    })
    .unwrap_or(-1)
}
