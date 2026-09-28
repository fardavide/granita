# `waiting` is terminal for a connection, which is the opposite of the recorded browser lesson

`BonjourBrowser.change(for:)` treats `.waiting` as **recoverable** and says so in as many words: a
waiting browser is alive and comes back on its own, so the stream stays open and the session does not
replace it. That lesson is recorded, it is right, and it is about a *browser*.

**An `NWConnection` is the other way round, and a later reader will "fix" this if nobody writes it
down.** A connection that reports `.waiting` has failed to establish and will not establish itself;
what recovers it is a new connection, not patience. So `BonjourServiceConnection` reports waiting as
terminal, ends the stream, and lets the resolver answer. Two types, two opposite readings of one
enumeration case name, and the only thing standing between them is this entry.

The failure enum has exactly **two** cases — unreachable, carrying the diagnostic, and
localNetworkDenied — because those are the two design §5's outcome screen can say something different
about. `localNetworkDenied` is kept out of `unreachable` rather than folded into it precisely because
folding it would offer *Try Again* against a permission that never grants itself, which is a control
that cannot work. Rejected: a case per `NWError` code, which is a vocabulary no screen branches on.

Recorded rather than left in a doc comment because the agent that wrote it judged this file too
contended to touch from a worktree, and was right to hand it back rather than risk a three-thousand
line collision.

