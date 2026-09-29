# The wire contract has one definition, and `CoreApiDomain` is where the rest of it went

Writing the phone's half of the API forced the question the Mac's half had never had to answer: what
is a payload both ends name, and where does it live. The Mac had been the only reader of its own
contract, so `HealthResponse`, `PairRequest`, `PairResponse`, `ViewedRequest` and `ApiErrorCode` sat
in `ServerApiPresentation` beside the Hummingbird routes that produced them. The obvious way to give
the client the same shapes is to write them again on the client, and that is the one thing
`CoreDiffDomain`'s own header already forbids in as many words: *these types are the wire contract,
so a renamed property is a version skew rather than a refactor.*

So there is a fourth `Core` module, not in SPEC §3's tree for the same reason `CoreBrandingDomain`
and `CorePairingDomain` are not. What it holds is the contract that is neither a diff model nor a
pairing credential. `ApiErrorCode` is the load-bearing member: SPEC §8 says the codes are part of the
contract *because the client branches on them*, and a client branching on string literals copied out
of the server would make a rename a screen that silently stops appearing. The HTTP status each code
maps to stayed on the Mac, because a status is how a refusal travelled and never what it means.

Three payloads moved into `CoreDiffDomain` instead, where the models the API is expressed in already
live: `DiffSide`, and the two read bodies that were called `ChangesResponse` and `LinesResponse` and
are now `WorktreeChanges` and `FileLines`.

**`WorktreePatch` is the case that justifies the whole exercise.** SPEC §8 marks it TRAP: `Codable`
decodes an absent key and an explicit `null` identically, so a struct cannot tell "clear the alias"
from "leave it alone", and the API needs both. That was implemented once, correctly, on the reading
side. Written a second time on the writing side it would have been a coin flip whether the phone
omitted the key where the Mac expected a null — and the symptom is an alias the reader has just
deleted quietly coming back. One type now encodes and decodes it, and the round trip through both
halves is a test.

Rejected: a shared `ApiErrorEnvelope` alongside the code. The Mac wants to encode a typed code and
the phone must tolerate one it has never heard of, which are different types with the same field
names; the client's four-line private decoder is not the duplication worth removing, and the
enumeration is.

**And the claim is checked rather than asserted.** "Both halves name the same type" is exactly the
kind of statement a suite that only ever sees one half cannot prove, so the phone's real client now
runs against the Mac's real router in one process — nothing faked below the routes, nothing faked
above them, and the pinned `URLSession` as the single substitution, because it is the one thing on
the path that is not about the contract. It pairs with a code the Mac issued and with the six words
under it, reads a worktree's changes and one file's diff and its raw lines, and drives the partial
update through all three of its states. Removing the explicit null from the encoder turns it red with
the symptom this entry describes: an alias the reader has just deleted coming back.

