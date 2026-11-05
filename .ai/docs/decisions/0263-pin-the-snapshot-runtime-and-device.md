# Pin the snapshot runtime and device

Snapshot, native interaction and TLS validation select a supported iPhone under **iOS 27.0**, the
runtime used to record the committed phone baselines. One shared selector returns its device UUID;
boot and test destinations use that UUID rather than a name with `OS=latest`. Missing baseline
runtime or requested phone fails explicitly. Package-only checks do not discover simulators.

This supersedes [0246](0246-simulator-selection-retains-the-newest-supported-runtime.md)'s newest
supported runtime policy. Runtime changes require deliberate validation; a runner image update
must not silently change what a baseline comparison measures.

In [CI 42020856052](https://github.com/fardavide/granita/actions/runs/42020856052), shard 0 used
runner image `20261104.0337.1`, whose inventory adds iOS 27.2. Its native test result confirms
`iPhone 18 Pro`, iOS **27.2**, build `24B8117`, and 96 image mismatches. Shard 1 used the previous
image `20261026.0314.1`; its native result confirms the same phone on iOS **27.0**, build `24A434`,
with 582 passing executions. Both jobs selected Xcode 27.0 (`27A266a`), so the compiler selection
did not pin the test runtime. The failing list/form captures move inner content inward by 4pt.

A dry-run regression supplies the same phone name under both runtimes and exercises the real
Makefile destination. Before the change it fails: `OS=latest` instead of the baseline runtime.
Public selector cases cover duplicate names across runtimes, absent baseline runtime, unsupported
models and an explicit phone request. A second controlled RED supplies a non-default UUID to the
real collector and observes it rediscovering and testing the wrong phone; the repair carries the
supplied UUID through enumeration, boot, snapshots, TLS and gestures. All 139 tooling tests and
12 focused app-icon image executions pass. Baselines, rendering code and comparison thresholds stay
unchanged; this does not claim a production rendering repair on iOS 27.2.
