# A new Mac baseline needs a placeholder pushed first, because a missing one never reaches the artefact

The adoption round trip — push, let `Snapshot tests (macOS)` fail, `gh run download … -n
snapshot-diffs-mac`, `Scripts/adopt-mac-baselines.py` — works for a baseline that **changed** and
silently does nothing for one that is **new**. The report is built from `__SnapshotFailures__`, and
swift-snapshot-testing does not write there when there is no reference: it records the image into
`__Snapshots__` and fails that run instead. So the artefact for a first run of a new test is the
script's own "no snapshot mismatches were captured" placeholder, and there is nothing to adopt.

**So a new baseline lands in two commits.** The first pushes this machine's renders as placeholders,
which turns "no reference" into a mismatch; the second replaces all of them with the runner's. Both
commits say which they are, because a placeholder left behind is exactly the locally-recorded baseline
this whole arrangement exists to prevent — and it would be green on the run that introduced it and red
on every run after.

Rejected: recording on CI with `record: true` behind an environment variable, which is the same
"suite that cannot fail" the `swift-testing` skill forbids, aimed at a narrower target. And rejected:
teaching `snapshot-report.py` to emit a section for a newly-recorded image, which cannot work — the
job's checkout is what the report reads, and a newly-recorded image is only ever on the runner's disk
inside a directory the failing step does not upload.

Written down because the failure is silent in the worst way: the script prints `0 baseline(s)
adopted`, which reads like "nothing needed adopting" rather than "there was nothing to adopt".

