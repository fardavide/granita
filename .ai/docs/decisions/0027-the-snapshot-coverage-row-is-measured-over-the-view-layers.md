# The Snapshot coverage row is measured over the view layers, not the whole package

The parser landing dropped that row from 72.6% to 32.8% while the project's uncovered lines went from
72 to 73 — the covered line count did not move at all. The phone app links the diff modules through
its connection feature, so five hundred new lines joined the snapshot denominator, and rendering a
view executes none of them. Measured that way the row falls whenever domain code is added anywhere
under the app, which is a fact about the dependency graph rather than about the snapshots, and no
amount of testing the parser could have fixed it.

Scoped to the layers that draw, the row answers the question it exists for: of the code that draws
screens, how much does a baseline put on screen. Davide's call between three options. The Ui kind is
left unscoped, because a behavioural test drives the real app and reaching a repository and a parser
is exactly what it does.

Rejected: ratcheting that row on covered lines rather than a percentage, which would have passed
today and still caught a deleted baseline, but leaves a number in the table that nothing enforces the
meaning of. Also rejected: reporting the row without gating it, which keeps the dilution and loses
the signal.

**A redefinition un-judges its row for one run.** The summary now records what each kind's percentage
was taken over, and the gate compares two numbers only when both were taken the same way. Without
that, changing the measurement fails the very pull request that changes it — for the redefinition
rather than for a regression — and the only way through would be to disable the gate for one merge,
which is the habit this ruleset exists to prevent.

