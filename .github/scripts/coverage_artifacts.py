"""Validate coverage provenance before any counters enter the gate."""

import hashlib
import json
import re
import sys
from pathlib import Path


def validate_manifest(
    manifest_path: Path,
    expected_revision: str,
    expected_run: str,
    expected_toolchain: str,
    expected_source_digest: str | None = None,
) -> None:
    manifest: object = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("Coverage manifest must be an object")
    if manifest.get("schema") != 1:
        raise ValueError(f"Unsupported coverage manifest schema: {manifest.get('schema')}")
    if manifest.get("source_revision") != expected_revision:
        raise ValueError(f"Coverage source revision {manifest.get('source_revision')} does not match {expected_revision}")
    if manifest.get("run") != expected_run:
        raise ValueError(f"Coverage run attempt {manifest.get('run')} does not match {expected_run}")
    if manifest.get("toolchain") != expected_toolchain:
        raise ValueError(f"Coverage toolchain {manifest.get('toolchain')} does not match {expected_toolchain}")
    if manifest.get("complete") is not True:
        raise ValueError("Coverage results are incomplete")
    if expected_source_digest is not None and manifest.get("source_digest") != expected_source_digest:
        raise ValueError(f"Coverage source digest {manifest.get('source_digest')} does not match {expected_source_digest}")
    files = manifest.get("files", [])
    if not isinstance(files, list):
        raise ValueError("Coverage files must be a list")
    if not files:
        raise ValueError("Coverage requires a profile and mappings")
    for entry in files:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise ValueError("Coverage file entry must contain a path")
        relative = Path(entry["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"Invalid coverage artifact path: {relative}")
        path = manifest_path.parent / entry["path"]
        if not path.is_file():
            raise ValueError(f"Coverage file is missing: {entry['path']}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry.get("sha256"):
            raise ValueError(f"Coverage digest mismatch: {entry['path']}")
    paths = [entry["path"] for entry in files]
    if "profile.profdata" not in paths or not any(path.startswith("objects/") for path in paths):
        raise ValueError("Coverage requires a profile and mappings")
    actual_mappings = {
        str(path.relative_to(manifest_path.parent))
        for path in (manifest_path.parent / "objects").iterdir()
    }
    declared_mappings = {path for path in paths if path.startswith("objects/")}
    if actual_mappings != declared_mappings:
        raise ValueError(f"Coverage mapping inventory differs: {sorted(actual_mappings ^ declared_mappings)}")
    if manifest.get("suite") == "unit" and "tests.log" not in paths:
        raise ValueError("Unit coverage requires tests.log receipt")
    if manifest.get("suite") == "unit":
        receipt = (manifest_path.parent / "tests.log").read_text(encoding="utf-8")
        runs = re.findall(r"Test run with [1-9][0-9]* tests .*passed", receipt)
        if len(runs) != len(declared_mappings):
            raise ValueError("Completed positive test runs must match every unit mapping")
    if manifest.get("suite") in ("ios", "ios-0", "ios-1", "mac"):
        for receipt in ("test-summary.json", "test-inventory.json"):
            if receipt not in paths:
                raise ValueError(f"Snapshot coverage requires {receipt} receipt")
        summary: object = json.loads((manifest_path.parent / "test-summary.json").read_text())
        if not isinstance(summary, dict):
            raise ValueError("Invalid snapshot test summary")
        if summary.get("result") != "Passed" or summary.get("passedTests", 0) <= 0 or summary.get("totalTestCount") != summary.get("passedTests") or summary.get("failedTests") != 0 or summary.get("skippedTests") != 0:
            raise ValueError("Snapshot tests failed or are incomplete")
        if len(declared_mappings) != 3:
            raise ValueError("Snapshot coverage requires all three mappings")
        if manifest.get("suite") in ("ios-0", "ios-1"):
            from snapshot_shards import verify_completed_tests

            for receipt in ("planned-tests.json", "enumerated-tests.json"):
                if receipt not in paths:
                    raise ValueError(f"Snapshot coverage requires {receipt} receipt")
            expected: object = json.loads((manifest_path.parent / "planned-tests.json").read_text())
            if not isinstance(expected, list) or not all(isinstance(item, str) for item in expected):
                raise ValueError("Invalid planned snapshot tests")
            verify_completed_tests(expected, json.loads((manifest_path.parent / "test-inventory.json").read_text()))


if __name__ == "__main__":
    validate_manifest(Path(sys.argv[1]), *sys.argv[2:6])
