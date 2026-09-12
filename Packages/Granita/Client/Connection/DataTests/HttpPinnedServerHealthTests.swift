import Foundation
import Testing

import ClientConnectionDomain
import CoreApiDomain
import CorePairingDomain

@testable import ClientConnectionData

struct HttpPinnedServerHealthTests {
    @Test
    func `given an unusable endpoint when probing with the native factory then it is refused without insecure dispatch`() async {
        // given
        let scenario = Scenario(usingNativeSession: true)

        // when - then
        await #expect(throws: ApiFailure.requestNotBuildable(diagnostic: "Granita connections require HTTPS")) {
            try await scenario.sut.health(at: ServerAddress(host: "not a host", port: 8737), pinnedTo: SpkiFingerprint(rawValue: "saved-native-probe-key"))
        }
    }

    @Test
    func `given concurrent route probes with the same saved pin when verifying then they share one bounded session`() async throws {
        // given
        let scenario = Scenario()
        let fingerprint = SpkiFingerprint(rawValue: "shared-saved-mac-pin")

        // when
        async let local = scenario.sut.health(at: ServerAddress(host: "mac.local", port: 8737), pinnedTo: fingerprint)
        async let tailnet = scenario.sut.health(at: ServerAddress(host: "100.87.42.19", port: 8737), pinnedTo: fingerprint)
        _ = try await (local, tailnet)

        // then
        #expect(scenario.factory.createdPins == [fingerprint])
    }


    @Test
    func `given a remembered endpoint when verifying health then HTTPS reaches that endpoint without a bearer`() async throws {
        // given
        let scenario = Scenario()

        // when
        let health = try await scenario.sut.health(
            at: ServerAddress(host: "100.87.42.19", port: 8737),
            pinnedTo: SpkiFingerprint(rawValue: "saved-mac-pin")
        )

        // then
        #expect(health.serverVersion == "0.11.2")
        let request = try #require(await scenario.transport.sent.last)
        #expect(request.url.absoluteString == "https://100.87.42.19:8737/v1/health")
        #expect(request.headers["Authorization"] == nil)
    }

    @Test
    func `given different saved pins when probing then each Mac has its own pinned session`() async throws {
        // given
        let scenario = Scenario()
        let first = SpkiFingerprint(rawValue: "first-mac-key")
        let second = SpkiFingerprint(rawValue: "second-mac-key")

        // when
        _ = try await scenario.sut.health(at: ServerAddress(host: "first.local", port: 8737), pinnedTo: first)
        _ = try await scenario.sut.health(at: ServerAddress(host: "second.local", port: 8737), pinnedTo: second)

        // then
        #expect(scenario.factory.createdPins == [first, second])
    }

    private struct Scenario {
        let sut: HttpPinnedServerHealth
        let transport: FakeHttpTransport
        let factory: FakeHttpTransportFactory

        init(usingNativeSession: Bool = false) {
            transport = FakeHttpTransport(status: 200, json: #"{"name":"Granita","apiVersion":1,"serverVersion":"0.11.2"}"#)
            factory = FakeHttpTransportFactory(answer: transport)
            if usingNativeSession {
                sut = HttpPinnedServerHealth(logs: ConnectionLogs(
                    context: ConnectionLogContext(appVersion: "0.11.3", build: "test", systemVersion: "test", deviceModel: "test"),
                    capacity: 200, now: Date.init
                ))
            } else {
                sut = HttpPinnedServerHealth(transport: { [factory] in factory.transport(pinnedTo: $0) })
            }
        }
    }
}
