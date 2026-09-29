# Every argument carries its own terminator, and two files reviewed as empty for want of one

Davide photographed a ten-file worktree in which two files drew a header, their counts and then
nothing. Reproduced against the same worktree through `granita-server --insecure-http`: `/changes`
named all ten correctly, and `/v1/…/files/<id>/diff` came back with **zero hunks** for exactly those
two, on every request, while the same `git diff HEAD -U3 -- <path>` run by hand printed 1,494 bytes.
Same binary, same working directory, same environment, opposite answers — which is the shape of a
difference in what the child process was actually handed.

**It was the argument vector, and the corruption is in the library boundary rather than in the
vector.** `Arguments` has a byte-array form, which is what this product uses because a path on disk
is bytes and decoding one to re-invoke on it addresses a file that does not exist. That form stores
each element as raw bytes and, when the process is spawned, hands each one to `strdup` — which copies
until it meets a zero byte. A Swift array carries its length beside it and nothing after it, so an
element with no terminator is copied out of the array and on into whatever the allocator left next to
it. Which arguments that happens to depends on the size of the allocation and on what is beside it,
which is why it was two files out of ten and the same two every time.

**Everything after `--` is a pathspec, which is where this is silent.** A pathspec matching nothing
makes `git diff` print nothing, write nothing to standard error and **exit 0** — indistinguishable
from a file with no changes. So a corrupted flag would have failed loudly and a corrupted path failed
as an empty diff, which the viewer draws as a file with an empty body. The change set was right
throughout, because every command that builds it — `status`, `diff --raw`, `diff --numstat`,
`ls-files` — carries no path at all.

**The terminator is added in `ProcessGitClient` and not in `GitInvocation`**, because it is a
requirement of the library that spawns the process rather than of the way git is spelled. SPEC §5.1
asks for the argument array of each command family to be asserted, and those assertions read the
vector as text; a terminator baked into it would put a trailing `\0` through every one of them and
would also be wrong for a backend that is not a subprocess. `GitInvocation` keeps answering "how is
this command spelled", `ProcessGitClient.terminated` answers "how is it handed over", and the test
asserts both halves — one zero byte, at the end, and the vector otherwise unchanged.

**What the regression test can and cannot be.** Whether an unterminated argument is corrupted at all
depends on the heap, so a test that runs git and asserts a non-empty diff would pass on most runs
with the defect still in place — a test that cannot fail reliably is worse than none. The invariant
is what is asserted instead: every element handed to the library ends in exactly one zero. That is
the property whose violation caused this, stated where it can be checked deterministically.

