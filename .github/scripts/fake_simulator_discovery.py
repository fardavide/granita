#!/usr/bin/env python3
"""Local simulator inventory for destination-selection tests."""

import os
from pathlib import Path
import shlex
import sys


def main() -> None:
    arguments = sys.argv[1:]
    receipt = os.environ.get("FAKE_SIMULATOR_TOOL_CALLS")
    if receipt is not None:
        with Path(receipt).open("a") as output:
            output.write(shlex.join(["xcrun", *arguments]) + "\n")
    if arguments == ["simctl", "list", "devices", "available"]:
        print(Path(os.environ["FAKE_SIMULATOR_DEVICE_LIST"]).read_text(), end="")
    elif len(arguments) == 3 and arguments[:2] == ["simctl", "boot"]:
        return
    else:
        raise AssertionError(f"Unexpected platform command: {arguments}")


if __name__ == "__main__":
    main()
