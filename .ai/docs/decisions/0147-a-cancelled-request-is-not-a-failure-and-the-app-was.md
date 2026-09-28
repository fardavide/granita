# A cancelled request is not a failure, and the app was blaming the Mac for it

`URLSession` reports a torn-down request as `NSURLErrorCancelled`, and the transport folded every
non-`ApiFailure` error into `unreachable`. A `.task` is cancelled the moment its view goes away —
which in a navigation stack is *every time the reader opens something* — so an in-flight read of the
worktree list was routinely cancelled by the app itself and then reported as **Could not read your
Mac**, with `Code=-999 "cancelled"` in the small print, on the screen the reader reached by pressing
Back.

`ApiFailure.cancelled` is a case of its own now. The transport maps `URLError.cancelled` and
`CancellationError` to it, and each model decides: the worktree list keeps the arrangement it had,
the viewer keeps the change set it had, and a cancelled *write* leaves the reader's mark standing
rather than taking it back with an alert nobody caused.

**It is a case rather than a silent `nil`** because the transport cannot know what to do about it and
the screen can. And it is not folded into `unreachable` because the two differ in the only way that
matters to a reader: one means the Mac is not there, and the other means nothing at all.

