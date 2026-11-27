#!/usr/bin/env python3
"""Build the pinned Linux static XKB dependency with the selected neojac."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--neojac", default="neojac")
    parser.add_argument("--cache", type=Path, required=True)
    args = parser.parse_args()
    neojac = shutil.which(args.neojac)
    if neojac is None:
        parser.error("neojac executable not found")
    neojac = str(Path(neojac).resolve())
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    pin = json.loads(Path(__file__).with_name("inputs.json").read_text())["xkb"]
    archive = cache / "libxkbcommon-1.7.0.tar.xz"
    if not archive.exists():
        urllib.request.urlretrieve(pin["url"], archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != pin["sha256"]:
        raise RuntimeError(f"Checksum mismatch: {archive}")
    source = cache / "libxkbcommon-1.7.0"
    if not source.exists():
        with tarfile.open(archive) as bundle:
            bundle.extractall(cache, filter="data")
    machine = cache / "neojac-native.ini"
    machine.write_text("[binaries]\nc = [" + repr(neojac) + ", " + repr("cc") + "]\nar = " + repr(shutil.which("ar")) + "\nstrip = " + repr(shutil.which("strip")) + "\n")
    fingerprint = hashlib.sha256(Path(neojac).read_bytes()).hexdigest()[:16]
    build = cache / ("xkb-build-" + fingerprint)
    if not (build / "build.ninja").exists():
        subprocess.run(["meson", "setup", str(build), str(source), "--native-file", str(machine), "--buildtype=release", "-Ddefault_library=static", "-Denable-x11=false", "-Denable-wayland=false", "-Denable-tools=false", "-Denable-docs=false", "-Denable-xkbregistry=false", "-Denable-bash-completion=false"], check=True)
    subprocess.run(["ninja", "-C", str(build), "-j2", "libxkbcommon.a"], check=True)
    print(f"RUNE_PROBE_XKB_LIB_DIR={build}")


if __name__ == "__main__":
    main()
