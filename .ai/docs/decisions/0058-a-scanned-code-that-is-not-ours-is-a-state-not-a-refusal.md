# A scanned code that is not ours is a state, not a refusal

`PairingLink` already refused a non-Granita URL with `notAPairingLink`. What was missing is that a
viewfinder is not a form: it reads several times a second and most of what it finds belongs to
somebody else — a Wi-Fi code on a poster, a URL on the back of a bus. Surfacing those as errors would
put a stream of refusals in front of somebody who is simply holding a phone up at a screen.

So `PairingLink.scanned` returns one of three things, and the distinction it draws is **ours / not
ours** rather than valid / invalid. A `granita://` link that is damaged is worth a sentence, because
the reader is pointing at the right thing and it is not working. Anything else — another scheme,
another action under our own scheme, or text that is not a URL at all — is not an event.

Rejected: a `Result`, which forces the common case to be a failure and would make silence the
caller's job to remember. Rejected: treating a `granita://` link with an unknown action as damage,
which would make any future URL this app learns to open surface as a broken pairing code today.

