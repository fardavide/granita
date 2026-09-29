# Advanced ships without its Diagnostics half, because Granita has no logging at all

Design §7 draws a verbose switch and an **Open in Console** button beside it, with the footnote
*verbose logging records every request and every git invocation until you turn it off*. Both were
built on a premise nobody had checked: there is **no logging anywhere in this product**. Not a
`Logger`, not an `os.log`, not a print — the whole package, searched.

So the switch would turn on nothing and the button would open a Console filtered to a subsystem that
never writes. A control over an absent subsystem is worse than an absent control: it reads as a
feature, it is pressed, and what it reports is silence that looks like "nothing is wrong".

**They land with the logging they describe**, which is its own slice — a seam in `Domain`, an
`os.Logger` behind it, and call sites at the request boundary and at every git invocation, because
that is what the footnote promises. Advanced ships now with the two rows that stand on their own: git,
and the data folder with Reset.

**And Console cannot be filtered from outside, which is settled before that slice starts.**
`Console.app` registers **no URL scheme** — its `Info.plist` has no `CFBundleURLTypes` at all — so
nothing can hand it a predicate. Davide chose, on 22 August 2026, that the button opens Console and
puts the predicate on the pasteboard, so one paste finishes it. What that beat: opening Console
unfiltered, which is the exact failure the review says the button exists to prevent — *a level control
with no route to the log leaves a person choosing how much of something they cannot find*; and running
`log stream` in Terminal, which is genuinely filtered and leaves the reader in a different app,
holding a process this one does not own.

**The lock-file row is absent for the same shape of reason**: SPEC §9's lock file is not built, so the
row that reads its refusal has nothing to read.

