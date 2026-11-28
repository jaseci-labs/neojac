extern "C" fn answer(_: *mut std::ffi::c_void) -> i64 {
    42
}

fn main() {
    if std::env::args().any(|argument| argument == "--snap") {
        rune_actual_probe::run_app();
        return;
    }
    assert_eq!(rune_actual_probe::rune_check(std::ptr::null_mut(), answer), 42);
    println!("Rune + rune-kit: layout and retained click handler passed");
}
