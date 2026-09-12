import Network
import Testing

import ClientConnectionDomain

@testable import ClientConnectionData

struct NetworkLocalNetworkAvailabilityTests {
    @Test(.timeLimit(.minutes(1)))
    func `given the native Wi-Fi monitor when checking then its first snapshot completes`() async {
        // given
        let sut = NetworkLocalNetworkAvailability()

        // when
        let availability = await sut.availability()

        // then
        #expect([LocalNetworkAvailability.available, .unavailable].contains(availability))
    }


    @Test(arguments: [NWPath.Status.satisfied, .unsatisfied, .requiresConnection])
    func `given a physical local path status when checking availability then only an active path enables discovery`(
        status: NWPath.Status
    ) async {
        // given
        let scenario = Scenario(status: status)

        // when
        let availability = await scenario.sut.availability()

        // then
        #expect(availability == (status == .satisfied ? .available : .unavailable))
    }

    private struct Scenario {
        let sut: NetworkLocalNetworkAvailability

        init(status: NWPath.Status) {
            sut = NetworkLocalNetworkAvailability(checking: { status })
        }
    }
}
