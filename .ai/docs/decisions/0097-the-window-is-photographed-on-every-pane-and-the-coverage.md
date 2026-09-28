# The window is photographed on every pane, and the coverage gate is what said so

The Snapshot row fell 95.6% → 95.4% and the export named the cause without argument: 84 of
`GranitaSettingsScreen`'s 445 lines uncovered, because the window's only baselines landed on General
and the other four tabs' composition closures are code no picture executed. Adding a fifth tab made
a gap that was already there one fifth worse.

**The pictures are partly redundant and the execution is not.** A hosted `TabView` draws no tab bar,
so the window on Devices looks very like `DevicesSettingsView`'s own baseline — but a pane's own
baselines are taken against values a test hands it directly, and these are taken against values that
arrived through the closures the window composes it from. A closure handed the wrong one — Devices
drawing Projects' failure, a Revoke carrying the neighbouring row's identifier — is invisible in
every other test this repository has.

Rejected: rescoping the row. It is the fourth time a falling row has been read here and the third
time the answer was that the code it cannot reach is code that should be reachable.

### And it immediately caught one, which is the point

The first render of the window on Devices photographed **Code expired**, forever. The pane's clock
came from `TimelineView(.periodic(from: .now, by: 1))` — a wall clock — while its data came from a
model whose clock is fixed, so the fake's expiry was always in the past.

That is the defect the connection log's row was repaired for, arriving one layer up: a schedule says
*when* to redraw and does not say what to draw, and a `body` that answers the second question with
`Date()` is a `body` whose picture depends on when the shutter opened. Both panes read
`model.currentTime` now. The schedule still comes from `.now`, because when to redraw is not
something a baseline can be wrong about.

