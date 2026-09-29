# The connection log's elapsed time is handed in, which is what makes the panel photographable

The row drew its time with `Text(_:style: .relative)` — live, correct on screen, and measured against
the moment of rendering. That is why the macOS snapshot kind landed with only this panel's *empty*
state: a baseline of a populated row read "3 minutes ago" the day it was taken and "2 days ago" the
week after, so there was nothing to compare against.

So the view takes `now` as a value and computes the elapsed string from it. A populated row is then a
pure function of a fixed clock and a fixed list, and four states of the panel have baselines that
previously could not exist. The screen supplies the clock from a `TimelineView` on a per-minute
schedule, which is both the cheapest thing that can move it and exactly as often as a row changes —
the coarsest unit this row prints below an hour is a minute.

**What it beat is `.relative` plus an excluded test.** Snapshot testing has a way to say "compare
everything except this rectangle", and using it here would have kept the live time and bought a
baseline for the rest of the row. It loses on what it hides: the time is the widest column on the
right-hand side, so excluding it also stops the baseline from catching the row growing into it, which
is precisely how the long `pairingNotRecordable` sentence misbehaves. A value the view is given is
also the thing a `Ui` module is supposed to be — it renders what it is handed and derives nothing.

**A second locale trap came with it, and it is the same one the clock had.** The count is routinely
four digits, and `Int.formatted()` reads `Locale.current` — the *process's* locale, which a SwiftUI
environment cannot pin. Identical code wrote `1,284` on the runner and `1.284` on an Italian laptop.
The number goes through `Text`'s own format interpolation instead, which resolves against the
environment, so the pinned `en_US_POSIX` reaches it. Worth writing down because the mechanism is
invisible: both spellings are correct, both look deliberate, and only a cross-machine run says which
one a baseline is holding.

