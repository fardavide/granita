# Count the file beyond the final diff hunk

*(5 November 2026)*

Davide reports that a 1,000-line file changed around lines 200 and 600 cannot expand below the last
change. The regression reproduces both file lengths being reported as 603: the end of the last
three-line context window, rather than the end of the file.

This supersedes 0168's acceptance of the missing downward control. The existing remainder-of-file
row and twenty-line expansion windows already implement the intended interaction; the missing
input is the server's file length, so the view and its design stay unchanged.

For a complete tracked text diff, compare the working copy against `/dev/null` through the existing
git port. That full-addition hunk's new-side count is the file length. The complete change diff
supplies the net line delta, giving the old-side total
without a second content read or a filesystem seam. This costs one additional git invocation per
tracked text file with hunks. Added, untracked and deleted files already describe their whole content;
binary files, submodules and files without hunks need no count read.

A truncated change diff keeps its existing visible bounds instead. Advertising a remainder beyond
the retained hunks would let context expansion show omitted changes as unchanged lines. If the
whole-file read hits its output ceiling, retain the visible bounds and explain that the file is too
large for context expansion; the existing context route cannot serve beyond that ceiling either.
Reading the whole-file count does not raise the diff limits or bypass truncation.

The regression first fails with 603 versus 1,000 and then passes with the corrected metadata. The
existing client expansion and gap-row tests hold the twenty-line windows and end-of-file behavior.
A second regression first fails on an advertised but unreadable remainder, then verifies that capped
context reports the limit while retaining the original changed lines.

An iOS touch check mounts the production reader model and screen over a range-aware test repository.
With UIKit and SwiftUI animations verified disabled, pressing the trailing control reveals twenty
lines, then the remaining three; the final line appears and the control disappears. The existing
32 file-content snapshot cases remain unchanged. This validates the existing control's effect
without adding a new reader-facing view or changing the horizontal-swipe fixture.
