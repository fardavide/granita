# Prepare worktree summaries and refresh only the review that changed

The worktree list currently rebuilds every checkout's change metadata before answering.
The September profile attributed almost all server time to git, with enumeration a small
fraction. The selected change is a shared in-memory summary cache, warmed on the Mac and
invalidated by file and Git events. Cached summaries serve both HTTP and local readers.

Fresh diff, line, image and viewed-mark validation remain separate. A cached content hash
must never authorize a mark against bytes that have since changed. A content-sensitive
revision includes HEAD and the changed-file hashes, since porcelain status can stay identical
across edits to an already modified file.

The Mac publishes completed snapshots through an authenticated event stream; local readers
observe the same snapshots without HTTP. Reconnect reads current state and compares each
worktree's own content identity. Intermediate snapshots may coalesce because each carries
the complete inventory. No durable event replay or disk cache is required for this slice.

Davide approved automatic application of updates to the open worktree. This supersedes
SPEC section 10's required "Changes available" pill and the foreground-only restriction in
[0214](0214-coming-back-to-the-app-re-reads-the-worktree-list-and-it-is.md). Same-worktree
updates may reuse the existing full reload; incremental rendering and maintaining a reading
position through simultaneous edits are deferred unless straightforward.

Isolation across worktrees is mandatory. While A is being reviewed, edits or Git activity in B
must not reload A, display activity, move its content, or rearrange a visible sidebar. B advances
in the background and the list catches up when revisited. Shared Git metadata and reconnection
can require checking A, but only a changed identity or verified disappearance can change its
review surface. Summary-only writes such as viewed marks must not trigger content reload loops.

Observation uses actual worktree and Git directories, including external linked checkouts.
Bursts coalesce and scans are rate-limited without starving continuous edits. All git work
shares a concurrency ceiling. Wake and lost-event recovery reconcile with git; quiet worktrees
are not repeatedly hashed on a timer. Failed scans retain their previous successful answer and
its age rather than fabricating a clean worktree or fresh receipt.
Healthy projects can publish alongside those retained answers. A visible project whose first
scan has never succeeded prevents full-inventory publication, since omitting it would falsely
declare its worktrees gone to a reconnecting client.

The implementation and verification are tracked in
[the plan](../../plan/worktree-cache-live-updates.md); this decision records the agreed contract,
not a claim that every implementation check has completed.
