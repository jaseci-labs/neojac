import from native { retained_open, retained_click, retained_close }

glob released: int = 0;

obj Handler {
    has call: Callable[[], int];
}

def dispatch(context: ptr) -> int {
    try {
        return held[Handler](context).call();
    } except Exception {
        return -10;
    }
}

def drop_context(context: ptr) {
    release(context);
    released += 1;
}

def register -> int {
    captured = 41;
    return retained_open(
        hold(Handler(call=lambda -> int { return captured + 1; })), dispatch, drop_context
    );
}

with entry {
    for cycle in range(8) {
        id = register();
        if id <= 0 {
            raise RuntimeError("registration failed");
        }
        try {
            if released != cycle {
                raise RuntimeError("context released before dispatch");
            }
            if retained_click(id) != 42 {
                raise RuntimeError("retained callback failed");
            }
        } finally {
            if retained_close(id) != 0 {
                raise RuntimeError("close failed");
            }
        }
        if released != cycle + 1 {
            raise RuntimeError("final owner did not release context");
        }
        if retained_click(id) != -2 {
            raise RuntimeError("late callback accepted");
        }
        if retained_close(id) != -2 {
            raise RuntimeError("duplicate close accepted");
        }
    }
    print("ownership_baseline_passed registrations=8 releases=8 late_rejected=8");
}
