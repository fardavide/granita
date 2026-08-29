import Testing

import ClientConnectionDomain

/// The address a magic packet is built from, and the four ways a string can fail to be one.
///
/// Every refusal here reaches the reader as a Mac that cannot be woken, which is a state the app
/// already handles. What none of them may become is a packet built from the wrong bytes, which
/// looks exactly like a packet that works.
@Suite("Hardware address")
struct HardwareAddressTests {

    // MARK: - Reading one

    @Test
    func `given six colon-separated bytes when they are read then they become an address`() {
        // given - when
        let address = HardwareAddress(text: "3e:2d:c6:c3:4b:fe")

        // then
        #expect(address?.bytes == [0x3e, 0x2d, 0xc6, 0xc3, 0x4b, 0xfe])
    }

    @Test
    func `given an address in capitals when it is read then it becomes the same address`() {
        // given - when — what some Macs and most routers print.
        let address = HardwareAddress(text: "3E:2D:C6:C3:4B:FE")

        // then
        #expect(address == HardwareAddress(text: "3e:2d:c6:c3:4b:fe"))
    }

    @Test
    func `given an address when it is written back then it is lowercase and colon separated`() {
        // given - when
        let address = HardwareAddress(text: "3E:2D:C6:C3:4B:FE")

        // then — canonical, so the same Mac read twice compares equal to itself in the Keychain.
        #expect(address?.text == "3e:2d:c6:c3:4b:fe")
    }

    @Test
    func `given a byte under sixteen when the address is written back then it keeps its leading zero`() {
        // given - when
        let address = HardwareAddress(text: "00:0a:0f:10:ff:01")

        // then
        #expect(address?.text == "00:0a:0f:10:ff:01")
    }

    // MARK: - Refusing one

    @Test
    func `given fewer than six groups when they are read then there is no address`() {
        // given - when
        let address = HardwareAddress(text: "3e:2d:c6:c3:4b")

        // then
        #expect(address == nil)
    }

    @Test
    func `given more than six groups when they are read then there is no address`() {
        // given - when
        let address = HardwareAddress(text: "3e:2d:c6:c3:4b:fe:00")

        // then
        #expect(address == nil)
    }

    @Test
    func `given a group of one digit when it is read then there is no address`() {
        // given — the failure that most looks like success: this parses byte by byte and shifts
        // everything after it, yielding an address that is wrong rather than refused.
        let address = HardwareAddress(text: "3e:2:c6:c3:4b:fe")

        // then
        #expect(address == nil)
    }

    @Test
    func `given a group that is not hexadecimal when it is read then there is no address`() {
        // given - when
        let address = HardwareAddress(text: "3e:2d:c6:zz:4b:fe")

        // then
        #expect(address == nil)
    }

    @Test
    func `given six zero bytes when they are read then there is no address`() {
        // given - when — what an interface with no hardware of its own reports. It parses, and it
        // is not somewhere a packet can go.
        let address = HardwareAddress(text: "00:00:00:00:00:00")

        // then
        #expect(address == nil)
    }

    @Test
    func `given an empty string when it is read then there is no address`() {
        // given - when
        let address = HardwareAddress(text: "")

        // then
        #expect(address == nil)
    }

    // MARK: - Reading several

    @Test
    func `given a list holding one that is not an address when they are read then only that one is dropped`() {
        // given - when — a Mac reporting three interfaces of which one is unusable must still be
        // wakeable through the other two, rather than costing the reader the whole pairing.
        let addresses = HardwareAddress.all(in: ["3e:2d:c6:c3:4b:fe", "nonsense", "a4:83:e7:11:22:33"])

        // then
        #expect(addresses.map(\.text) == ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"])
    }

    @Test
    func `given a list of none when they are read then there are no addresses`() {
        // given - when
        let addresses = HardwareAddress.all(in: [])

        // then
        #expect(addresses.isEmpty)
    }

    @Test
    func `given a Mac that claims more addresses than any Mac has when they are read then the list is capped`() {
        // given — health answers before pairing and the spoken path trusts whoever answers, so this
        // list is attacker-shaped. Unbounded, it becomes a broadcast flood every time the discovery
        // screen appears.
        let claimed = (0..<5_000).map { index in
            String(format: "02:00:00:%02x:%02x:%02x", (index >> 16) & 0xff, (index >> 8) & 0xff, index & 0xff)
        }

        // when
        let addresses = HardwareAddress.all(in: claimed)

        // then
        #expect(addresses.count == HardwareAddress.mostPerMac)
        #expect(HardwareAddress.mostPerMac == 8)
    }

    @Test
    func `given more claimed addresses than the cap when they are read then the ones kept are the first`() {
        // given — the cap keeps a prefix rather than an arbitrary subset, so which addresses a Mac
        // is woken through is the order it reported them in and not chance.
        let claimed = ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"] + (0..<20).map { _ in "aa:bb:cc:dd:ee:ff" }

        // when
        let addresses = HardwareAddress.all(in: claimed)

        // then
        #expect(addresses.prefix(2).map(\.text) == ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"])
        #expect(addresses.count == HardwareAddress.mostPerMac)
    }
}
