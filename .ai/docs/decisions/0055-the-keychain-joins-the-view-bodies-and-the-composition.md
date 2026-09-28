# The Keychain joins the view bodies and the composition roots as uncoverable

Adding the identity store dropped the Unit row 5.6 points and turned the coverage gate red. Nothing
got worse: the store is ~200 lines that a host test cannot execute at all, and linking it into a
test binary — which happened because the interface enumeration beside it *does* have tests — pulled
every one of those lines into the denominator. That is the same dilution that scoped the Snapshot
row to the view layers and the Unit row away from the composition roots, arriving a third time.

A SwiftPM test binary is unsigned and has no keychain of its own, so the only way to run that file
is to write into the developer's real login keychain. It is behind `ServerIdentityStore` for exactly
that reason, everything downstream is tested against a fake, and it was verified by running the
server and pairing against it. Uncoverable by construction, not uncovered by neglect.

So it is named in the scope, **per file rather than per directory**: `Server/Identity/Data` also
holds the interface enumeration, and exempting the directory would stop measuring code that host
tests do cover. The bar for a second entry is the bar this one met — unrunnable from `swift test` by
construction — and not "hard to test".

**The scope's name changed with it**, `reachable` to `host-reachable`, and that is the mechanism
rather than a tidy-up. The gate compares two numbers only when both were taken the same way, so
renaming is how a redefinition declares itself: the Unit and All rows go unjudged for one run and
rejoin the ratchet on the next `main` run. Redefining silently would have compared a number against
the answer to a different question — and would have failed this pull request for the redefinition
rather than for a regression.

Rejected: deleting the interface-enumeration tests so nothing links the module and it leaves the
denominator the way `granita-server` does. It would have passed the gate today by removing tests,
which is the failure signature the `swift-testing` skill warns about in as many words.

