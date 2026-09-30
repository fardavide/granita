"""Fingerprint the inputs to compilation, rendering and measurement."""

import hashlib
import json
import subprocess
import sys
from pathlib import Path


def measurement_digest(
    files: dict[str, bytes],
    resolved: object,
    committed_resolved: object,
) -> str:
    digest = hashlib.sha256()
    for name, contents in sorted(files.items()):
        digest.update(name.encode() + b"\0" + hashlib.sha256(contents).digest())
    if not isinstance(resolved, dict) or not isinstance(committed_resolved, dict):
        raise ValueError("Invalid resolved dependency graph")
    pins = resolved.get("pins")
    committed_pins = committed_resolved.get("pins")
    if not isinstance(pins, list) or not isinstance(committed_pins, list):
        raise ValueError("Invalid resolved dependency pins")
    normalized: dict[str, object] = {}
    for pin in pins:
        if not isinstance(pin, dict) or not isinstance(pin.get("identity"), str):
            raise ValueError("Invalid resolved dependency pin")
        normalized[pin["identity"]] = pin
    # SwiftPM rewrites this lock to its own graph; Xcode uses the union. Only the four
    # known Xcode-only omissions may inherit their committed pin, never a changed pin.
    for pin in committed_pins:
        if not isinstance(pin, dict) or not isinstance(pin.get("identity"), str):
            raise ValueError("Invalid committed dependency pin")
        identity = pin["identity"]
        if identity in ("swift-snapshot-testing", "swift-custom-dump", "swift-issue-reporting", "swift-syntax") and identity not in normalized:
            normalized[identity] = pin
    digest.update(json.dumps(normalized, sort_keys=True).encode())
    return digest.hexdigest()


def validate_build_stamp(
    stamp: object,
    revision: str,
    run: str,
    toolchain: str,
    root: str,
    source_digest: str,
) -> None:
    if not isinstance(stamp, dict):
        raise ValueError("Invalid build stamp")
    expected = {"revision": revision, "run": run, "toolchain": toolchain, "root": root, "source_digest": source_digest}
    for key, value in expected.items():
        if stamp.get(key) != value:
            raise ValueError(f"Build {key.replace('_', ' ')} {stamp.get(key)} does not match {value}")


if __name__ == "__main__":
    lock = "Packages/Granita/Package.resolved"
    names = subprocess.check_output([
        "git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--",
        "Apps", "Packages", "Granita.xcodeproj", "Art", "project.yml", "Makefile",
        ".github/scripts", ".github/ios-snapshot-durations.json",
    ]).decode().split("\0")
    files = {name: Path(name).read_bytes() for name in names if name and name != lock}
    committed: object = json.loads(subprocess.check_output(["git", "show", f"HEAD:{lock}"]))
    source_digest = measurement_digest(files, json.loads(Path(lock).read_text()), committed)
    if len(sys.argv) == 1:
        print(source_digest)
    elif sys.argv[1] == "verify-build":
        validate_build_stamp(json.loads(Path(sys.argv[2]).read_text()), *sys.argv[3:7], source_digest)
    else:
        raise ValueError("Expected verify-build or no arguments")
