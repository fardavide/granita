# One clipboard read held every phone baseline hostage

`SystemDiagnosticPasteboard`'s UIKit branch wrote `UIPasteboard.general` and took no name, so the only
way to assert it was for a test to save the **shared system pasteboard**, write, read back and restore
it. Reading `items` off the general board waits on a simulator daemon that does not reliably answer,
and when it does not, the test host sits at 0% CPU forever — with every one of the suite's ~936
baselines behind it, because the suites are `.serialized` and share one window.

It presented three different ways and none of them looked like a pasteboard: a run that sat 48 minutes
with the test host never launching, a run that crash-looped and restarted three times reporting "12
tests passed", and a run that blocked for an hour. The only thing they had in common was the test that
ran immediately before.

**The fix is the seam the AppKit branch already had.** That side takes an `NSPasteboard.Name` for
exactly this reason — its own comment says a suite may not write the developer's clipboard on every
`make test` — and the UIKit side now takes a `UIPasteboard.Name?` the same way, defaulting to the
general board so nothing about the shipped behaviour changes. The name travels rather than the
instance, because `UIPasteboard` is not `Sendable` and this type is. A named board is private to the
process: no save, no restore, nothing outside to wait on.

> Rejected: skipping the test in `make snapshots`. It would have unblocked the suite the same day and
> left a real integration test — *did Copy Logs put the report where a paste would find it* — running
> nowhere, which is the half of this the unit tests genuinely cannot answer.

**What made it findable was deleting `-quiet` from the Makefile's long `xcodebuild` runs.** With it,
a healthy run and a blocked one produce identical output — nothing — so the only way to tell them
apart is to go looking for the test host process by hand. The two signals worth keeping: is the app
process alive, and are PNGs appearing. Neither is visible in a quiet run.

