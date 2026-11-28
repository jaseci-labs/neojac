# Verification record

Verified on Linux x86_64 on 2026-11-26 with neojac 0.5.3
(build 4da9bcccf875), using the pins in inputs.json.

- Pinned static XKB preparation: passed, including a fresh compiler-fingerprinted build.
- `python3 verify.py --neojac <compiler> --snapshot`: passed.
- Rust and Jac stdout matched exactly:
  ```text
  center_before=(60.0, 48.25); state=false
  center_after=(60.0, 48.25); state=true
  native_baseline_passed callback=42
  ```
- Retained callback executable:
  `ownership_baseline_passed registrations=8 releases=8 late_rejected=8`.
- Offscreen rendering: valid 640×480 PNG, visually inspected. SHA256:
  `2dc213a671abd1aa34ba2f46ee78e08a6f003054a105fe5fc0a31a8d4ca0d99a`.
- Both Jac files passed `neojac fmt --fix --check`.
- Both Python tools passed bytecode compilation.
- Read-only review completed; compiler cache isolation and PNG validation findings fixed.

The development executable requires its emitted `libneojac-rust-*.so` companion
beside it ($ORIGIN runpath). It does not use the historical probe shared library.
This is native Rust-module integration, not a verified single-file distribution.

The full repository check with this pinned release reports seven failures in
existing docs, formatting and stdjac modules. A clean checkout of base
3f8a290d7f71df41f117aae9a7b9ce948b41318b reproduced the identical seven
failure categories (81 checks, seven failed, nine left out). No unrelated source files were changed.

General typed Jac tree construction, automatic shutdown/foreign-thread cleanup,
foreign-wait runtime entry, an interactive Jac window and a release build remain
unverified. See upstream compiler issue #91 and milestone #90. This slice closes
neither issue.
