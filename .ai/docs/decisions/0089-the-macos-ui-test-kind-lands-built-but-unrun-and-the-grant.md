# The macOS UI test kind lands built but unrun, and the grant it waits on is Davide's

The kind this project has owed since a dead control shipped for eight releases. A baseline
photographs a row whether or not the row leads anywhere — that is how the discovery list's
`NavigationLink` to nowhere stayed green through four layouts for four releases — so the only check
that catches one is a test that presses the thing and reads back an effect.

It was written and abandoned three times on 23 August 2026, each failure naming the next constraint,
and the sequence is worth keeping because none of the three messages says what is wrong:

1. `CODE_SIGNING_ALLOWED=NO` gives **"Test crashed with signal kill before establishing
   connection"**. A UI test bundle is not loaded into the app — it is a separate runner app that
   launches and drives another process — and an unsigned runner is killed before it can connect. So
   this is the one target in the repository that is **signed**, and `make ui-tests-mac` omits the
   flag every other target passes.
2. Signed, it gives **"Cannot code sign because the target does not have an Info.plist"** — naming
   the *snapshot* bundle while the UI bundle is the one being run. No test bundle here had ever been
   signed, so none had a plist. `GENERATE_INFOPLIST_FILE` goes on **both**.
3. Signed and with a plist, it gives **"The test runner failed to initialize for UI testing. (Timed
   out while enabling automation mode.)"** That one is not a project setting. It is the Accessibility
   privilege the runner needs, under System Settings › Privacy & Security › Accessibility, and it is
   Davide's to grant. **The target has therefore never been seen to pass.**

### Three invocations had to be scoped before the bundle could join the scheme

Adding it to the `GranitaMac` scheme means every invocation of that scheme runs both kinds. Without
`-only-testing`, the `Snapshot tests (macOS)` job would start driving the app as well as
photographing it — turning a green job red in the job least able to explain why, and on a runner with
no Accessibility grant either. So `-only-testing:GranitaMacSnapshotTests` is on `make snapshots-mac`
**and on the CI job**, and `make ui-tests-mac` carries the other half.

The bundle is still **built** by that job, which is the only thing keeping it compiling until
something runs it. Verified rather than assumed: a `build-for-testing` over the scheme produces
`GranitaMacUiTests-Runner.app` unsigned, so the signing requirement is a runtime one and CI's
`CODE_SIGNING_ALLOWED=NO` does not break the build.

### The `ui` coverage row is deliberately not wired in the same pull request

The report has always had a row for this kind and it has always been absent. Filling it here would
mean measuring an out-of-process profile that nobody has ever produced, on a target that cannot yet
run — and a near-zero row becomes the ratchet baseline the moment it is recorded. It lands with the
first green run, not with the target.

### XCTest, in this bundle and nowhere else

`XCUIApplication` is XCTest-only; there is no Swift Testing equivalent. The `swift-testing` skill's
rule is unchanged everywhere else in the repository, and this is the exception rather than a
loosening — the bundle is the boundary.

### The app is driven against a store in a temporary directory

`--store` is why `MacLaunchOptions` exists, and this is the case it was built for: without it the
test would drive the reader's own document on a real Mac and switch a real repository on, which is
the one thing the Projects tab must never do by accident. `--open-settings` is the other half —
Granita has no window until its menu is opened, so a test would otherwise have to hunt a status item
in the menu bar before it could assert anything. Both go through the same call the menu uses, so what
a test opens is what a reader opens.

The assertion is read back from the **document**, not from the screen. A row that redraws itself
while nothing is written is precisely the defect this kind of test exists to catch, and a test that
read the toggle back off the toggle would pass in that case.

