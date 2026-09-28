# An action closure leaves the Snapshot regions column, and the entry above is what it answers

Davide, on reading the row above: *"We should exclude untestable closure from tests coverage."* The
entry above is the fifth slice to report the same structural gap and the first to be asked to close
it rather than document it again.

**The rule.** In the views scope, a region that belongs *only* to a closure returning `()` is not
counted. Such a closure is an action — a `Button`'s, an `onChange`, a `.task`, an `onAppear` — it
draws nothing, and a baseline presses nothing, so it is outside the question the row asks rather than
merely untested by it. That is the `UNREACHABLE_FILES` bar, *unrunnable by this kind of test by
construction*, applied at the only granularity that can express it: an action closure shares a file,
and usually a line, with the view it sits in, so no file-level predicate reaches it.

**A named method returning `()` is not an action, and that is where the line is drawn.** A method has
a name, so a test can call it; a closure literal has neither a name nor a seam. Thirty-five of the 186
partly-uncovered records in the views scope are named methods and all thirty-five stay judged.

### Regions only, and that is a measurement rather than a shortcut

**Corrected on 2026-09-18** — the entry headed *The Snapshot row's lines leave with its regions*
shows that the "7 of 5043" below came from modelling the line total as a count over the source,
which llvm-cov does not compute. Both columns leave out action closures now.

Over the whole views scope the exclusion takes **200 of 1695 regions** out of the denominator and
**7 of 5043 lines**. A closure written inline is spanned by the view expression containing it, so its
lines *are* the body's lines and removing them would remove the body. So the line counter is untouched
and still judged exactly as before; only the region number changes basis, **87.8% → 97.5%**.

That asymmetry is the finding. The row had been read as "lines and regions both say a snapshot cannot
press a button", and only one of them was ever capable of saying it.

### Three ways this was tried before the one that worked

- **`llvm-cov export --name-allowlist`.** The flag exists and `export` silently ignores it — the same
  1485 function records come back with and without it, and the file summaries are identical to the
  byte. `report --show-functions` does honour the name filters, but its totals do not agree with the
  file summary either (130 regions against 126 for `WorktreeDiffScreen`), so it is not a substitute
  basis.
- **Recomputing both counters from the function records.** Regions reproduce the file summaries
  *exactly* — 1489/1695 across the scope — which is what makes the subtraction below exact rather than
  approximate. Lines do not: llvm-cov's line summary is per-instantiation, so it counts 430 lines in a
  394-line file, and a deduplicated recount gives 99.0% where the summary gives 97.0%. Switching that
  basis would have replaced a judged number with one that has no headroom.
- **Subtracting from the summaries, which is what shipped.** The base stays the file summary every
  other row is taken from, and an export carrying no function records subtracts nothing — which is the
  honest reading of "this run identified no action closure", not a fallback to zero.

### The predicate parses; it does not match `-> ()` anywhere in the string

`xcrun swift-demangle --compact` is the only thing that reads the mangling, because the grammar is an
implementation detail of the compiler shipped beside it. The parse then anchors on the *first* arrow
of the *first* closure, and both halves of that are load-bearing:

- A demangled closure carries its enclosing context after ` in `, so
  `closure #1 () -> SwiftUI.Text in …configure() -> ()` is a **ViewBuilder inside a void method**.
- A closure taking a closure puts an arrow inside its parameters, so the parameter list is scanned to
  its own matching bracket rather than to the first one.

Both are tested, and both are cases where the looser predicate fails in the direction that looks like
good news — a view dropped out of the denominator, raising the number.

### What it costs, recorded rather than discovered later

View code is judged by this row and no other, so **an action closure's body is now judged by nothing**.
That is bounded by an architecture rule the project already has and review already enforces: a
screen's action closure is one call into a model, and the model is judged by the Unit row. The
`swift-testing` skill now carries it as a rule — a closure that grows a branch has outgrown a view,
and moving it to the model is the fix rather than counting it here.

The scope string is renamed `views-and-screens-no-action-closures`, so the Snapshot row is unjudged
for exactly one run and rejoins the ratchet on the next `main` run. That is the sixth rename and the
first that narrows *within* a file rather than by file.

