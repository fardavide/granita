# A refused lock is its own run state, because reusing `failed` points a button the wrong way

The cheap version was to put the refusal's sentence into `failed(reason:)`, which already carries a
string and already reaches every surface. It was rejected, and the reason is not tidiness: General's
`failed` branch **names Local Network access as the likely cause and offers a button straight to that
pane**. For a lock conflict that pane is already correct, so the advice is wrong and the button is a
control that does something actively unhelpful — a reader follows it, finds nothing to change, and
comes back knowing less than they started with. That is worse than a control that does nothing,
because it costs a trip.

So `blockedByAnotherProcess` is a case of its own. **The compiler found all six switches over the
enum**, which is what the no-`default:` rule buys: three of them fold the new case in with
`failed`/`stopped` because the answer really is the same — the menu bar's symbol, its accessibility
label, and whether pairing can be offered — and three needed a real answer.

**Three symbols in the menu bar rather than four.** The status item asks one question and a blocked
lock answers it the same way a failure does: not serving. Which of the three reasons it is belongs
one click below, and 0.0.16 already settled that shape.

**The menu names this reason, unlike `failed`, whose reason it deliberately withholds.** The
difference is that `failed` carries whatever went wrong — a locked keychain reaches it too — so a
menu with no room for small print would be asserting a cause it cannot know. A held lock is a fact
with one short noun in it and no hedge to leave out.

**`ServerApiDomain` gained a dependency on `ServerStoreDomain`** for the holder the state carries.
`Domain` may depend on `Domain`, and the alternative was flattening a two-field record into two
loose parameters — the same record spelled twice, in the enum that exists to keep it in one place.

