# The composition root is its own module, and coverage is measured over what a test can reach

Two things landed together because the first is what makes the second expressible.

**`ServerAppPresentation`, which the spec's §3 tree does not list.** The menu bar app's wiring lived
in `Server/Mac/Presentation` beside the model it builds. That module was then both a feature's
presentation layer and a composition root — one of them full of things a test constructs, the other
full of things no test can. It is now split the way the client already was: `Client/App/Presentation`
has always been the phone's composition root, and `Server/App/Presentation` is the Mac's. The
feature module loses its `Data` dependencies with it, so `Presentation` no longer sees `Data`
anywhere except in the two roots and the executable — which is what the layer rule always said.

**Then the coverage gate.** Adding the Mac's first test target pulled `ServerMacUi` and the
composition root into the unit denominator for the first time and dropped the Unit row 11.7 points
in one pull request. Nothing had got worse: a SwiftUI body needs a renderer and a SwiftPM test
target is hostless, and no test constructs a composition root, so those lines are uncoverable by
construction rather than uncovered by neglect. The number moved because a module was linked into a
test binary — a fact about the target graph, and the same class of dilution that scoped the Snapshot
row to the view layers.

So the Unit and All rows are now measured over **what a host test can reach**: the package, minus
view bodies, minus the composition roots. It is the mirror of the Snapshot row's scope rather than a
new idea, and the gate un-judges a redefined row for exactly one run, which is the mechanism that
exists for this.

`granita-server` was already exempt by accident — an executable target is not linked into a test
binary, so its composition root has never been measured at all. Naming the directories makes that
the same decision for all three rather than a property of how one of them is packaged.

**What this leaves open, deliberately.** A macOS view layer is now measured by nothing: the Snapshot
kind is the iOS target, and there is no macOS equivalent. That is tracked in `status.md` and it is
owed before the Settings window grows its other three tabs — each one is a screen that a host test
cannot execute, and the Unit row will keep drifting down until a kind exists that renders them.
Screens composed in `Presentation` have the same problem in miniature and are counted today, which
is the honest reading: they are reachable in principle, and nothing renders them yet.

