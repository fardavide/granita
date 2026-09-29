# The Mac's snapshot kind is a second bundle in the same row, not a row of its own

The Mac had no snapshot kind, so every Settings surface was code that nothing rendered and the
coverage report had no way to say so. Adding one raised a question the report's own shape does not
answer: is "snapshot" one kind measured on two platforms, or two kinds?

**One row.** The phone renders on a simulator and the Mac renders on the machine itself — there is no
macOS simulator — but the question the row exists to answer is identical for both: *of the code that
draws screens, how much does a baseline put on screen*. Two rows would split one question along a
platform axis no reader of the report cares about, and would do something actively misleading on the
day the Mac's row first appears: a new row starts unjudged, and a low number beside a high one reads
as a regression in the phone rather than as a kind that has just begun being measured. The two
profiles are merged before the row is taken, exactly as `all` already merges everything.

It moves the denominator, and that is expected rather than a surprise: `Server/Mac/Ui`,
`Server/Mac/Presentation` and `Server/App/Presentation` were in the views scope and in no export,
because the simulator never linked them. They are now in both.

**App-hosted, and for the coverage reason rather than the rendering one.** macOS needs no
`drawHierarchyInKeyWindow` — the `NSView` strategy renders through `cacheDisplay` — so a hostless
bundle would have produced pictures. What it would not have produced is the composition root
executing where the profile is written, which is the evidence the last session's coverage work turned
on. The cost is that the host really launches: the server binds, reaches for the Keychain identity
and tries to advertise. On a runner none of that succeeds and none of it needs to — every one of
those is a `ServerRunState.failed` the app already handles, and no baseline renders the app's own
scene.

### Four things about rendering AppKit that a baseline cannot tell you it got wrong

Each of these produces a picture that looks plausible and asserts less than it appears to.

**And the one that could not be fixed at all: the Mac's baselines are recorded on the CI runner.**
See the entry below; it inverts a rule this project states plainly elsewhere, and it is the only
option of four that survives the measurement.

**A baseline inherits the display's backing scale, so one recorded on a Retina Mac can never pass on
a runner.** This is the one that actually turned CI red, and it is the most important of the four
because the failure names nothing: twelve baselines, `Newly-taken snapshot@(620.0, 560.0) does not
match reference@(620.0, 560.0)`, identical point sizes, no clue. The diff artefact is what said it —
the reference was 1240 × 1120 pixels and what the runner drew was 620 × 560. A CI runner is headless
and has no Retina display, so `bitmapImageRepForCachingDisplay` gives it a 1× rep and this Mac a 2×
one, and every pixel differs for a reason that has nothing to do with the screen being asserted.

So the library's `NSView` strategy is replaced by one of ours that states the raster: the bitmap rep
is built with its pixel dimensions computed from a pinned scale and its `size` left in points, which
is what makes it 2× whatever is underneath. **Proved rather than assumed** — pinning the scale to 1
on this Retina Mac produced 620 × 560 images, which is the same mechanism observed in the direction
that can be tested locally.

Two is chosen over one because a baseline is reviewed by eye and half the resolution is half of what
a reviewer can catch.

**A window that never becomes key draws accent-tinted controls grey, and nothing here can make it
key.** `Open Local Network Settings` — the whole point of that row, the button a reader is meant to
press — renders identically to the `Try Again` beside it, and a switched-on `Toggle` shows a grey
track with the knob to the right. A window cannot become key while its application is not active,
and a test runner is never the frontmost app: `activate()`, `makeKeyAndOrderFront` and switching the
accessory host to `.regular` were each tried and none of them changed a pixel.

**So this limitation is named rather than worked around.** It costs exactly one thing — the accent
tint. Layout, copy, symbols, control shapes, a toggle's knob position and every non-accent semantic
colour are captured; the orange on "Not serving" is in the baselines. What a Mac baseline can never
catch is a `.borderedProminent` quietly losing its prominence, so that call is reviewed in the code.
Worth stating plainly because the failure mode of *not* stating it is a future session recording a
flat-looking screen, believing the design drifted, and re-recording to match.

**A rendered clock time is a locale and a time zone.** General shows when the server bound, so a
runner in UTC and a laptop in CEST draw different pixels from identical code — a failure the suite is
least able to explain. The locale and time zone are pinned once, in the shared hosting, rather than
per test.

**A `Form`'s "fitting height" is not a clipping test, and two attempts at one were wrong.**
`NSView.fittingSize` answers unconstrained, so a long footnote reports an ideal width past the
window's and an ideal height far short of the truth. Constraining the width and asking `sizeThatFits`
is no better: a `Form` is a scroll view and accepts whatever height it is offered. A pane cannot clip
— it scrolls — so the question worth asking is whether it *has* to, and the baseline answers that by
eye. What is asserted from inside the app is the window's content size, which is the thing that
genuinely cannot be measured from outside while Stage Manager is on.

### The macOS kind found two defects in what the coverage rows measure, and neither is a rescoping

Both rows went red, and the reflex — the one this project has now recorded being wrong about twice —
is that the gate is mis-scoped. Read with the per-file export rather than by algebra, it was
reporting two definitions that had only ever been exercised against one platform.

**`Server/Api/Presentation` was in the views scope.** The scope selects on the directory name
`Presentation`, and the server's API module is a presentation layer in the wire sense —
domain-to-wire mapping plus routes. `architecture.md` says it in as many words: *it has no `Ui`
sibling because it has no views.* This was invisible while only the phone had a snapshot kind,
because the simulator never linked those files and an export cannot include what a binary does not
map. The macOS kind links them, and they arrived as **1199 of the views scope's 2350 lines** —
`GranitaRouter.swift` alone contributing 562. The row was being asked how much of the HTTP router a
rendered screen executes.

**A SwiftUI body in `Presentation` was in the host-reachable scope.** That scope excludes `Ui`
because a body needs a renderer and a SwiftPM test target is hostless — and then counts
`GranitaSettingsScreen.swift`, which is a body, because it lives one layer out. `Presentation` holds
both models and the screens composed from `Ui`, and only the second kind needs a renderer;
`ServerMacModel` is an ordinary object a test constructs and stays judged. The incompleteness had
been sitting there at 23 uncovered lines in `ServerDiscoveryScreen.swift`; the Mac's screen is 101,
which is what made it visible.

**The test that says this is a correction and not a rescoping is the direction the number moves.**
With the screens excluded and nothing else changed, the Unit row reads **95.5% against the 93.9%
baseline it had been failing** — higher, not lower. Lines that leave a denominator and take the
percentage *up* were dragging it down by being unreachable rather than by being untested. A
rescoping that flatters a number does the opposite, every time, and that is how to tell them apart.

Both scope strings are renamed, so both rows go unjudged for one run and rejoin on the next `main`
run. That is the second consecutive run in which they are unenforced, which is a real cost and is
named here rather than left to be discovered.

**What is left genuinely uncovered is the Snapshot row at 76.3%**, down from 96.9%, and that number
is honest: the Mac's screens are newly measured and most of them are not rendered by any baseline
yet. `ConnectionLogView` has only its empty state, because a populated row draws its time with
`.relative` and a baseline of it would read differently every day — that is a change to the row and
lands with §6. `GranitaSettingsScreen` is composed by nothing, because rendering it needs the four
fakes the package's test target holds and an app bundle cannot import them.

