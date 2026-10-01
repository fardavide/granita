import Testing

import ClientConnectionDomain
import CorePairingDomain

@Suite("Excluding this Mac from discovery")
struct ExcludingServerDiscoveryTests {

    @Test
    func `given this Mac and remote Macs when discovery updates then only this Mac is excluded`() async {
        // given
        let local = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "local-instance"),
            name: "MacBook Pro"
        )
        let sameName = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "remote-instance"),
            name: "MacBook Pro"
        )
        let other = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "studio-instance"),
            name: "Mac Studio"
        )
        let scenario = Scenario(
            instance: local.id,
            reporting: [
                .idle,
                .searching,
                .found([local, sameName, other]),
                .failed(diagnostic: "Bonjour interrupted"),
                .found([local]),
                .localNetworkDenied,
                .found([other, local, sameName]),
                .found([])
            ]
        )

        // when
        var states: [DiscoveryState] = []
        for await state in scenario.sut.discover() {
            states.append(state)
        }

        // then
        #expect(states == [
            .idle,
            .searching,
            .found([sameName, other]),
            .failed(diagnostic: "Bonjour interrupted"),
            .searching,
            .localNetworkDenied,
            .found([other, sameName]),
            .searching
        ])
    }

    private struct Scenario {

        let sut: any ServerDiscovering

        init(instance: BonjourInstanceName, reporting states: [DiscoveryState]) {
            sut = ExcludingServerDiscovery(
                discovery: FakeServerDiscovery(states: states),
                instance: instance
            )
        }
    }
}
