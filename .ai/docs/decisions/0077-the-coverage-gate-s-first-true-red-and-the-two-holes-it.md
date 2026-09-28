# The coverage gate's first true red, and the two holes it found

Three of its reds have been noise — measured, and recorded above. This one was not, and telling them
apart took the same method both times: measure both sides locally, through `coverage.py`'s own scope
filter, and read the per-file export.

**The Unit row went *up* +0.2 while `All tests` regions fell 0.9%**, which is far outside the ~0.3%
spread. That divergence is the signature: the unit profile is `swift test`, and the merged profile
also links the Mac app, so a module the package does not link is invisible to the first and counted
at zero by the second.

**`Server/Mac/Data` was that module.** Nothing in the package depended on it — the composition root
is an app target — so `ProcessGitInstallations` had no test and no row in the unit export to say so.
It now has a test target of its own, which is the fix for both: the failures each carry git's own
words, and that is the whole point of the row they feed.

**And `GranitaSettingsScreen` was the second**, in the views scope and rendered by nothing, so every
line the Advanced tab added to it went straight into the denominator. It is now rendered with six
fakes held in the snapshot bundle, which is the same trade the `Api` and `Mac` suites already make:
test targets cannot import each other, and the alternative ships doubles in the binary a reader
installs.

**Closing the first hole opened a third, and it is a scope correction rather than a gap.** Giving
`Server/Mac/Data` a test target linked it into the unit profile for the first time — which brought
`ServiceLoginItemRegistry` with it, at **0 of 15 regions and 0 of 25 lines**. It had never been
judged, only invisible.

It is exempted, on the bar `UNREACHABLE_FILES` already sets and not on the arithmetic: every line of
it is a call on `SMAppService.mainApp`, which is the *running main bundle* — in a test process, the
unsigned test runner. Running it means either failing for want of a signature or writing the test
binary into the developer's real Login Items. That is the same class as the two Keychain stores,
which are exempt because a SwiftPM test binary is unsigned and has no keychain: **unrunnable by
construction, not merely untested.**

The honesty check this project applies to a rescoping is whether it flatters a number, and this one
*does* raise it — 90.4% to 91.4% — which is why the justification is the bar rather than the
direction. The distinguishing fact is that the file entered the scope and was exempted in the same
breath, rather than having been measured and then excused. The scope string is renamed from
`…-no-keychain-…` to `…-no-system-services-…`, so the Unit and All rows go unjudged for one run and
rejoin on the next `main` run. That is the third time these rows have been unjudged, which is a real
cost and is named here rather than left to be discovered.

**Two things that baseline cannot do, stated so they are not assumed.** It does not capture the tab
bar — a `TabView` hosted in a plain window draws the selected pane and no picker, because the
segments come from the `Settings` scene and a test bundle has none, so tab order and symbols stay
reviewed in code like the accent tint. And the model must be **driven** first: the screen does not
start the server, the composition root does, so a screen rendered straight after construction reports
`.starting` whatever it was handed — a baseline named "serving" showing "Starting…" asserts the
opposite of its own name, which is what the first attempt at it did.

