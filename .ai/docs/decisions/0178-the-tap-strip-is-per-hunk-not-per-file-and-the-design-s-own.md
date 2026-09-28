# The tap strip is per hunk, not per file, and the design's own shape is why

§7 asks for one recogniser over "the gutter column of each file section". A file is not one view:
`DiffFileContent` lays out one `DiffFileLines` per hunk with 44pt torn expander rows between them, and
each hunk adds a 3pt scroll indicator one layout pass after its own geometry resolves. A file-level
`floor(y / rowHeight)` would have to sum hunk heights, expander heights and an indicator that appears
late.

Per hunk keeps every property the design argued for — one spatial recogniser rather than forty-two
buttons, `floor(y / rowHeight)`, nearest-numbered-centre resolution — and is the coordinate space
`GutterTarget` was already written against. Rejected: a 44pt `contentShape` per row, which the design
also rejects and for the better reason: it overhangs its neighbours by 13pt on each side, so three
rows claim one point and z-order decides.

