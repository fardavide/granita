# The routes stopped owning how this Mac is read, and that is what the merge was for

Issue [#97](https://github.com/fardavide/granita/issues/97)'s premise is that the Client's
repository protocols are already the boundary, so a merged Mac app binds them to the server's own
implementations and the diff arrives without a socket. **Reading the code showed the boundary was in
the wrong place**, and this is the correction.

`GranitaRouter`'s handlers were not thin. Between the registry and the wire they carried the
behaviour that actually decides what a reader sees: folding the store's viewed marks into the git
call, running four git processes at a time and returning them in the order they were asked for,
taking a rename's committed side from its **old** path because `HEAD:<new path>` fails outright,
refusing a mark against content nobody read, the alias tri-state, the `isPrimary` guard, and the
presence-versus-null merge that stops a queued edit overwriting a field it never read.

**Nine of the fourteen repository methods needed some of it.** A local repository written against
the registry alone would have reimplemented that half, and the two readers would have drifted —
invisibly, because nothing compares them, and the symptom would be one reader disagreeing with
another about the same worktree on the same Mac.

So `WorktreeReader` holds all fourteen operations in `ServerWorktreesDomain`, and the routes and the
window are both callers. `GranitaRouter` is now parse, call, encode.

**What each boundary keeps is the wording**, which is the whole reason the reader carries causes and
not sentences: a wire message and a screen's sentence are different jobs, and `WorktreeReadError` is
mapped once in each direction — to `ApiError` beside the routes, to `ApiFailure` beside the window.
**Both mappings are exhaustive `switch`es the compiler checks**, so a case added to the reader cannot
reach one reader and not the other.

**The wire is unchanged, and it was verified rather than asserted.** Every refusal message was moved
rather than retyped and the before-and-after literals diffed: four deltas, all explained — two
interpolation variables renamed with identical output, and two sentences that moved out of
`WorktreeRegistry` rather than out of the router. Worth writing down because **the acceptance suite
asserts the error *codes* and only one message verbatim**, so it would not have caught a reworded
refusal.

### A cancelled read was about to become a git failure

Found while wiring it, and it is the kind of defect the extraction exists to prevent rather than one
it introduced. The diff fan-out is a task group, and a cancelled group throws `CancellationError`
from inside it. Classified with the unknowns it would reach a screen as **git failed**, on a window
the reader had just closed — which is exactly the defect `ApiFailure.cancelled` was added to prevent
on the phone, recorded in this file under the `.task` teardown. `WorktreeReadError` gets its own
`cancelled` case, the local path maps it to `ApiFailure.cancelled`, and the HTTP path answers a typed
500 where it previously let the error escape the handler and become an **empty** one.

### One layer move made it possible

`WorktreeRegistry` was in `Server/Api/Presentation` and could not stay there: `Presentation` may not
be imported by a `Data` target, and the routes it serves carry Hummingbird. Its only filesystem
access was two `FileManager` calls — `fileExists` in `resolve(_:)` and `attributesOfItem` for a
worktree's modification date — so those went behind `WorktreeDirectoryReading` with a
`LocalWorktreeDirectory` conformer, and the type moved to `ServerWorktreesDomain` where both callers
can reach it. It stops throwing the Hummingbird-bound `ApiError`.

**`ApiError` itself cannot move down**, which is the fact that forced this shape: it conforms to
`HTTPResponseError`, because an error the framework does not recognise becomes an empty 500.
`ApiErrorCode` was already pure in `CoreApiDomain` and stayed there.

`WorktreeReadProfiler.read` became generic over its thrown type in the same pass, rather than naming
one caller's error for a measurement that does not care.

### The new module, and why a `Server` target implements a `Client` protocol

`LocalGranitaRepository` is at `Server/Reader/Data`. It implements `ClientConnectionDomain`'s
`GranitaRepository` from a `Server` module, which is the one place the two units meet — and **they
meet over `Domain` on both sides**, so no `Data` target is in the path and the phone's shell still
links none of it. The alternative placements both failed the layer rules rather than taste: in
`Presentation` it would have put Hummingbird in the reader's path, and in `Main` it would have been
logic in a composition root, which is exempt from both coverage rows and therefore untested code that
no longer looks untested.

