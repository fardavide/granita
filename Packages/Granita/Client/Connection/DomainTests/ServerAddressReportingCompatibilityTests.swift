import Testing

import ClientConnectionDomain

@Suite("Server address reporting compatibility")
struct ServerAddressReportingCompatibilityTests {

    @Test
    func `given a legacy resolver when reporting its successful resolution then the address survives and only unknown route stages are reported`() async throws {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Legacy resolving Mac"), name: "Legacy resolving Mac")
        let address = ServerAddress(host: "100.123.87.96", port: 61_023)
        let scenario = Scenario(answering: .success(address))
        let resolver: any ServerAddressResolving = scenario.sut

        // when
        let result = try await resolver.address(of: server, reporting: { stage in
            await scenario.progress.record(stage)
        })

        // then
        #expect(result == address)
        #expect(await scenario.sut.received == [server])
        #expect(await scenario.progress.stages == [.finding(.unknown), .reading(.unknown)])
    }

    @Test(arguments: [ServerAddressResolutionFailure.localNetworkDenied, .unreachable(diagnostic: "The legacy lookup returned no route")])
    func `given a legacy resolver fails when reporting its resolution then the typed failure survives without claiming verification or reading`(failure: ServerAddressResolutionFailure) async {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Failed legacy resolving Mac"), name: "Failed legacy resolving Mac")
        let scenario = Scenario(answering: .failure(failure))
        let resolver: any ServerAddressResolving = scenario.sut

        // when
        await #expect(throws: failure) {
            try await resolver.address(of: server, reporting: { stage in
                await scenario.progress.record(stage)
            })
        }

        // then
        #expect(await scenario.sut.received == [server])
        #expect(await scenario.progress.stages == [.finding(.unknown)])
    }

    private struct Scenario {
        let sut: FakeLegacyServerAddressResolving
        let progress: FakeWorktreeReadProgressRecording

        init(answering: Result<ServerAddress, ServerAddressResolutionFailure>) {
            sut = FakeLegacyServerAddressResolving(answering: answering)
            progress = FakeWorktreeReadProgressRecording()
        }
    }
}
