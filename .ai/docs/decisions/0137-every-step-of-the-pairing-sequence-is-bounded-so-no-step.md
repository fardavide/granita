# Every step of the pairing sequence is bounded, so no step can end in a spinner

Davide's call on the night the above was found, and it outranks the bug: *something stuck without an
outcome is unacceptable — if there is an error, we must show it.* Fixing the navigation removes
tonight's instance; a bound removes the shape.

`MacPairing` now gives every awaited step a patience and answers `neverAnswered` when one runs out,
so the sequence is incapable of not producing a `PairingOutcome`. **Seventy-five seconds, and the
number is a backstop rather than a policy.** Every network step already has the transport's own
sixty-second request timeout, and a shorter bound here would replace `URLSession`'s diagnostic with a
worse one on an ordinary bad network. What it is actually for is the step with no deadline at all:
the Keychain is a synchronous call into another process and nothing above it can call it off.

**Not a task group**, which is the one implementation detail worth recording. A group awaits every
child before it returns, so a step that ignores cancellation would hold the group open for exactly as
long as it would have held the caller — the bound would be decorative, and the step this exists for
is precisely the uncancellable kind. What races instead is a one-shot actor that takes the first of
two answers and lets the loser finish or not finish on its own.

`PairingStall` splits the ending three ways and the split is **whether the code left the phone**,
because that is the only fact the reader can act on. Before it goes, another tap costs nothing and
the screen says so in the sentence this app already uses twice. After it, the Mac may hold a device
record and the screen has to be as careful as the Keychain one is: it names the trip to Settings ▸
Devices and offers no retry, because a button that spends a credential that may already be gone is
worse than no button. A write that never answered keeps the retry, for the reason a refused write
does — the token survives in the outcome, and the code that bought it is spent either way.

**The Keychain was the prime suspect and it is not the cause.** Run inside the simulator against the
real `KeychainPairingTokenStore` — never executed anywhere before, since a SwiftPM test binary is
unsigned and has no keychain — every call returned in about five milliseconds with
`errSecMissingEntitlement`, which is a `tokenNotStored` and therefore a screen. Recorded because the
next person to read that type's doc comment will suspect it too.

