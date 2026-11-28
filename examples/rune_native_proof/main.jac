import from native { rune_check }

obj Handler {
    has call: Callable[[], int];
}

def dispatch(context: ptr) -> int {
    return held[Handler](context).call();
}

with entry {
    captured = 41;
    context = hold(Handler(call=lambda -> int { return captured + 1; }));
    try {
        result = rune_check(context, dispatch);
        if result != 42 {
            raise RuntimeError(f"Native Rune callback returned {result}, expected 42");
        }
        print("native_baseline_passed callback=42");
    } finally {
        release(context);
    }
}
