# The Snapshot row falls for §7, and it is the gap `GranitaSettingsScreen` already documented

`make coverage` refuses this slice on two values: **Snapshot lines 97.8% → 97.0% and Snapshot regions
89.7% → 87.8%.** The other four rows are level or up — Unit gained 0.2 and 0.3, and `All tests` is ±0
on lines and +0.3 on regions.

The per-file export was read before anything was touched, which is the rule. Every uncovered region in
the §7 view code is an action closure or a presentation the raster excludes:

| File | Regions | What is uncovered |
|---|---|---|
| `WorktreeDiffScreen` | 83/126 | **All 43** — the two alert button builders, three `Binding` setters, the nine callbacks handed to `ContinuousDiffView`, and the sheet builders |
| `ReviewSheetView` | 94/106 | The alert's buttons, the keyboard toolbar, the swipe action, and the Copy / Clear / *Show text* actions |
| `DiffFileLines` | 95/111 | The tap and long-press closures, and the `{ _ in }` defaults behind them |
| `ReviewCapsule`, `CommentInstructionBar`, `StaleCommentRow`, `CommentCountChip` | **100%** | — |

That is verbatim the case the `swift-testing` skill records for `GranitaSettingsScreen`: *"adding a
control to that screen lowers the Snapshot regions row and no test this project can currently run will
lift it — only the `Ui` kind would, and that target cannot run without an Accessibility grant. Do not
respond by restructuring the screen or by widening a scope."* §7 adds nine controls and three
presentations to one screen, so the row moves further than it has for any previous slice.

**Two things in the residue were not structural and are fixed.** `showsDocument` was `@State` inside
the review sheet, so *Show text*'s entire effect — the branch that draws the exported text — was
reachable by no baseline and no test; it is on the model now with a unit test and a subject of its
own, and it moved Snapshot lines from −0.9 to −0.7. And `CommentSelection.ends` was still carrying the
unreachable `guard` this file's own earlier entry said would be removed, beside a genuinely reachable
branch nothing drove: tapping the gutter of a file whose diff has not arrived. Both closed, and
together they are what took `All tests` lines back to level.

**What is not being done, deliberately.** The scope is not widened and the screen is not restructured.
`Client/Viewer/Data/UiKitReviewPasteboard.swift` is three permanently-uncovered lines that meet the
`UNREACHABLE_FILES` bar exactly — every line is a call on the running application, and executing it in
a test writes into the developer's own pasteboard, which is why `AppKitSystemGestures` is already
there — but adding it is a scope redefinition and, as it turns out, is **not needed**: `All tests`
reaches level without it. It is recorded here rather than taken.

