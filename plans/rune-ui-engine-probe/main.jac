import dl;
import sys;

obj Handler {
    has call: Callable[[], int];
}

def dispatch(context: ptr) -> int {
    return held[Handler](context).call();
}

with entry {
    if len(sys.argv) != 2 {
        raise ValueError("Pass the path of librune_actual_probe.so");
    }
    library = dl.open(sys.argv[1]);
    run = Callable[[ptr, Callable[[ptr], int]], int](library.symbol("rune_check"));
    captured = 41;
    context = hold(Handler(call=lambda -> int { return captured + 1; }));
    try {
        result = run(context, dispatch);
        if result != 42 {
            raise RuntimeError(f"Rune callback returned {result}, expected 42");
        }
        print("Rune callback reached Jac:", result);
    } finally {
        release(context);
        library.close();
    }
}
