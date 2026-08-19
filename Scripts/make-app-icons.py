#!/usr/bin/env python3
"""Generates the app icon sets for both targets.

This exists so the icon is reproducible rather than a binary somebody once dragged in, and so
replacing the placeholder with a designed mark is a change to one function.

Two constraints are App Store Connect rejections rather than build failures, so they are asserted
here instead of being left to review:

  * the icon must be **opaque** — an alpha channel is ITMS-90717, and it is invisible locally;
  * every **macOS** slot must be filled — with the mac slots empty the asset compiler emits no
    macOS icon at all, which uploads as ITMS-90236.

The PNGs are written with no alpha channel (colour type 2), so opacity is structural rather than
a property that has to hold.

Usage:  Scripts/make-app-icons.py
"""

from __future__ import annotations

import json
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

# macOS reads a distinct slot set from iOS, and both scales of every size must resolve.
MAC_SLOTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]


def render(size: int) -> bytes:
    """A deterministic opaque gradient — crushed ice, which is what a granita is.

    Replace this body when the designed mark arrives; nothing else in the file needs to change.
    """
    rows = []
    for y in range(size):
        row = bytearray([0])  # PNG filter type 0 — none
        for x in range(size):
            t = (x + y) / max(1, 2 * size - 2)
            row += bytes((int(28 + 90 * t), int(110 + 95 * t), int(160 + 70 * t)))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    # Colour type 2 is truecolour with no alpha sample, so the output cannot carry transparency.
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def write_set(app: str, images: list[dict], pixel_sizes: set[int]) -> None:
    out = ROOT / "Apps" / app / "Assets.xcassets" / "AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    for stale in out.glob("*.png"):
        stale.unlink()
    for pixels in sorted(pixel_sizes):
        (out / f"icon-{pixels}.png").write_bytes(render(pixels))
    (out / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    (out.parent / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    print(f"  {app}: {len(images)} slot(s), {len(pixel_sizes)} PNG(s)")


def main() -> None:
    # iOS takes one universal 1024 entry; modern Xcode derives every other size from it.
    write_set(
        "GranitaMobile",
        [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        {1024},
    )

    mac_images = [
        {"filename": f"icon-{points * scale}.png", "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"}
        for points, scale in MAC_SLOTS
    ]
    write_set("GranitaMac", mac_images, {points * scale for points, scale in MAC_SLOTS})


if __name__ == "__main__":
    main()
