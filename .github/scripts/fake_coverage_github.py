#!/usr/bin/env python3
"""Local GitHub CLI fake for coverage-baseline workflow tests."""

import os
from pathlib import Path
import shutil
import sys


def main() -> int:
    arguments = sys.argv[1:]
    assert arguments[arguments.index("--repo") + 1] == "fardavide/granita", arguments
    if arguments[:2] == ["run", "list"]:
        assert arguments[arguments.index("--branch") + 1] == "main", arguments
        assert arguments[arguments.index("--status") + 1] == "success", arguments
        assert arguments[arguments.index("--workflow") + 1] == "CI", arguments
        print("123456789")
        return 0
    if arguments[:3] == ["run", "download", "123456789"]:
        if os.environ["FAKE_COVERAGE_DOWNLOAD_FAILS"] == "1":
            print("Saved main artifact could not be downloaded", file=sys.stderr)
            return 9
        assert arguments[arguments.index("-n") + 1] == "coverage-summary", arguments
        destination = Path(arguments[arguments.index("-D") + 1])
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copyfile("saved-main-summary.json", destination / "summary.json")
        return 0
    raise AssertionError(f"Unexpected GitHub command: {arguments}")


if __name__ == "__main__":
    sys.exit(main())
