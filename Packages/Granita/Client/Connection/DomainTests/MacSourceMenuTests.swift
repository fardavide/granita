import Testing

import ClientConnectionDomain

@Suite("Mac source menu membership")
struct MacSourceMenuTests {

    @Test(arguments: StatusCase.allCases)
    func `given discovery and remembered sources when resolving menu status then only remote choices are reported`(
        _ statusCase: StatusCase
    ) {
        // given
        let local = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "excluded-local-status-instance"),
            name: "This Mac's advertisement"
        )
        let remote = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "remote-status-instance"),
            name: "Remote Studio"
        )
        let discovery: DiscoveryState
        let remembered: [DiscoveredServer]
        let expected: DiscoveryState
        switch statusCase {
        case .idle:
            discovery = .idle
            remembered = []
            expected = .searching
        case .searching:
            discovery = .searching
            remembered = []
            expected = .searching
        case .noRemoteFound:
            discovery = .found([local])
            remembered = []
            expected = .found([])
        case .remoteFound:
            discovery = .found([local, remote])
            remembered = []
            expected = .found([remote])
        case .denied:
            discovery = .localNetworkDenied
            remembered = []
            expected = .localNetworkDenied
        case .failed:
            discovery = .failed(diagnostic: "Bonjour browse could not restart")
            remembered = []
            expected = .failed(diagnostic: "Bonjour browse could not restart")
        case .rememberedNotDiscovered:
            discovery = .found([])
            remembered = [remote]
            expected = .found([remote])
        }

        // when
        let scenario = Scenario(discovery: discovery, remembered: remembered, excluding: local.id)

        // then
        #expect(scenario.sut.status == expected)
    }

    @Test(arguments: DiscoveryCase.allCases)
    func `given remembered and discovered Macs when building the source menu then remote identities remain available once`(
        discoveryCase: DiscoveryCase
    ) {
        // given
        let local = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "this-mac-instance"),
            name: "MacBook Pro"
        )
        let sameName = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "other-macbook-instance"),
            name: "MacBook Pro"
        )
        let saved = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "renamed-studio-instance"),
            name: "Zulu saved studio"
        )
        let current = DiscoveredServer(
            id: saved.id,
            name: "Alpha renamed studio"
        )
        let offline = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "offline-mini-instance"),
            name: "Beta off-network mini"
        )
        let discovered = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "new-studio-instance"),
            name: "Gamma discovered studio"
        )
        let discovery: DiscoveryState
        let expected: [DiscoveredServer]
        switch discoveryCase {
        case .idle:
            discovery = .idle
            expected = [offline, sameName, saved]
        case .searching:
            discovery = .searching
            expected = [offline, sameName, saved]
        case .failed:
            discovery = .failed(diagnostic: "Bonjour unavailable")
            expected = [offline, sameName, saved]
        case .denied:
            discovery = .localNetworkDenied
            expected = [offline, sameName, saved]
        case .found:
            discovery = .found([local, current, discovered, current, sameName])
            expected = [current, offline, discovered, sameName]
        case .foundEmpty:
            discovery = .found([])
            expected = [offline, sameName, saved]
        }

        // when
        let scenario = Scenario(
            discovery: discovery,
            remembered: [saved, local, offline, saved, sameName],
            excluding: local.id
        )

        // then
        #expect(scenario.sut.servers == expected)
    }

    private struct Scenario {

        let sut: MacSourceMenu

        init(
            discovery: DiscoveryState,
            remembered: [DiscoveredServer],
            excluding instance: BonjourInstanceName
        ) {
            sut = MacSourceMenu(discovery: discovery, remembered: remembered, excluding: instance)
        }
    }

    enum DiscoveryCase: CaseIterable {
        case idle
        case searching
        case failed
        case denied
        case found
        case foundEmpty
    }

    enum StatusCase: CaseIterable {
        case idle
        case searching
        case noRemoteFound
        case remoteFound
        case denied
        case failed
        case rememberedNotDiscovered
    }
}
