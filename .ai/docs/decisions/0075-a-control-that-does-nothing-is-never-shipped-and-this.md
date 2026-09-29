# A control that does nothing is never shipped, and this project shipped one

Between 0.0.4 and 0.0.11 the discovery list's rows were `NavigationLink(value:)` and **no module
declared a destination for that value**. Tapping the Mac a reader opened the app to read did nothing
at all — no push, no message, no spinner. It reached TestFlight, and it is the worst defect this
product has had.

It was **known**. `GranitaMobileScene` carried a comment saying "the rows link to a destination this
stack does not have and tapping one does nothing, which is what tapping one already did". That
sentence is the whole failure: a defect was observed, written down, reasoned about, and shipped,
because it was filed as *the pairing screen is not built yet* rather than as *the app has a dead
control in it*. Those are not the same thing, and only the second one is a release blocker.

**The rule is now stated where it cannot be missed rather than where it must be looked up** — in the
global `CLAUDE.md`, in this repository's `CLAUDE.md`, and in the `/design` skill's binding rules.
Before any control ships, one of these is true: it works; it is absent; it is disabled **and**
labelled with why; or it is enabled and explains that the thing behind it is not built. Being
mid-slice is not an exception — it is the case the rule is for.

It was first written as a skill of its own and that was wrong, which is worth one line: **a skill is
read when something reaches for it**, and nothing reaches for a rule about dead controls while
believing it is only deferring one. A rule that must hold unconditionally belongs in the files that
load unconditionally.

**Two things about it are specific to how this codebase is built.** Clean layer boundaries make this
*easier* to miss rather than harder: every layer looked finished on its own, and the gap was between
two modules. And **the snapshot suite cannot catch it** — a baseline photographs a row beautifully
whether or not the row leads anywhere, which is exactly what happened here. The check is running the
app and pressing the thing.

So the destination now lives in `ServerDiscoveryScreen`, **beside the rows that link to it**, rather
than in the composition root where it would have gone. A link and its destination in two modules is
what let them drift apart invisibly; in one file, adding the first without the second is something a
reader sees. What that beat: leaving it in the root and relying on the rule alone, which is the same
arrangement that already failed once.

Rejected: disabling the row. It would answer "why can I not tap my Mac" with nothing, which is a
different unanswerable question. And rejected: removing the row, which leaves a discovery screen that
finds Macs and does not let you choose one — the app would then have no purpose a reader could see.

**What is still owed is the test that would have caught it**, and it is named here so it is not
forgotten: a behavioural test that taps a row and asserts something appears. That is the `ui` kind
this project has no target for, and this defect is what earns it.

