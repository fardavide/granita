# The coverage gate keeps its build directories, and boots the simulator before it needs one

*(1 September 2026, 0.6.1)*

The Coverage job took 20m30s against a 1m56s unit job and a 2m09s build job, and the reason was never
the measuring. Read off the 1 September `main` run (`da17334`, job 99827756013): 1m01s of prologue,
**5m27s** of unit pass of which 5m02s was building the package, **10m36s** of iOS pass, 2m55s of macOS
pass of which xcodebuild reported **14.2s** as the actual test operation, and 31s of merging and
export. Three cold builds and a boot, wrapped around about six minutes of tests.

Three things were paid for and none of them bought anything.

**The package was built from scratch to run 25 seconds of tests.** `Unit tests (Granita)` caches
`Packages/Granita/.build` and finishes the entire job in 1m56s; this one cached nothing. It now has
a cache of its own — and a directory of its own, `build/derived/package`, because these objects carry
coverage instrumentation and sharing `.build` with `make test` means each command invalidates the
other's build every time they alternate. That is the local half of the same fix: two directories,
two warm builds.

**A warm package directory is only honest if `codecov/` is emptied first.** SwiftPM merges *every*
`.profraw` in that directory into `default.profdata`, so a raw counter file left by an earlier run of
an earlier commit would be added to this run's numbers — coverage credited to lines these tests never
executed, and possibly to lines the commit no longer has. It could not happen while the directory was
rebuilt from nothing each time, which is exactly why caching it is the change that introduces it. The
script deletes the directory before the pass. **A wrong number is worse than a slow job**, and this
repository has spent enough on the arithmetic of which file moved a row to want no doubt about the
denominator.

**Nothing booted the simulator, so the job stopped and waited for it.** Left to `xcodebuild` the boot
happens after its build finishes: the iOS pass reported 8m49s for a suite whose test bodies account
for 5m30s, and the sibling snapshot job on the same commit showed a **9m31s** gap between the app
bundle being touched and the app's first log line — `xcrun simctl list` alone took 74s on that runner,
which is what a cold CoreSimulator looks like. The boot now starts immediately before the iOS pass,
so it runs against `xcodebuild`'s own build of the app — which needs no device until it starts
testing. Its failure is swallowed: `xcodebuild` boots the device itself, slowly, and turning a
warm-up into a red run would trade minutes for false alarms.

**It was first written to boot before the *unit* pass, and the runner rejected that outright.** The
reasoning had been that the unit pass needs no simulator, so the boot was free there — but a
simulator booting beside the package build starves it. Measured on this change's own first run, #62:
the unit pass went from 5m27s to **15m16s**, the suite's own wall time doubled from 25s to 50.3s, and
the job went from 20m30s to **38m06s** while trying to get faster.

**The wall clock was the smaller half of that.** The unit pass is `--no-parallel` because this suite's
coverage number moves with how busy the machine is — five runs of one commit once reported two
different numbers — so a booting simulator beside it feeds noise into the measurement that flag exists
to remove. An optimisation that competes with the thing being measured is not an optimisation. What
survives is the overlap that costs nothing: a boot against a build that wants no device.

**`Snapshot tests (iOS)` got the same head start, because it was the job actually being waited on.**
It is where the 9m31s gap was measured, it reported 946s against the coverage job's 529s for the same
suite on the same commit, and at twenty minutes it outlasts the coverage job even after everything
above — so fixing one and not the other would have moved a number without shortening a single pull
request. **It is also the one place the head start was an unambiguous win: 19m54s to 10m53s on #62**,
because there the boot overlaps an app build and there is no host suite beside it to starve. It boots
with `simctl boot`, which returns as soon as CoreSimulator has taken the request and lets the daemon
carry it across the step boundary — a backgrounded child of one `run:` step cannot be relied on to
outlive it. It fails when the device is already booted, which is the outcome wanted anyway.

The derived data directories moved out of `build/coverage` for the same reason — the script wipes that
directory on every run, which on a fresh runner costs nothing and on a developer's machine meant two
from-scratch app builds per `make coverage`. What still must not survive is the profile, since both
app passes find theirs by searching the tree for `Coverage.profdata` and taking the first hit; Xcode
writes exactly one, under `Build/ProfileData/<device>/`, so that subtree alone is deleted.

Rejected: parallel testing, in either the unit pass or the snapshot passes. The unit pass is
`--no-parallel` for a recorded reason — five runs of one commit reported two different numbers — and a
ratchet with no slack cannot absorb a suite that measures the machine instead of itself. Rendering
views across simulator clones is the same bet at longer odds. Rejected: having the job reuse the
profiles the two snapshot jobs already produce rather than running those suites again. It removes
about thirteen minutes from this job but serialises it behind a twenty-minute one, so the wall clock
a pull request actually waits through barely moves — and the duplication is deliberate anyway, so a
stale baseline reddens one job rather than two.

