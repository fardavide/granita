# A remembered Mac is filed under its Bonjour name, and the row goes straight to its worktrees

Two entries above this one — *the already-paired state is the one frame this slice did not build* and
*`loadPairingHistory()` and `pairedServers` are removed for the second time* — both stop at the same
sentence: nothing joins a Bonjour instance to a stored token, and the `serverInstanceID` that would
join them is a TXT record entry SPEC §8 asks for and the Mac does not publish. That was read as a
blocker on the Mac. It was a blocker on the **key**, and the key was the wrong one.

`ServerInstanceId` arrives inside a `/v1/pair` response. A phone that has not paired cannot know it,
and a phone that has cannot match it against anything a browse returns — so filing a token under it
guaranteed that the token could never be found again. It was also never stable: `Pairing.instanceId`
is a `UUID()` evaluated once per process, which its own comment says out loud, so every restart of the
Mac orphaned every token any phone held. Two documents disagreed about this for four releases and the
code agreed with the wrong one.

**What a browse result carries is a Bonjour instance name, so that is the key.** It is in hand at the
one moment the question is asked — this row, does this phone already know it — and it is unique within
a local domain because the system appends "(2)" itself. A rename costs one more pairing, paid by the
person who renamed the machine rather than by everybody every time they open the app.

**The identity check is the pin, not the identifier**, which is what makes the weaker key safe. The
stored pairing carries the SPKI fingerprint beside the token, and the session built from it refuses
every other key in the handshake. A different Mac answering under a remembered name is a refused
connection, not a request sent to a stranger. That is a stronger guarantee than matching a UUID would
have been, since a UUID is only ever as good as the channel that carried it.

So no TXT record is added, and the not-recommended entry in design §5.6 stays not-recommended for the
reason it gives: a TXT record is in-band, and the one field that may not ride there is the key. The
instance identifier may — and now nothing needs it to.

**The row is the fix, and the screen is not.** The review's own reading, recorded in the first entry
above, was that *already-paired is a discovery problem wearing a pairing screen*, and that the right
behaviour is a paired Mac's row going straight to its worktrees. That is what ships. The drawn
already-paired frames stay in `.ai/docs/design/` for the one reader who ever reaches that
situation — the one whose token the Mac revoked — and that case is handled without a screen for now:
a refusal forgets the pairing, so Back and a second tap reach the two credentials again.

**No new screen and no new state, which is why this needed no design round trip.** Reaching a
remembered Mac is a Keychain read, a Bonjour lookup and a pinned session, and all three happen behind
the worktree list's own loading state because they happen inside its repository rather than in front
of it. `RememberedMacRepository` is the seam: every call opens the connection if there is not one,
and the failure of a call is what changes what the phone believes — a refusal forgets the pairing, an
unreachable read throws away the address, and the exhaustive switch is what stops a future refusal
joining those two by accident. Rejected: resolving the address in the row's tap handler, which is a
list that goes dead for the length of an mDNS lookup; rejected: a connecting screen, which is a frame
that does not exist and a fifth screen in a flow design §5 fixed at four.

**The address is not stored and the fingerprint is.** The port is the system's choice at bind time, so
a remembered `host:port` is wrong the first time the Mac restarts — a phone dialling it would report a
Mac two feet away as unreachable. The key is the opposite: it is in the login Keychain on that Mac and
outlives every restart, and without it a reconnection would have to trust whoever answered, giving
back the whole of what pairing bought. So one is looked up every time and the other is written down.

**0.4.0's items are deleted rather than left.** They are unreachable by construction and each one is a
live bearer token, since the Mac's device record outlives the launch that issued it. The sweep runs
after the first successful write in the new format, which is the moment the reader demonstrably has a
pairing this version can use — not at launch, where it would be a Keychain call on every scene
evaluation forever for a migration that happens once.

