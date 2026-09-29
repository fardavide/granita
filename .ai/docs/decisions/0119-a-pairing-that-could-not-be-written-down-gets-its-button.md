# A pairing that could not be written down gets its button back

`MacPairing.pair` held the `PairedDevice` in hand when `tokens.save` threw and dropped it on the
floor, returning `.tokenNotStored(error)`. The design drew that screen without a primary action for a
stated reason — the reviewer could not tell whether the token survived that far, and **a button that
cannot work is the defect this project is named for**.

It survives. So the outcome carries it, *Try Again* on that screen retries the Keychain write **alone**
rather than re-running a handshake against a code that is now spent, and the walk to the Mac drops to
the second sentence. `errSecInteractionNotAllowed`, the common cause, is transient.

Davide's call on 25 August 2026, against the drawn version. The cost is stated rather than waved
through: a live bearer token now sits in memory for as long as that screen is on screen, where before
it was discarded immediately. It is not written anywhere, it dies with the screen, and the alternative
was sending the reader to another machine to fix something the phone could have fixed itself.

Still rejected, and the review is right about both: **no *Pair Again* on that screen**, which would
leave a second device record beside the orphan, and no dropping of the sentence that says the Mac now
believes this iPhone is paired — without it the advice to go and revoke it sounds like superstition.

