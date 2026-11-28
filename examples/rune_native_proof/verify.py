#!/usr/bin/env python3
"""Verify the native linking baseline; does not certify all #90 gates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import zlib


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--neojac", default="neojac")
    parser.add_argument("--snapshot", action="store_true")
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    artifacts = root / "artifacts"
    artifacts.mkdir(exist_ok=True)
    report = {"scope": "bounded native linking and retained callback proof", "status": "failed", "commands": []}

    def run(name, command):
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=args.timeout)
        (artifacts / (name + ".stdout")).write_text(result.stdout)
        (artifacts / (name + ".stderr")).write_text(result.stderr)
        report["commands"].append({"name": name, "argv": command, "exit_code": result.returncode})
        if result.returncode:
            error_path = artifacts / (name + ".stderr")
            raise RuntimeError(f"{name} failed ({result.returncode}); see {error_path}")
        return result.stdout

    try:
        neojac = shutil.which(args.neojac)
        if neojac is None:
            raise RuntimeError(f"neojac not found: {args.neojac}")
        if not Path(os.environ.get("RUNE_PROBE_XKB_LIB_DIR", "") , "libxkbcommon.a").is_file():
            raise RuntimeError("RUNE_PROBE_XKB_LIB_DIR must contain neojac-built libxkbcommon.a")
        version = run("version", [neojac, "version"]).strip()
        report["compiler"] = version
        if "0.5.3" not in version or "4da9bcccf875" not in version:
            raise RuntimeError(f"Unexpected compiler: {version}; update pairing evidence explicitly")
        rust = run("rust-reference", [neojac, "cargo", "run", "--locked", "--manifest-path", "native/Cargo.toml"])
        executable = artifacts / "jac-rune-baseline"
        run("jac-build", [neojac, "build", "main.jac", "-o", str(executable)])
        jac = run("jac-reference", [str(executable)])
        if rust != jac or "native_baseline_passed callback=42" not in jac:
            raise RuntimeError("Jac/Rust layout or callback evidence differs")
        dependencies = run("elf-dependencies", ["readelf", "-d", str(executable)])
        if "librune_actual_probe" in dependencies:
            raise RuntimeError("Executable depends on the historical shared-library probe")
        ownership_exe = artifacts / "jac-rune-ownership"
        run("ownership-build", [neojac, "build", "ownership.jac", "-o", str(ownership_exe)])
        ownership = run("ownership", [str(ownership_exe)])
        if ownership.strip() != "ownership_baseline_passed registrations=8 releases=8 late_rejected=8":
            raise RuntimeError("Retained ownership trace did not match")
        report["executable_sha256"] = hashlib.sha256(executable.read_bytes()).hexdigest()
        report["snapshot"] = "not requested"
        if args.snapshot:
            image = artifacts / "reference.png"
            image.unlink(missing_ok=True)
            run("snapshot", [neojac, "cargo", "run", "--locked", "--manifest-path", "native/Cargo.toml", "--", "--snap", str(image)])
            if not image.is_file():
                raise RuntimeError("Snapshot command did not produce a PNG")
            data = image.read_bytes()
            if data[:8] != b"\x89PNG\r\n\x1a\n":
                raise RuntimeError("Snapshot is not a PNG")
            offset, dimensions, ended = 8, None, False
            while offset + 12 <= len(data):
                length = struct.unpack(">I", data[offset:offset + 4])[0]
                kind = data[offset + 4:offset + 8]
                payload = data[offset + 8:offset + 8 + length]
                end = offset + 12 + length
                if end > len(data):
                    raise RuntimeError("Truncated PNG chunk")
                crc = struct.unpack(">I", data[end - 4:end])[0]
                if zlib.crc32(kind + payload) != crc:
                    raise RuntimeError("PNG chunk checksum mismatch")
                if kind == b"IHDR":
                    dimensions = struct.unpack(">II", payload[:8])
                if kind == b"IEND":
                    ended = True
                    break
                offset = end
            if not ended or dimensions != (640, 480):
                raise RuntimeError(f"Unexpected snapshot dimensions or incomplete PNG: {dimensions}")
            report["snapshot"] = {"sha256": hashlib.sha256(data).hexdigest(), "dimensions": dimensions}
        report["status"] = "passed"
        report["remaining_gates"] = ["typed Jac tree", "foreign-wait worker progress", "interactive Jac window", "release build"]
    except (RuntimeError, OSError, ValueError, struct.error, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
    finally:
        (artifacts / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
