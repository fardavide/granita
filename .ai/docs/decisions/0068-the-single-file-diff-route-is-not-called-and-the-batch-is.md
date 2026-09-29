# The single-file diff route is not called, and the batch is why

SPEC §8 lists both `/v1/worktrees/{id}/diffs?fileIDs=…` and
`/v1/worktrees/{id}/files/{fileID}/diff`. The client calls only the first, with one identifier when
it wants one file.

They are the same answer through the same code on the Mac, and a second way to ask a question is a
second place for it to be answered differently — a divergence that would show up as one file
rendering differently depending on whether it was prefetched or opened. The route stays served,
because removing it is a contract change and nothing is gained by making one.

