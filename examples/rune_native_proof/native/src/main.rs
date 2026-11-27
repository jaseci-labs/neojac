extern "C" fn answer(_: *mut std::ffi::c_void) -> i64 {
    42
}
fn main() {
    if std::env::args().any(|arg| arg == "--window" || arg == "--snap") {
        rune_native_proof::run_app();
        return;
    }
    assert_eq!(
        rune_native_proof::rune_check(std::ptr::null_mut(), answer),
        42
    );
    println!("native_baseline_passed callback=42");
}
