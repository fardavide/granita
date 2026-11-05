#!/usr/bin/env python3
"""Capture a collector's test destination without starting platform tooling."""

import os
from pathlib import Path
import shlex
import sys


def main() -> int:
    with Path(os.environ["FAKE_SIMULATOR_TOOL_CALLS"]).open("a") as receipt:
        receipt.write(shlex.join(["xcodebuild", *sys.argv[1:]]) + "\n")
    print("Stopped after capturing the test invocation", file=sys.stderr)
    return 92


if __name__ == "__main__":
    sys.exit(main())
