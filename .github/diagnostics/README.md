# Temporary native motion recording

This branch records the original iOS motion checks without changing their assertions, fixtures,
baselines or deadlines. It does not provide a required coverage receipt or repair the reader.

The CI workflow runs the complete original iOS group 1. Recording starts when its native motion
test reports readiness and lasts at most ten seconds; the remaining tests continue afterwards.
The complete-group recording requires collapse begin/end markers. The focused local recording
requires selector markers. Clock attachments identify each collapse parameter combination and
allow its native frame trace to be correlated with the recording.

The standard Time Profiler records waiting threads through the checked-in recording options.
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
```

Preserve a previous `build/native-motion-profile` directory before starting another run.

On 2 November 2026, the final complete-group protocol passes all 580 executions across 64 test
functions, with no skips or structured runtime warnings. Its trace is 8.3 MiB and source
fingerprints match after restoration. Independent source review finds no blocker. These local
results do not establish the cause of the remote failure or prove that required CI passes.

The earlier long Thread Activity trial is discarded. It exhausted disk during export despite
all tests passing; the affected checkout and free space were recovered before further recording.
The retained recorder uses no additional instrument and does not control the host desktop.
