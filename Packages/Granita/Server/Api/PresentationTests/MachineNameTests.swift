import Foundation
import Testing

import ServerApiPresentation

/// What this Mac is called, which is what the phone lists it under and what belongs beside a port.
///
/// **The trap this pins is that the obvious answer looks right.**
/// `ProcessInfo.processInfo.hostName` and `Host.current().localizedName` are reverse DNS lookups:
/// they ask the network what this address currently resolves to. On Davide's connection that
/// answers `customer.mlnnita1.isp.starlink.com`, so the Mac advertises under a name nobody
/// recognises — and the same call from a terminal a minute later answers `macbook-pro.local`, which
/// is what makes it look like it works.
///
/// So these assert the *shape* the System Configuration answers have and the reverse-DNS answer does
/// not, rather than a literal name — a runner and a laptop are called different things, and a test
/// that pinned one would only ever run on one machine.
@Suite("Machine name")
struct MachineNameTests {

    @Test
    func `given this Mac when it is asked what it is called then it answers something`() {
        // given - when
        let name = MachineName.computer

        // then — an empty name would advertise a Bonjour service with no label, which the phone
        // lists as a blank row rather than failing to list.
        #expect(name.isEmpty == false)
    }

    @Test
    func `given this Mac when its local network name is asked for then it is a mDNS name`() {
        // given - when
        let name = MachineName.localHost

        // then — the `.local` suffix is the whole point of this value: it is the name that resolves
        // over mDNS, and a reverse DNS answer is a routable name that does not end this way.
        #expect(name.hasSuffix(".local"))
    }

    @Test
    func `given this Mac when its two names are asked for then neither carries a port`() {
        // given - when - then — both are pasted beside a port by the caller, so either one arriving
        // with a port already on it produces an address with two.
        #expect(MachineName.computer.contains(":") == false)
        #expect(MachineName.localHost.contains(":") == false)
    }
}
