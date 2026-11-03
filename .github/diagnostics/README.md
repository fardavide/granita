# Temporary native motion recording

This branch records the original iOS motion checks without changing their assertions, fixtures,
baselines or deadlines. It does not provide a required coverage receipt or repair the reader.

The CI workflow runs the complete original iOS group 1 with simulator video and no CPU profiler.
The recorder explicitly requests viewed/wordDiff in a complete-group run, or the selector in a
focused run. Other tests cannot start that recording. Readiness metadata identifies the actual
requested case. The first processed native video frame releases the test's setup gate; capture
then lasts ten seconds before SIGINT finalizes the movie. The remaining tests continue afterwards.
The native phase interval must fit between first-frame readiness and stop request on the same
Mach absolute clock. A nonempty movie without that temporal coverage is rejected.

Video is an independent observation of pixels, not a guarantee that every physical refresh was
captured. Intermediate positions can disprove an apparent single-frame jump in a stalled
main-thread observer; absence of those positions still requires checking recording cadence.
The original motion assertions continue to pass or fail independently of the recording.

The optional CPU mode uses the standard Time Profiler and records waiting threads through the checked-in recording options.
Recorded input must confirm both waiting-thread recording and sampling of all thread states.
Sample weights therefore include waiting: do not describe their total as CPU time or compare
that total directly with the earlier CPU-only recordings.

The recorder verifies the simulator app's process, retains recording options and their checksum,
and preserves source fingerprints, instrumentation, object UUIDs and test inventory. It requires
eight GiB of free space before instrumenting. Original source copies are saved before applying
the temporary patch and renamed back only if the instrumented source still matches our copies.
Unexpected source edits leave the saved originals available for recovery. Failure to copy
diagnostic metadata does not skip protocol-file cleanup.

From a fresh output directory:

```sh
make profile-ios-motion
make profile-ios-motion IOS_PROFILE_FULL_SHARD=YES
make profile-ios-motion IOS_PROFILE_FULL_SHARD=YES IOS_PROFILE_RECORDER=VIDEO
```

Preserve a previous `build/native-motion-profile` directory before starting another run.

On 2 November 2026, the final complete-group protocol passes all 580 executions across 64 test
functions, with no skips or structured runtime warnings. Its trace is 8.3 MiB and source
fingerprints match after restoration. Independent source review finds no blocker. These local
results do not establish the cause of the remote failure or prove that required CI passes.

The earlier long Thread Activity trial is discarded. It exhausted disk during export despite
all tests passing; the affected checkout and free space were recovered before further recording.
The retained CPU recorder uses no additional instrument. Neither mode controls the host desktop.

The video handshake, command-line rejection and capture-clock receipt have failing-before/passing-
after checks. All 143 tooling tests pass locally. On 3 November, the complete video protocol passes
all 580 original executions, with no skips or structured runtime warnings. Case selection and
temporal coverage pass, source fingerprints match after restoration, and a shortened-window
negative control is rejected. The finalized 9.99-second movie contains 281 frames; a decoded frame
confirms the actual word-diff transition. Independent review finds no remaining blockers.
These are local diagnostic results, not evidence that required CI is repaired.
