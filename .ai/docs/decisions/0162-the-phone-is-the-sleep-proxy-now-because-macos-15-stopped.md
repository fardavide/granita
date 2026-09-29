# The phone is the sleep proxy now, because macOS 15 stopped being one

**SPEC §9 says a laptop that slept is the single most likely reason the phone cannot reach the Mac,
and it is right — but the remedy it names has stopped working.** The specification asks for
`NSWorkspace.didWakeNotification` and a re-bind, which repairs the Mac's side once it is already
awake. What it assumes, and never states, is that something wakes it. Until macOS 14 something did:
the Bonjour Sleep Proxy held a sleeping Mac's advertisements and sent it a magic packet when anyone
connected, which is exactly the mechanism Screens has always relied on and told its users to switch
on.

**In Sequoia that client is gone.** At `mDNSResponder-2881.120.11` — the build on Davide's Mac —
`MDNSRESPONDER_SUPPORTS_COMMON_SPS_CLIENT` is `0` for macOS, so `BeginSleepProcessing` takes the
`SendSleepGoodbyes` branch: the Mac *withdraws* its advertisements on the way down rather than
handing them to a proxy. The flag is present at 2559.1.1 (macOS 15.0) and absent from 2200.140.11
(macOS 14), so the change landed in Sequoia. There is an Apple TV on Davide's network advertising
`_sleep-proxy._udp` and it is now irrelevant — nothing registers with it.

The consequence is worse than a slow reconnect: a sleeping Mac is not in the browse at all, so the
discovery screen reports nothing found. There is no row, so there is nothing for any amount of
client patience to be patient about.

**So the phone sends the packet the proxy would have sent.** `/v1/health` reports the Mac's hardware
addresses, the pairing stores them beside the token, and two decorators — `WakingServerDiscovery`
over the browse and `WakingServerAddresses` over the resolve — broadcast a magic packet before
waiting to hear from a Mac that may be asleep.

### Why it is a decorator at the browse and not a screen

**Because a screen would need frames and this needs none.** The honest alternative is a row for a
Mac that is asleep with something to press, and design §1 has no such state; adding one is a design
round trip before any of this could ship. Waking at the browse means a sleeping Mac simply appears
in the list a few seconds later, through `searching` and `found` — states the screen already draws —
and the reader is told nothing they would have to act on. The wake runs *beside* the stream rather
than in front of it, so a refusing Keychain or a network that drops the datagram cannot cost the
reader the Macs that were awake all along.

### What is served unauthenticated, and why that is not a leak

A hardware address goes out on `/v1/health`, which answers before pairing. It is already broadcast
in the clear by ARP and mDNS to everyone on the same LAN, so this publishes nothing that was not
there for the asking — and the alternative, serving it only after pairing, would be a Mac that
cannot be woken until it has been reached, which is the case that never needs waking.

### Three departures from what was written down

**`RememberedMac` now stores something about where the Mac is**, which its own doc comment rules
out. The exception is deliberate and narrow: a hardware address is a property of the machine rather
than of this boot, so it does not go stale the way the port does — and it is the only thing usable
while the Mac is asleep, which is precisely when Bonjour has nothing to say.

**`RememberedMacRecord` gains an optional fifth field.** Optional so that every pairing already in a
reader's Keychain still decodes; a required one would read on the phone as a Mac that must be paired
with again, for no reason anybody could see.

**The just-paired destination now goes through `RememberedMacRepository`.** It used to build an
`HttpGranitaRepository` straight over the address pairing returned, and the comment above it argued
that was the point — a Mac just paired with "brings its address in hand". It also meant `lostContact`
never ran there, so once that Mac slept, *Try Again* re-dialled a dead port until the reader left the
screen. That was a defect before this work and it is the thing that makes waking from that screen
possible at all.

### The entitlement, which is the difference between this working and doing nothing

**iOS has not let an app broadcast without permission since iOS 14, and that includes this.**
`com.apple.developer.networking.multicast` is named for multicast and gates broadcast too; the check
is in the network stack, so a raw BSD socket is not a way around it — which matters here because the
socket was chosen for reliability and would otherwise have looked like one. Apple's own
documentation is explicit that the simulator does not enforce it, so **neither the snapshot suite nor
the loopback test in `MagicPacketWakeTests` can catch its absence**: they aim at `127.0.0.1`, which is
neither broadcast nor multicast.

The failure mode is the one this repository cares most about. `sendto` returns `-1`, the result is
discarded because nothing acknowledges a magic packet anyway, and the reader sees precisely what they
saw before the feature existed — a sleeping Mac that never appears. Not a dead control, since nothing
is pressed, but the same class of defect: something that looks finished and does nothing.

The entitlement is **restricted** and Apple must approve a request before a profile can carry it.
`Apps/GranitaMobile/GranitaMobile.entitlements` and the `entitlements:` key in `project.yml` are in
place, and **Apple assigned the entitlement to the account on 3 September 2026**, so a signed build
can carry it.

What that grant does *not* settle is whether waking works. `make build` signs nothing
(`CODE_SIGNING_ALLOWED=NO`), the simulator does not enforce the entitlement at all, and the loopback
test aims at `127.0.0.1`, which is neither broadcast nor multicast. **The first real evidence is a
device build against a sleeping Mac**, and until that has been done this feature is believed to work
rather than known to.

### Learning to wake a Mac that was paired with first

**Only pairing ever wrote a hardware address, so the first release that can wake a Mac could not wake
the Mac its reader already had.** Every pairing in the Keychain on upgrade day decodes with none, and
the remedy would have been to walk to the Mac and pair again — for a feature whose entire purpose is
not having to walk to the Mac.

So `RememberedMacs` backfills: when a Mac is reached and its record has no address, it reads health
and rewrites the record. It happens at the one moment the phone is guaranteed to be talking to a Mac
that is awake — it has just reached it — and once per Mac per run, so a Mac that genuinely has none
is asked once rather than on every reconnection. Silent on every failure, because a Mac too old to
answer, a health read that fails and a Keychain that refuses all leave the same state: a Mac that is
simply not wakeable, which is the state it was already in.

The health read is **unpinned**, deliberately. Health carries no secret, it is the route that answers
before pairing, and what comes back only aims a broadcast anyone on the network could send anyway.
Pinning would mean a second session per Mac for a read whose worst outcome is a packet nothing
answers.

### What no code here can fix

**Wake for network access has to be `Always`.** `pmset` ships it as *Only on Power Adapter* — `womp
1` on AC, `womp 0` on battery — and a Mac on battery ignores a magic packet entirely. Screens' own
support page leads with the same instruction, which is the tell that this is a platform requirement
and not something an app talks its way around. Saying so *in the app* would be a new surface on the
Mac's General tab, so for now it is in the changelog and this file. **If a reader ever reports "it
still does not wake", that setting is the first thing to check and the app cannot check it for
them.**

### Rejected, so it is not re-proposed

**An `IOPMAssertion` keeping the Mac awake while it serves.** It works, needs no packet and no
setting — and Davide ruled it out directly: the goal is to reach a Mac that is asleep, not to stop it
sleeping. It also costs battery on a laptop forever, and would need a General-tab toggle to be
honest about that, which is the design round trip this approach avoids.

**Pinning the Bonjour port so it survives a rebind.** Worth reconsidering only if a wake is ever
observed to land on a stale port. `BindAddress` has no case that fixes a port *and* advertises, so it
would mean an off-label mutation of the live `NWListener`, a store schema bump, and rewriting the
General tab footnote that currently tells the reader in as many words that the port changes every
launch — which is a screen, and therefore design-blocked. The phone re-resolves after each wake, so
the port it ends up on is the one Bonjour publishes.

