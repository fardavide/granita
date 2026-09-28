# Tailscale is a stable fallback for remembered Macs, not a second discovery system

Davide chose support through the existing Tailscale apps rather than embedding a VPN or making
Granita configure a tailnet. Granita neither invokes the Tailscale CLI nor changes Serve, MagicDNS,
ACLs or routes. It observes the `100.64.0.0/10` IPv4 address already assigned to the Mac and does
nothing when that interface is absent.

**One fixed listener serves both paths.** The Mac app binds pinned TLS on `0.0.0.0:8737` and attaches
its Bonjour service to the underlying `NWListener` after readiness. Network supports that mutation;
it keeps the SPEC §8 rule intact because there is one listener and one socket, not a second advertiser
trying to claim the same port. A conflict on 8737 is visible as the server's existing failed state.

**Bonjour wins and Tailscale falls back.** Health optionally reports a typed tailnet endpoint. The
phone stores it beside the pairing but still resolves Bonjour first, so local moves and fresh network
state remain authoritative. An unreachable or locally denied resolve uses the stored endpoint with
the same SPKI pin and bearer token; remembered rows therefore remain tappable even when multicast
discovery has no answer.

**A searching browser is already an empty local answer for remote rows.** On cellular, `NWBrowser`
can become ready and remain searching without ever calling its results handler with an empty set.
Waiting for `.found([])` therefore leaves the screen searching forever even when a remembered Mac
has a stable fallback. The discovery decorator surfaces fallback-capable remembered Macs from
`.searching`, then lets any later Bonjour result supply the authoritative local name for matching
servers while unmatched remembered rows remain available remotely.

**Old pairings upgrade rather than expire.** Missing endpoint fields decode as local-only. On the
next successful local connection, the phone reads health through the already-stored pin and rewrites
the Keychain record with any tailnet endpoint and wake addresses it learned. An untrusted Bonjour
answer cannot redirect later authenticated traffic because the metadata read itself is pinned.

**First pairing remains Bonjour-local.** The current QR scanner and six-word entry live behind a Mac
row, so a never-paired Mac must first appear in discovery. Remote first contact would require a new
entry surface and design; it is outside this slice rather than a hidden no-op.

---

