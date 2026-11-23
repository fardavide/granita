# Isolate worktree scan failures and preview stale cleanup

Git can enumerate a linked worktree whose administrative link is missing. The failed scan for
that checkout used to prevent its project from publishing, including its readable siblings.

A successful enumeration and a successful change scan are separate facts. Commit readable
summaries and retain the previous summary and timestamp for each failed scan. A project whose
enumeration fails retains its last known inventory. A reader that can interpret scan issues
opts into partial snapshots on reads and the event stream. An absent row is authoritative only
when the relevant inventory is known. Legacy readers continue receiving complete inventories.

*Try Again* rescans the affected checkout or project through the same cache. Git's prunable
marker can produce a *Repair…* action. The Mac runs a prune dry run, supports Git's known
missing-link diagnostic, and presents the affected registrations in the repository. The phone
can confirm the one-use preview on its own. The Mac resolves the worktree against its enabled
projects and reruns the dry run before moving the approved Git administrative directories into
a backup in the common Git directory. This keeps the Git index and history recoverable and
limits the write to the entries the reader approved. Git's repository-wide prune is unsuitable
for applying the preview because external worktree changes can add to its scope.
