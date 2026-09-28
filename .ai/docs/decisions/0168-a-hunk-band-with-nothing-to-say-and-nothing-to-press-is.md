# A hunk band with nothing to say and nothing to press is removed, and one arrow is missing under it

*(1 September 2026, 0.6.1)*

`DiffHunkHeader` drew its 26pt strip unconditionally. For a short file — one hunk, from the first
line to the last, and no section heading, which is what git gives whenever nothing encloses the
change — that is a band with no name to carry and no gap to open: 26pt of grey chrome under the file
header of most small diffs. Davide: *"some grey bars are empty… they should either have arrow/s or be
hidden (I think they're missing arrow)"*.

The band is now drawn only where it has a heading **or** a gap on one side, which is design §4's
"a chevron over an empty gap is the smallest possible lie" applied to the thing the chevron sits in.

**His hunch is also right, and that half is not fixed here.** `WorktreeService.fileDiff` derives
`FileDiff.newLineCount` from the last hunk's own end — `newStart + newCount - 1` — while
`DiffModels.swift` documents the field as "total lines on each side, which is what makes *can this
hunk expand downwards* answerable without asking the server". They are the same number only when the
last hunk runs to the end of the file, so **the last hunk of every file reports no gap below it** and
never offers the downward chevron. `oldLineCount` has the same shape.

The honest fix is the Mac's and it is not free: git's diff output does not carry a file's length, so
the service would have to read the working copy for the new side and the compared revision for the
old — one or two extra `git` invocations per file, on a route that already runs one per file and is
called five files at a time.

**Davide settled it on 1 September 2026 and the answer is not to spend that**: *"it is fine in case
there's nothing to expand below, but we should not show an empty expander."* The requirement is on
what the screen draws, not on what the Mac knows. A chevron over an empty gap was already absent, a
band with nothing to say is absent now, and a missing downward chevron on a file's last hunk is a
smaller fault than either — it shows nothing rather than lying about something.

What it costs, stated so a later measurement can reopen it: a long file whose last hunk git left
unheaded loses its band rather than gaining the chevron it should have, and the reader reaches the
lines below that hunk by opening the file on the Mac.

