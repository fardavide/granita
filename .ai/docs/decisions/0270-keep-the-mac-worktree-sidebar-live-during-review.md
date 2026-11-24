# Keep the Mac worktree sidebar live during review

When a diff is open on the Mac, its sidebar still shows the list the reader uses to choose their
next worktree. Apply snapshots as they arrive so the visible list reflects changes to other
worktrees. Reload the open diff only for its own changes.

This supersedes the Mac sidebar deferral in
[0265](0265-prepare-worktree-summaries-and-refresh-only-the-review-that-changed.md). The iPhone and
iPad continue to hold sidebar updates during review.

Remove the Mac sidebar's toolbar Refresh button. This Mac uses the existing age footer to say
“Updated … ago” based on the successful scan receipt. Keep View → Refresh for explicit reads,
including from older sources, and Try Again for failures.
