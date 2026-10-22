# Native input is measured by behavioral coverage

Davide approved this measurement change on 22 October 2026 after the proposal was reproduced in
chat because its approval card was invisible. It follows the input extraction in 0242.

The last unchanged-policy [CI run](https://github.com/fardavide/granita/actions/runs/39755636556)
passed every functional job, Unit coverage and All-tests coverage. Snapshot coverage remained
99.2% lines and 97.6% regions against 99.4% and 97.9%. Its export identified four native gesture
context bridges and the action-time targeting constructor with no Snapshot executions. SwiftUI
offers no public initializer for the context or coordinate converter. Direct configuration and
dispatch checks and all six actual-touch tests already passed; neither a rendered baseline nor a
public real-window hosting experiment drove those context methods.

Input-only adapters and gesture modifiers live under `Ui/Input/`, inside their existing module.
Snapshot measures rendering and layout, excluding that directory in addition to its existing
action-closure exclusion. Domain input decisions retain their unit tests. Measured hunk layout
remains in Snapshot, including a direct check that a newer frame replaces an earlier measurement.
Frame bindings must still be read when input arrives, not in the rendering body.

Ui coverage is collected from the required behavioral execution, without repeating the six touch
tests. Its scheme also runs app-hosted Swift Testing adapter checks, in a separate bundle because
the out-of-process UI runner cannot provide that host. Profiles, mapping objects, successful test
receipts and the complete enumerated/completed inventory are required and hashed with the existing
revision, run-attempt, toolchain, source-root and source-digest provenance.

Snapshot receives a new scope identifier. Under the existing ratchet rules it is unjudged for this
pull request and establishes a baseline on the next successful main run; Ui establishes its first
baseline there too. Unit and All-tests scope identifiers and predicates remain unchanged. Their
numeric comparisons continue to apply. All-tests merges raw behavioral profiles with the other
kinds, while Snapshot never receives Ui profiles. No numeric gate, required suite, assertion,
image baseline, tolerance or inventory check is relaxed, and no stored baseline value is edited.

This supersedes the input-code portion of 0027's Snapshot scope and the then-empty Ui row in 0019.
The alternative was retaining the unchanged policy and leaving the pull request blocked while
seeking another way to execute input-only bridges through a snapshot. Approval covers this
collection and scope change; it does not authorize merging or publication.

The tooling suite passes 128 tests, including real-shell aggregation with fake platform commands:
it checks exact profile/mapping routing and refuses missing Ui artifacts before exporting counters.
The frame replacement check passes. A complete instrumented behavioral execution passes all six
touch tests and eleven parameterized adapter cases, with nine completed functions matching its
enumeration, no failures or skips, and a validated three-object manifest. Its first attempt failed
the pinned-first-file setup while the probe reported `waiting`; the unchanged focused case and
complete repeat passed. That first failure's cause is unverified, and no expectation was relaxed.

The full coverage command subsequently passed both iOS shards (21 and 58 functions) and all nine
behavioral functions without failures or skips. A source-filtered LLVM export of the behavioral
artifact records seven coordinator creations, seven native-recognizer creations, fourteen updates,
thirty-two action dispatches and thirty-four action-time targeting constructions. All five named
bridges that Snapshot had not executed therefore carry positive Ui counters; this is a diagnostic
of the collected artifact, not a substitute aggregate gate verdict.

Package tests, package instrumentation and both unsigned app builds pass. The full local coverage
run reaches the Mac host, whose result records eighteen image-mismatch failures and a canceled
menu test. After more than six minutes without progress and repeated `MDB_MAP_FULL` font-cache
messages, the run was interrupted (`make coverage` exit 130; child coverage-mac error 75). The
stall's cause is unverified. Both owned test processes stopped; the installed Granita app was not
interrupted. No successful Mac receipt or aggregate local coverage verdict is claimed. The Mac
comparison and final numeric verdict remain CI's responsibility, with no baseline re-recording.
