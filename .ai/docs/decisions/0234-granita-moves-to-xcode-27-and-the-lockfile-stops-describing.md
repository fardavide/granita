# Granita moves to Xcode 27, and the lockfile stops describing an impossible graph

28 September 2026. The development Mac updated itself to Xcode 27.0 (27A266a), and it refused two
`Shape` conformances that every Xcode 26 had accepted. Davide's call was to move the repository with
it rather than install 26.6 beside it, and then to move CI too rather than keep it on 26.6.

**The code change is one file.** `TornEdge` and `HiddenLines` are `nonisolated` now. The package
builds main-actor by default, and the Xcode 27 SDK declares `Shape.path(in:)` as a nonisolated
requirement, so a main-actor struct cannot satisfy it. `nonisolated` on a type is Swift 6.2, so the
change builds on 26.6 as well. Nothing else in the package failed to build, and every package test
passed on 27.0 unchanged. The 27 SDK does raise 135 new warnings, mostly the deprecated `Text` `+`
and `Binding` setters that are now `@isolated(any) @Sendable`. They are warnings, and fixing them is
separate work.

**`Package.resolved` changes by exactly the rename that the entry above was about.** Under 27, the
resolver pins `swift-issue-reporting` 2.1.1 in place of `xctest-dynamic-overlay` 1.13.1, and
nothing else moves. So the file finally describes a graph that can exist. The resolver fault that
entry traced to Swift 6.3.3 is gone. The consequence is that **Xcode Cloud has to move to 27
together with this merge**. Cloud does not resolve on its own, and a Cloud still pinned to 26.6 would
be the stale resolver judging a correct file.

**CI runs on `xcode-27`**, GitHub's image for Xcode 27 and its iOS 27 simulators. `macos-26` carries
only 26.x. The image was a public preview when this was written, which is a known risk: a queue or a
flaky runner there is GitHub's to fix. The pin in `select-xcode` prefers 27.0 and warns on any other
27.x. The two caches that hold compiled objects (the unit-test package build and the instrumented
coverage build) carry `xcode27` in their keys, so a restore can never hand the new compiler a build
made by the old one. The caches that hold only source clones keep their keys.

**The baselines that move, move by their own procedures.** The phone's are recorded locally on the
iOS 27 simulator, so the recording machine needs that runtime installed. With only the 26.5 runtime
present, Xcode 27 renders every phone baseline identically to 26.6, which is how the move was shown
to be the SDK's fault and not a layout change. On iOS 27, 301 of 1,091 fail, the same count here and
on the runner. Only those are replaced, not the whole directory the recorder rewrites, so the diff is
the change itself. Both causes are the system's: a toolbar button's glass gains a hairline border,
and `ContentUnavailableView` sets its title smaller and its description larger.

**The empty-state hierarchy is pinned rather than taken from 27.** The first draft of this entry
called the `ContentUnavailableView` change "the system's own" and re-recorded the baselines to
match. Davide read them and said the title was smaller than the body, which is a defect, not a
look. All 25 empty states now set their title at title2 bold and their description at body, the
hierarchy iOS 26 drew, through a pair of modifiers. **There is one copy per `Ui` module**, because a
`Ui` module may depend only on `Domain` and SwiftUI, so no module can hold it for all four. The call
is in `design.md`, beside the rest of the empty-state rules.

**With two runtimes installed, `make snapshots` rendered on the older one.** It took the first
recent iPhone in the list, "iPhone 17 Pro", which only iOS 26.5 ships, so `OS=latest` resolved to
26.5. The Makefile, `ci.yml` and the coverage script now take the first iPhone of the newest iOS
runtime. The Mac's are the runner's renders, and
the image's host OS is macOS 27, so they are adopted from the first red run through
`Scripts/adopt-mac-baselines.py`, as always. Eleven moved, and both changes are the system's
own: `ContentUnavailableView` sets its title smaller and its description larger, and the Review
pane's segmented control is a few points narrower. Nothing Granita draws itself moved.

**The coverage script stopped hardcoding SwiftPM's layout.** Xcode 27's SwiftPM builds through Swift
Build. That puts products under `<scratch>/out/Products/Debug` rather than
`<scratch>/arm64-apple-macosx/debug`, and it builds one test bundle per test target where there
used to be a single `GranitaPackageTests`. So the unit pass now asks `swift build --show-bin-path`
for the directory and takes every `*.xctest` under it, which is correct under either layout.

**The unit row's export is ours now, not SwiftPM's.** The first green run on 27 said unit lines fell
from 97.4% to 97.0% on a branch that adds no code, and the per-file exports explained it: SwiftPM's
`--show-codecov-path` export covered 98 files where `main`'s covered 1,385. It had exported one
test bundle of many. So the row was measuring a tenth of the package. The unit pass now runs
`llvm-cov export` itself over every bundle against SwiftPM's merged profile, the same way the
snapshot and all rows already did.

> Rejected: keep the repository on 26.6 and install it beside 27 locally. It was the lower-risk
> option, and it would have left a toolchain on the development Mac that the Mac no longer ships.
>
> Rejected: land the `nonisolated` fix alone and leave CI on 26.6 until the image leaves preview.
> The fix does build on both. But recording the phone's baselines on a runtime CI does not use is
> the environment drift the pin exists to prevent, and Davide chose to move CI as well.

