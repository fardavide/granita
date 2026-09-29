# The 128 words are contract, so they live in `Core` rather than on the Mac

`SpokenWords` was `internal` to `ServerApiPresentation`, which was right while the Mac was the only
reader of its own codes. Design §5 asks the phone to say *"branch" is not one of the words* before a
round trip is spent, and that needs the list on this side.

The move is the same argument `CoreApiDomain` already won and is recorded above: **a word list both
ends spend a credential against is the wire contract**, and a second copy on the client would make a
list edit a version skew that nothing catches until somebody across a room reads six words aloud and
is refused. So it goes to `CorePairingDomain`, beside the link that carries the code, and the five
tests asserting the list's four promises go with it.

What that buys beyond one sentence on a screen is worth stating, because it is the reason it is worth
the move rather than deleting the line: five failures a minute lock the source address out, so a
wasted round trip on a mistyped word costs more than it looks.

Rejected: copying the list into the client. Same failure as copying `ApiErrorCode` would have been.
Rejected: dropping the unknown-word line and keeping only the count, which the review offered as the
cheap way out — it is cheaper than the move by about twenty lines and it spends a fifth of the rate
limit to learn what the phone already knew.

