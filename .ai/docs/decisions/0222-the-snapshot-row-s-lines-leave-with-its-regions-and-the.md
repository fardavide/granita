# The Snapshot row's lines leave with its regions, and the 2026-09-04 reasoning for keeping them was a wrong model

Davide, on this slice's coverage report: *"Is there anything we should exclude by rule for snapshot
tests?"* and then *"Can you think of a solid rule for it?"* The answer was one rule that replaces two
half-rules, and adopting it corrected the entry above headed *An action closure leaves the Snapshot
regions column*.

**The rule.** The Snapshot row judges only what a render can execute. A line is in its denominator
when it is code and carries at least one region the regions column already counts. So an action
closure — a closure literal returning `()` — leaves both columns, not one, and the two columns
describe the same set of code again.

### Why the earlier entry kept lines, and why that was wrong

That entry measured **7 of 5043 lines** as belonging to a closure alone and concluded that an inline
closure "shares its lines with the view expression containing it", so removing them would remove the
body. That reading modelled a file's line total as a count over its source. **llvm-cov does not
compute one.** It computes lines *per function record*, from that record's own regions, and adds the
records up — `PairingEntryScreen` reports 72 lines over a 51-line span. A closure's lines are in the
total once for the body's record and once more for the closure's own, so the closure's share is a
separable whole, and the "7" was an artefact of the segment-based reading, not a property of the code.

The script now reproduces llvm-cov's own arithmetic for every scoped file, both counters, and
**refuses to run if the two disagree**. That self-check is what found the second thing the earlier
entry did not know: records that open at one source position form an *instantiation group* whose
figures merge by `max`. A curried `self.method` reference emits two closures at one column — a
thunk returning the action, count 4, and the action itself, count 0 — and llvm-cov counts that as one
line. The naive per-record sum gave two, `PairingOutcomeScreen` came out at 45 lines against
llvm-cov's 44, and the refusal fired. A group leaves only when every member is an action closure
whose spans no other record shares; a mixed group stays.

### The measurement, over one export

| | Before | After |
|---|---|---|
| Snapshot lines | 11070 / 11428, 96.9% | 10986 / 11072, 99.2% |
| Snapshot regions | 1851 / 1894 | 1851 / 1894, unchanged |

Regions unchanged is the check: the closures leaving the lines column are exactly the ones already
out of the regions column since 2026-09-04, and no new predicate crept in. Of the 356 lines that left,
84 were covered — `.task`, `onAppear`, `onChange` and geometry callbacks fire during a render — so the
rule takes covered lines out with the uncovered ones and does not merely flatter the number.

**One known imprecision, stated rather than fixed.** Fifteen of those 84 are an `enumerateAttribute`
block in `HighlightrSyntaxHighlighter`: a closure returning `()` that is a computation, not an action.
The predicate reads the return type and cannot tell the two apart; a predicate that read the call
site would be a parser of Swift. It lowers the number rather than raising it, it has been out of the
regions column since 2026-09-04 for the same reason, and the `swift-testing` skill now says in as
many words that writing view logic as a `-> ()` closure to take it out of the row is not a licence.

The scope string is renamed `views-and-screens-no-action-closures-per-record`, so the Snapshot row
is unjudged for exactly one run and rejoins the ratchet on the next `main` run. That is the seventh
rename, and the first that corrects a previous one rather than a previous scope.

