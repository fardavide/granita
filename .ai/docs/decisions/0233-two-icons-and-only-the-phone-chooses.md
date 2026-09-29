# Two icons, and only the phone chooses

0.20.0. Davide, 26 September 2026: *"I'm not very happy with the app icon."* Three rounds of drafts
later he chose two: **a glass of granita** whose syrup layers are the rows of a diff — the shipped
cup's markers and code lines, in wavy pastel syrup under whipped cream, with a spoon — as the app's
own icon, and **the diff frozen in an ice cube with a striped straw** as an alternate, *"more of a
Christmas version"*. Both replace the cup that shipped in #1. Four calls are expensive to reverse.

**The system is the only record of which icon is chosen.** iOS keeps an alternate across launches and
reports it back through `alternateIconName`, so nothing is written to this device's defaults. A second
copy could only ever disagree with the first — after a restore, or after an older build reads a name a
newer one set, which `SystemAppIconSwitcher` answers with the glass.

**The Mac has no setting, and the row is absent there rather than disabled.** macOS has no alternate
app icons: a running app can repaint its Dock tile, but Finder, Spotlight and the Dock at rest keep the
bundle's icon, so a chooser would change one of four places. Davide's call. The Mac apps ship the
glass, and the build setting that bundles the cube's icon set is scoped to the iPhone SDKs.

**Its own model, not a fifth value on `AppearanceModel`.** That model's whole contract is that nothing
it does can fail; the system can refuse an icon change, so folding it in would make the contract false.
Split by what it wraps, which is the one-model-per-unit rule's own escape hatch: `AppIconModel` wraps
the system, `AppearanceModel` wraps the defaults. A refusal keeps the checkmark on the icon the system
kept and shows the system's words as small print — the chooser never reports a change that did not
happen.

**The previews are image sets that `make icons` writes beside the icon sets.** An app icon set is not
something a view can load, and the section's rule is that the reader chooses a drawing rather than a
name — so the row and the chooser draw the icon, from the same artwork, shaped with alpha like the
Mac's, with a dark variant. Loose PNGs in a package bundle were rejected because loading one in
SwiftUI means a platform-specific fallback path for every row.

**No design round trip, on Davide's call** — *"You design it, and then I will run a round of Claude
Design if I'm not satisfied."* The row and the chooser copy *Code colours* exactly, so the calls are
written into [`design-appearance.md`](../design-appearance.md) in this repository's voice.

**The artwork was drawn by hand as SVG**, rendered through `Scripts/rasterise-svg.swift` and judged by
eye at 1024, 64 and 32 points across three rounds. It uses Gaussian blur, which that rasteriser
honours and which the old cup did not need. The generators are not committed; the SVGs in `Art/icon`
are the source.

