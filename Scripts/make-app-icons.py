#!/usr/bin/env python3
"""Rasterises the icon artwork in Art/icon/ into both app icon sets.

The SVGs are the design source and are committed; so are the PNGs this writes, because rasterising
is not reproducible across machines or OS releases. That is why `make verify-generated` checks the
Xcode project and the diff fixtures but deliberately NOT the icons — it would compare a runner's
antialiasing against a laptop's and fail on artwork nobody touched. This runs by hand, through
`make icons`, when the artwork changes.

The two sets need opposite things, and each mismatch is an App Store Connect reject rather than a
build failure:

  iOS     a full square with NO alpha sample. An alpha channel on the marketing icon is ITMS-90717,
          and the system applies its own mask, so the artwork is rendered with the squircle clip
          stripped — otherwise the mask is baked in and then masked again.
  macOS   the shaped icon WITH alpha, at every slot in the ladder. Nothing masks a Mac icon for you,
          and with the mac slots empty the asset compiler emits no macOS icon at all (ITMS-90236).

Usage:  Scripts/make-app-icons.py
"""

from __future__ import annotations

import json
import pathlib
import re
import struct
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "Art" / "icon"
RASTERISE = ROOT / "Scripts" / "rasterise-svg.swift"

# iOS 26 and macOS 26 render a different drawing per appearance. Three files, one icon set.
APPEARANCES = {
    "any": None,
    "dark": [{"appearance": "luminosity", "value": "dark"}],
    "tinted": [{"appearance": "luminosity", "value": "tinted"}],
}

MAC_SLOTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

# The artwork clips everything to a squircle for presentation. The clip is the outermost group's,
# and its id is `sq` plus a per-file letter.
SQUIRCLE_CLIP = re.compile(r'\s*clip-path="url\(#sq[A-Za-z]\)"')


def unclipped(svg: pathlib.Path, into: pathlib.Path) -> pathlib.Path:
    """The same drawing with the squircle clip removed, so the background fills the whole square."""
    source = svg.read_text()
    stripped = SQUIRCLE_CLIP.sub("", source, count=1)
    if stripped == source:
        raise SystemExit(f"error: no squircle clip found in {svg.name}; the artwork changed shape")
    destination = into / svg.name
    destination.write_text(stripped)
    return destination


def rasterise(svg: pathlib.Path, pixels: int, destination: pathlib.Path, opaque: bool) -> None:
    command = ["swift", str(RASTERISE), str(svg), str(pixels), str(destination)]
    if opaque:
        command.append("--opaque")
    subprocess.run(command, check=True)


def png_colour_type(png: pathlib.Path) -> int:
    return struct.unpack(">IIBB", png.read_bytes()[16:26])[3]


def reset(app: str) -> pathlib.Path:
    out = ROOT / "Apps" / app / "Assets.xcassets" / "AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    for stale in out.glob("*.png"):
        stale.unlink()
    (out.parent / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    return out


def write_contents(directory: pathlib.Path, images: list[dict]) -> None:
    (directory / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )


def write_mobile(scratch: pathlib.Path) -> None:
    out = reset("GranitaMobile")
    images = []
    for name, appearance in APPEARANCES.items():
        png = out / f"icon-{name}-1024.png"
        rasterise(unclipped(ART / f"granita-{name}.svg", scratch), 1024, png, opaque=True)
        if png_colour_type(png) in (4, 6):
            raise SystemExit(f"error: {png.name} carries an alpha channel; the iOS icon must not")
        entry = {"filename": png.name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance is not None:
            entry["appearances"] = appearance
        images.append(entry)
    write_contents(out, images)
    print(f"  GranitaMobile: {len(images)} appearances, opaque, unclipped")


def write_mac() -> None:
    out = reset("GranitaMac")
    # A mac icon set takes one drawing across the slot ladder; the appearance variants above are an
    # iOS home-screen facility. The default artwork is the one that reads on any desktop picture.
    for pixels in sorted({points * scale for points, scale in MAC_SLOTS}):
        png = out / f"icon-{pixels}.png"
        rasterise(ART / "granita-any.svg", pixels, png, opaque=False)
        if png_colour_type(png) not in (4, 6):
            raise SystemExit(f"error: {png.name} has no alpha channel; the macOS icon needs its shape")
    images = [
        {"filename": f"icon-{points * scale}.png", "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"}
        for points, scale in MAC_SLOTS
    ]
    write_contents(out, images)
    print(f"  GranitaMac: {len(images)} slots, shaped, with alpha")


def main() -> None:
    for name in APPEARANCES:
        svg = ART / f"granita-{name}.svg"
        if not svg.is_file():
            raise SystemExit(f"error: missing {svg.relative_to(ROOT)}")
    with tempfile.TemporaryDirectory() as scratch:
        write_mobile(pathlib.Path(scratch))
    write_mac()


if __name__ == "__main__":
    main()
