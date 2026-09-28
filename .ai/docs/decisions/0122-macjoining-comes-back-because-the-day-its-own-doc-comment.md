# `MacJoining` comes back, because the day its own doc comment named has arrived

`MacPairing` shipped 0.0.19 saying it would need a protocol "the day a screen drives it and wants a
double for the whole sequence", and that day is this one: the model behind design §5's four screens
drives all three of its members and is tested against them. So the protocol is back, with the two
members the outcome screen can act on separately — a code is spent once, and the Keychain write it
bought is retried on its own afterwards — plus the history the discovery list is ordered by.

**What it beat is the version that drives the two fakes already sitting under `MacPairing`.** That is
the option worth taking seriously, since `FakePairingTokenStore` and `FakeServerPairing` are written,
configurable and asserted against. It loses on two counts and the first is structural: they live in
`ClientConnectionDomainTests`, so a `Presentation` test reaching them means either a second copy of
both in a second bundle or a test target depending on a test target — one protocol and one fake is
less machinery than either. The second is the reason the entry above this one was written at all:
every model test would then re-run health, spend a code and write a token, which is a second copy of
`MacPairingTests` sitting one layer up and drifting from it the first time the sequence changes. The
model's tests should be able to say "the Mac refused" in one line and look at what the screen shows.

The cost is stated rather than waved through: it is one more name to learn, and for the moment it has
exactly one production implementation, which is the shape the `architecture` skill tells us to be
suspicious of. It clears that bar the ordinary way — there is a fake behind it today, in
`ClientConnectionPresentationTests`, and thirteen tests that could not be written without one.

### `PairingState` goes to `Domain`, which is not where it was removed from

It was nested in `ClientConnectionModel` when the pairing surface was taken out. It comes back as a
file beside `DiscoveryState` for the reason that one is there: the views that render it are in `Ui`,
which may see a `Domain` type and may not see a `Presentation` one. Nesting it would have forced the
screens to decompose it into primitives on the way down, which is the same enumeration written twice.

**Ten cases for design §5's twelve states, and the arithmetic is worth writing down** because two of
them are this repository's rather than the review's, and a later reader should not have to guess
which. The camera's *waiting*, *refused* and *restricted*; the viewfinder's *looking*, *not ours* and
*spending*; the entry screen; and the outcome. The two extra:

- **`savingToken`.** The outcome screen gained a button — recorded above, Davide's call — and with it
  the moment between the tap and the answer. The frame had no in-flight state because the frame had
  no button, and without one a write that fails a second time redraws the screen the reader was
  already looking at. That is a control that appears to do nothing, which is the defect this project
  is named for, arriving through the subtlest door it has.
- **`notReached`.** Six typed words with nowhere to send them. It carries
  `ServerAddressResolutionFailure` rather than a sentence because that enumeration's two cases do not
  share a remedy: *Try Again* is right for a Mac that slept, and it is a dead control in front of a
  local-network permission that will never grant itself. **§5 draws the first and not the second**,
  which is the one gap this slice found in that section — the refused-permission idiom §1 already
  owns is what the screen should reach for, and if that is wrong the answer belongs in `design.md`
  before it belongs in a screen.

`cameraRestricted` is not a third extra: §5 draws two permission states and `CameraAccess` has four
cases for the reason recorded with it, so folding a restriction into a refusal would ship *Turn the
Camera On in Settings* over a switch a policy is holding shut.

### The composition root is wired now, and that is not the mistake it looks like

The entry that removed this surface said do not ship a screen's API before the screen, and this
commit ships the model before the screens land. The difference is the ordering rather than the rule:
the screens are the next commit on this branch and no pull request opens between them, so nothing
reaches `main` with a property no view reads. What made the earlier case a defect was that the screens
had **no frames**, and the `design-handoff` rule forbade the pull request that would have drawn them;
§5 is drawn now.

Wiring the root is what gives `HttpServerPairing.init(mac:)` and
`UrlSessionHttpTransport.init(trustingFirstAnswer:)` their first production caller, which is what
those two were left uncalled and measured for. The root is also the only place allowed to see that
the two credentials build different sessions — pinned for a scanned link, trusting the first answer
for six words — and that is one closure rather than a branch anywhere above it.

