# A picture is not a binary file, and the phone fetches its two sides itself

Until 0.14.0 a changed screenshot was a collapsed bar reading `binary · no diff to show` with no
chevron on it — which is the smallest possible lie about a file with two pictures behind it, and it
shipped that way for every release the diff screen has had. Davide asked for image diffs on
15 September 2026, naming the case they are for: reviewing what a screenshot test re-recorded, from
the phone.

**Whether a file is a picture is decided from its path, on both ends, and never from git's binary
flag.** Two reasons, and the second is the one that would have been found late. Git reports a PNG as
binary and reports an *untracked* PNG as nothing at all — the change set builds untracked entries
from `ls-files` and never diffs them — so a screenshot an agent has just written is precisely the
file a binary-flag rule would refuse to draw. And an extension is the only thing either half knows
before any bytes have been read, which is the decision being made. The rule is one function in
`Core`, so the phone knows which sides to ask for and the Mac knows which files it will serve.

**Nothing new goes on the wire.** A `FileChange` already carries the path, so a field saying
"this is a PNG" would be a second answer to a question the client can put to itself — and a wire
field is a version skew where a shared function is a compile error. The contract version is
unchanged; the route is additive.

### The working copy is the one thing git cannot answer for

Every other side of every comparison is in the object database and comes back from `show`. The
working copy is not, and there is no read-only spelling that puts it there: `show :path` reads the
*index*, which for an edited file is the old content, and `hash-object -w` would write to a
repository this product never writes to. A `GIT binary patch` would decode, through a deflate
stream — a codec's worth of code to avoid opening a file.

So the server opens it, behind a protocol its `Domain` owns, implemented in a new
`Server/Worktrees/Data`. The path is joined by hand there, which is the only place in this product
that happens, and what makes it safe is unchanged: the path came from git's own account of the
checkout, resolved against the registry, never from a request.

### Refusing rather than truncating, and a second ceiling to make that possible

`fileDiff` truncates and says so, because half a diff is still half a diff. **Half a PNG is a
decoder drawing nothing under a card claiming the picture arrived**, so both sides refuse at the
ceiling instead — and the committed side refuses on the transport's own cut-off too, because a blob
that came back trimmed is indistinguishable from a corrupt one.

That forced a number: the git client's output ceiling is 2 MB, chosen for diffs, and **Granita's own
iPad snapshot baselines are 6.4 MB apiece**. A picture budget at the diff ceiling would have refused
exactly the files the feature was asked for. `show` therefore gets its own transport ceiling of
16 MB — it is the one command that answers with a file rather than with a report — and the product
refuses at 12. The two must not cross: above the transport's number, a picture inside the budget
could still come back trimmed, and the Mac would be promising a picture it then will not serve.

A side effect worth naming: context expansion reads its committed side through the same command, so
a source file between 2 and 16 MB was being spliced from a truncated copy and is no longer.

### The route answers with bytes, which is the only one that does

Base64 inside a JSON document is a third more wire and a whole decode pass on the phone, for bytes
an image decoder takes as they are. Everything else about the call is identical — the contract
version header, the bearer, and the same refusal table — which is what keeps it from being a second
client. It refuses in the shape every other route refuses in, so the phone needs no second mapping.

### The pictures sit beside the diffs rather than inside them

A `FileDiff` is the Mac's answer about one file; bytes fetched by two further requests are not part
of it. They are a dictionary on the model keyed by file, exactly as the lexer's output is, and for
the same second reason: a side landing has to redraw one card without the entry it belongs to being
rebuilt. They are dropped whole when a change set lands, which matters more here than for anything
else the model holds — a megabyte apiece under an identifier the scroll no longer draws is memory
nothing can reach.

**Fetched one at a time where the diffs are batched.** A five-file window can hold ten pictures, and
ten six-megabyte transfers in flight is most of a change set held in memory to draw two cards. In
the reader's own scroll order, so the picture under their thumb arrives first.

The screen calls are in [design §4](../design.md), including the waiver that let them be made here.

