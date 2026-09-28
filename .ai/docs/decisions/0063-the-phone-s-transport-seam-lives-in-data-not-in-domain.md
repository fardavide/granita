# The phone's transport seam lives in `Data`, not in `Domain`

Every other I/O edge in this project sits behind a protocol its `Domain` owns. `HttpTransport` does
not, and the exception is the rule working rather than a hole in it: nothing above the `Data` layer
names HTTP at all, and moving a request-and-response vocabulary into `Domain` so that one type could
be faked would put the leak in the layer whose whole purpose is not having one. The protocol's
implementation and its only caller both live in `Client/Connection/Data`.

What it buys is that every rule the API client enforces is asserted on the host with no server and no
network: the bearer on the authenticated routes and its absence on the two that answer before
pairing, the contract version on every request, the comma-joined batch of file identifiers, and the
whole table from a refusal code to something the phone has a screen for.

**No HTTP status reaches anything above that client**, and it is not a style preference. SPEC §8
makes the *codes* the contract precisely because two refusals the Mac spells differently on purpose
can share a status — `unauthorized` and `pairingExpired` are both 401 — so a screen switching on the
number could not tell them apart. The status only ever reaches a diagnostic string.

`ApiFailure` carries two cases §8 does not, because §8 describes what a Mac says rather than what
happens when it says nothing: `unreachable`, whose payload is labelled a diagnostic for the same
reason `DiscoveryState.failed`'s is, and `notUnderstood`, which is what a body this version cannot
read and a refusal code a newer Mac invented both become. A third, `requestNotBuildable`, exists so
that no step of assembling a request has to be silenced with a `try?`.

