//! Research fixture: real Rune layout, input, rune-kit and a retained ABI callback.
//! This is not a Jac JSX backend or a complete application integration.

use std::ffi::c_void;

use rune::{AppSpec, Cx, El, Env, Runtime, col, el, text};

#[derive(Default)]
struct State {
    on: bool,
    context: *mut c_void,
    callback: Option<extern "C" fn(*mut c_void) -> i64>,
    received: i64,
}

fn view(state: &State, _: &mut Cx<State>) -> El {
    let theme = rune::tok::theme(true);
    col()
        .w_full()
        .h_full()
        .gap(12.0)
        .fill(theme.bg)
        .child(text(if state.on { "Rune: on" } else { "Rune: off" }).color(theme.text))
        .child(
            el()
                .key("switch")
                .label("Toggle")
                .size(120.0, 40.0)
                .center()
                .fill(rune::tok::accent(0, true))
                .child(text("Toggle").color(theme.text))
                .on_press(|state: &mut State| {
                    state.on = !state.on;
                    if let Some(callback) = state.callback {
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
    let state = State { context, callback: Some(callback), ..State::default() };
    let mut runtime = Runtime::new(state, view, (320.0, 240.0), Env::new(true, 1.0));
    runtime.frame(0.0);
    let (x, y) = runtime.find("switch").expect("switch was laid out");
    runtime.pointer_down(x, y);
    runtime.pointer_up(x, y);
    runtime.frame(1.0 / 60.0);
    assert!(runtime.state.on, "retained input handler must update state");
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
    rune::run(AppSpec::new("Rune interop probe", (320.0, 240.0), State::default, view));
}
