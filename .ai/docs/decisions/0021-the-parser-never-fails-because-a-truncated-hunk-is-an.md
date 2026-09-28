# The parser never fails, because a truncated hunk is an ordinary input

The size guard hands it the first two thousand lines of a large diff, so a hunk that stops half way
through is what the guard promised rather than corruption. Throwing would turn every large file into
an error. Anything unrecognised is skipped and everything before it is kept, so the declared hunk
counts stay as git wrote them while the body is simply short — which is what lets the client show
"the first N lines" honestly.

Rejected: typed throws with a malformed-input case. It would be a case no caller could do anything
with, on an input the product produces on purpose.

