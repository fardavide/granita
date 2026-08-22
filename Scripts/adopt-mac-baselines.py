#!/usr/bin/env python3
"""Adopt the macOS snapshot baselines a CI runner rendered.

**The Mac's baselines are recorded on the runner, and this is how.** That inverts the rule the phone
follows — record locally, never on CI — and the reason is measured rather than assumed:

    cross-machine drift, same code   0.737% of pixels differ by more than 64 levels
    a real one-word copy change      0.162%

The noise is four and a half times the signal, so no tolerance exists that catches a changed word
without also hiding one.

What is demonstrated about the cause is that the runner's window renders at 1x and a Retina laptop's
at 2x — before the raster was pinned, the same code produced 620 x 560 there and 1240 x 1120 here —
and that `NSWindow.backingScaleFactor` comes from the screen with no API to pin it. Pinning the
*bitmap* raster, which this project does, fixes the image size and not whatever the backing scale
does upstream of it. The exact mechanism is open; see `decisions.md`, which separates the measured
from the inferred.

So the runner is the one machine whose renders are reproducible on the machine that gates them, and
its output is what gets committed.

**The consequence, and it is not subtle: `make snapshots-mac` is red on a developer's Mac.** That is
expected and is not something to fix by re-recording locally — doing so turns CI red instead, which
is the failure this whole arrangement exists to avoid. `make record-snapshots` deliberately leaves
the Mac baselines alone for the same reason.

    Scripts/adopt-mac-baselines.py <snapshot-diffs-mac artifact dir or index.html>

The artifact is what the `Snapshot tests (macOS)` job uploads when it fails. Download it with

    gh run download <run-id> -n snapshot-diffs-mac -D <dir>

Every image is written **only** if it differs from what is already committed, and the script prints
what it changed — because adopting a runner's render is accepting a picture nobody has looked at,
and the list is what makes the review possible.
"""

from __future__ import annotations

import base64
import pathlib
import re
import sys

BASELINES = pathlib.Path("Apps/GranitaMacSnapshotTests/__Snapshots__")

# Each section of the report carries four images: the committed baseline and the fresh render, then
# the same two again stacked for the difference view. Index 1 is the render.
SECTION = re.compile(r"<section>\s*<h2>(.*?)</h2>(.*?)</section>", re.S)
IMAGE = re.compile(r"data:image/png;base64,([A-Za-z0-9+/=]+)")
RENDERED = 1


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__)
        return 2

    source = pathlib.Path(argv[0])
    report = source / "index.html" if source.is_dir() else source
    if not report.is_file():
        print(f"No report at {report}", file=sys.stderr)
        return 1

    sections = SECTION.findall(report.read_text())
    if not sections:
        print(f"{report} holds no mismatches — nothing to adopt.")
        return 0

    written = 0
    for relative, body in sections:
        images = IMAGE.findall(body)
        if len(images) <= RENDERED:
            print(f"  skipped (no render): {relative}")
            continue
        rendered = base64.b64decode(images[RENDERED])
        target = BASELINES / relative
        if target.is_file() and target.read_bytes() == rendered:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(rendered)
        written += 1
        print(f"  adopted: {relative}")

    print(f"\n{written} baseline(s) adopted from the runner, {len(sections) - written} already matching.")
    print("Review every changed PNG by eye before committing — see the module docstring.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
