# The sidebar's mode control is a toolbar menu, which is a second departure from `SPEC.md` §10

§10 says a segmented control switching between grouped and flat. Design §2 calls replacing it "the
strongest single recommendation in section two", and the built screen follows the design: **one
toolbar menu holding an inline picker and a toggle.**

The arithmetic is what settles it. A segmented picker is a permanent 32pt band plus 16pt of padding
— 48pt of every scroll, forever, for a preference set in week one — and it lands directly above the
Pinned header, so the first thing a reader sees on the screen this product exists for is two rows of
chrome. There is already a second preference beside the mode, the quiet switch, and probably a third:
three toggles cannot be three segmented controls, but they are three menu rows without a redesign.

Recorded here rather than left in `design.md` alone because this file is where a knowing departure
from the specification belongs, and this is the second in §2 — the other being the rename sheet
offering the suggestion rather than prefilling it. Everything else §10 asks of this sidebar is built
as written: the row's six fields, the swipe actions, pinned above everything in both modes with a
single Pinned section in grouped, and renaming writing the alias and never touching git.

