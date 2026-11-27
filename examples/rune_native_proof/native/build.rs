fn main() {
    println!("cargo:rerun-if-env-changed=RUNE_PROBE_XKB_LIB_DIR");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("linux") {
        let directory = std::env::var("RUNE_PROBE_XKB_LIB_DIR")
            .expect("Set RUNE_PROBE_XKB_LIB_DIR to the neojac-built libxkbcommon.a directory");
        println!("cargo:rustc-link-search=native={directory}");
        println!("cargo:rustc-link-lib=static=xkbcommon");
        println!("cargo:rerun-if-changed=compat.c");
        cc::Build::new()
            .file("compat.c")
            .compile("neojac_rune_compat");
    }
}
