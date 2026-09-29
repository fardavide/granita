# The truncation footer says what was served, because what exists is not on the wire

Design §3's frame prints "Showing the first 1,000 of 1,314 changed files." **The second number does
not exist on this client.** `WorktreeChanges` carries `isTruncated` and a file list, and its stats are
summed over the files that were *kept* — the server truncates before it counts — so a total would have
to be invented.

So the footer says how many are shown and that the Mac does not serve more at once. It keeps the half
of the frame that matters, which is §3's own instruction: say "not served" rather than "load more",
because the Mac's limits will not serve them and a button that cannot succeed is worse than a
sentence. Adding the total to the wire is a contract change on both ends for one line of copy, and it
is not one this slice asked for.

