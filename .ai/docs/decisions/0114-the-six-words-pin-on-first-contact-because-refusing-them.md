# The six words pin on first contact, because refusing them leaves a state with no way out

The pairing design review's finding, and the one thing in it no frame could carry: **the two
credentials are not peers.** The QR carries the SPKI fingerprint over a channel nobody on the network
can write to — the Mac's own screen. The six words carry a code and nothing else, and the host and
port they borrow come from a Bonjour record any device on the LAN can publish. They redeem the same
pairing and they do not buy the same guarantee.

The client had already decided this by accident and in the strictest direction: `PairingLink(url:)`
throws `missingField(named: "spki")`, and `UrlSessionHttpTransport(pinnedTo:)` cannot build a session
without a fingerprint at all. So on 0.0.19 the six-word path could not be built, whatever a screen
looked like.

**`SPEC.md` contains the tension rather than settling it.** §8 requires the SPKI pin *and* requires a
six-word fallback "for when the camera is unavailable", and the second cannot satisfy the first. That
is why it went to Davide rather than being resolved here; he delegated it back on 25 August 2026.

**The words path pins the certificate it is handed on first contact**, and everything downstream
follows from that being said out loud rather than hidden. What decided it was the alternative's cost
rather than this one's comfort: refusing without an `spki` deletes SPEC §8's fallback outright, and it
leaves design §5's refused-camera state with **no in-app remedy at all** — an unavailable-content view
whose only action leaves the app, which is the shape this project spent eight releases learning not to
ship. It also makes the same-device case unreachable, which is the case Davide actually hits.

The asymmetry is carried in two cheap places instead of one expensive one: the camera is **ordered
first** on the entry screen, and one caption2 line on the six-word screen says what the difference is
— *"The QR code also carries your Mac's key. Typed words trust the Mac that answers, so use them on a
network you trust."* That is a true sentence about a pin, and it is not the plaintext warning 0.0.7
retired: the connection is TLS on both paths.

Rejected: **putting the fingerprint in the Bonjour TXT record.** It repairs the already-paired state
and it looks like it repairs this, and it does not — a TXT record is in-band, so an impostor
advertises its own key beside its own host and the phone pins precisely what the attacker chose. One
field, two features, one of them imaginary. The instance identifier the discovery list is waiting for
may still ride there; the key may not, and this entry exists partly so that nobody adds it later
believing it helps.

Rejected: **a fingerprint the reader compares.** Four characters beside the words on the Mac, four on
the phone, and a confirmation. It is the SSH ceremony and it is entirely buildable. It does not ship
because a check nobody performs is worse than an honest sentence — it launders the risk — and this one
would be performed by the reader who has already been pushed onto the harder path, squinting across a
room.

Rejected: **refusing to pair over words unless the network is trusted**, in any automated form. There
is no signal on iOS that answers that question, and a screen that claims to know is a worse lie than
the one it replaces.

The scope that makes this affordable is `SPEC.md` §0's, and it is LOCKED: **the network is LAN only in
v1.** The day v2 adds remote access this entry is the first thing to re-read, because trust on first
use across the internet is a different proposition from trust on first use across a flat.

