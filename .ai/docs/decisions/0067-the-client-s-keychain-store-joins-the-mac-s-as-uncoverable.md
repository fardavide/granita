# The client's Keychain store joins the Mac's as uncoverable, and the scope is renamed again

Same reasoning, second instance, and the bar it met is the one the first one set: a SwiftPM test
binary is unsigned and has no keychain of its own, so the only way to execute
`KeychainPairingTokenStore` at all is to write into a real one. It is behind `PairingTokenStore` for
that reason and everything downstream is tested against a fake.

The scope string moves from `host-reachable` to `host-reachable-no-keychain`, which is the mechanism
declaring itself rather than a tidy-up — the gate compares two numbers only when both were taken the
same way, so the Unit and All rows go unjudged for one run and rejoin on the next `main` run. The
name now says what the exempt set actually is instead of leaving one of its two members unmentioned.

**Unlike the Mac's, this one has not been run.** The Mac's store was verified by running the server
and pairing against it; the phone's needs a device, and the screen that would reach it does not
exist. `status.md` carries that.

**The rename found a bug in the mechanism it was using.** The filter selected on the scope *string*
literal, so renaming the scope in the configuration and not in the filter stopped narrowing anything
at all — silently, and in the direction that looks like good news, since the rows go unjudged for
that same run. The script's own tests caught it on the first CI run. Both scope names are constants
now, so the two cannot come apart, and a test asserts that whatever is configured still removes
something rather than that the two constants equal each other, which would be a tautology.

