# The already-paired state is the one frame this slice did not build

Design §5 draws it, it draws fine, and it is unreachable: nothing joins a Bonjour instance to a stored
token. The phone keeps its tokens against `ServerInstanceId`, a discovered Mac is only a Bonjour
instance name, and the `serverInstanceID` that would join them is the TXT record entry SPEC §8 asks
for and the Mac does not publish — which is on `status.md`'s "Waiting on Davide" for design §1's
*Recent* and *Other Macs* sections already, and is now blocking a second thing.

So the frames for that state stay in `.ai/docs/design/`, alone, and the rest are deleted with the
sections that shipped. **A `pairedAt` date on the token store is not added either**, for the same
reason: it is one field and one better sentence on a screen no reader can currently reach, and adding
it now would be API a screen has not agreed to — which is the mistake `ClientConnectionModel` already
made once and had a whole entry written about.

The review's own reading of that state is worth keeping, because it changes what to build when the
record lands: **already-paired is a discovery problem wearing a pairing screen.** The right behaviour
is a paired Mac's *row* going straight to its worktrees, after which the only readers who ever see
this screen are the ones whose token the Mac revoked. Build the row; keep the screen for that one
case.

