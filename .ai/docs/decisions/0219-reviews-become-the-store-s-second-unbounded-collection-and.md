# Reviews become the store's second unbounded collection, and the worse one

§9 names `viewed` as the only collection that grows without bound, and this slice ends that. Reviews
accumulate per worktree, a comment carries an excerpt, so a review is kilobytes where a viewed mark is
bytes — and the worktrees they belong to are created and destroyed by an agent rather than by a
reader.

`viewed` could not be pruned or capped as §9 requires because the code stores neither of the fields
that would make it possible: it is a file-path hash to a content hash, with no worktree and no date,
where §9 specifies both.

> **Corrected while building it: this is not a wire change.** The route is
> `POST /v1/worktrees/:worktreeId/files/:fileId/viewed`, so the worktree has been in the path the
> whole time — it stopped at the route handler and never reached the store. The fix is entirely
> behind the API, no contract bump and no client change, which makes it far cheaper than this entry
> first claimed.

**A second defect fell out of the same shape, and it is the worse one.** A file identifier is a hash
of a repository-relative path, so one file in two checkouts of a project is one identifier. With no
worktree on a mark, marking a file read in one worktree drew it as read in the other whenever their
content agreed — which, between two branches of one repository, is most of the files in them. A diff
silently drawn as already-read is the one failure this feature must not have.

**Version 1's marks are dropped rather than migrated.** They carry no worktree and none can be
inferred, and a mark assigned to the wrong worktree hides a file the reader has not seen. Dropping
them costs a reader one pass of re-marking; guessing costs them a review. The old shape is still
decoded rather than ignored, so a `viewed` key that is neither shape still makes the document
unreadable instead of quietly emptying a collection this version would then write back.

**Pruning is a rule rather than a control**, on the same startup pass for both collections: drop what
belongs to a worktree that no longer exists. There is no Mac-side button to clear a review — clearing
is the reader's act at the moment of pasting, and a Mac-side button would destroy a review a phone
might still be holding unsent.

