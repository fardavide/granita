import Foundation
import Network
import Testing

import ClientConnectionData
import CorePairingDomain

@Suite(.serialized)
struct PinnedConnectionTests {

    @Test func `given a wrong pinned key when requesting a tailnet IP then HTTPS is refused`() async throws {
        // given
        let scenario = try await Scenario(
            host: "100.81.42.98",
            fingerprint: SpkiFingerprint(rawValue: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        )
        defer {
            scenario.session.invalidateAndCancel()
            scenario.server.stop()
        }

        // when
        await #expect(throws: URLError.self) {
            try await scenario.session.data(for: URLRequest(url: scenario.url))
        }
        let report = await scenario.logs.report()

        // then
        try #require(scenario.server.acceptedTunnel, "The request must reach the fixture proxy")
        #expect(report.contains("refused — pinned key mismatch"))
        #expect(report.contains("accepted — pinned key matched") == false)
    }

    @Test func `given a pinned ten year certificate when requesting a non tailnet IP then HTTPS remains refused`() async throws {
        // given
        let scenario = try await Scenario(
            host: "192.0.2.1",
            fingerprint: SpkiFingerprint(rawValue: "9NqNI4rb1u4rHqUsuHyPnGUNhs0ANF7uXShoHgv9nbI=")
        )
        defer {
            scenario.session.invalidateAndCancel()
            scenario.server.stop()
        }

        // when
        let failure = await #expect(throws: URLError.self) {
            try await scenario.session.data(for: URLRequest(url: scenario.url))
        }
        let report = await scenario.logs.report()

        // then
        try #require(scenario.server.acceptedTunnel, "The request must reach the fixture proxy")
        let error = try #require(failure)
        #expect(error.code == .secureConnectionFailed)
        #expect(report.contains("accepted — pinned key matched"))
        #expect(report.contains("refused — pinned key mismatch") == false)
    }

    @Test func `given a pinned ten year certificate when requesting a tailnet IP then HTTPS completes`() async throws {
        // given
        let scenario = try await Scenario(
            host: "100.81.42.98",
            fingerprint: SpkiFingerprint(rawValue: "9NqNI4rb1u4rHqUsuHyPnGUNhs0ANF7uXShoHgv9nbI=")
        )
        defer {
            scenario.session.invalidateAndCancel()
            scenario.server.stop()
        }

        // when
        do {
            let (body, response) = try await scenario.session.data(for: URLRequest(url: scenario.url))

            // then
            try #require(scenario.server.acceptedTunnel, "The request must reach the fixture proxy")
            let http = try #require(response as? HTTPURLResponse)
            #expect(http.statusCode == 200)
            #expect(body == Data("pinned fixture response".utf8))
        } catch {
            Issue.record("Real HTTPS failed: \(ConnectionLogError.chain(for: error)); \(await scenario.logs.report())")
        }
    }

    private struct Scenario {

        let logs: ConnectionLogs
        let server: LoopbackTlsServer
        let session: URLSession
        let url: URL

        init(host: String, fingerprint: SpkiFingerprint) async throws {
            logs = ConnectionLogs(
                context: ConnectionLogContext(
                    appVersion: "acceptance", build: "fixture", systemVersion: "simulator", deviceModel: "iPhone"
                ),
                capacity: 20,
                now: { Date() }
            )
            server = try await LoopbackTlsServer(host: host)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 10
            configuration.proxyConfigurations = [server.proxy]
            session = URLSession(
                configuration: configuration,
                delegate: PinnedServerTrust(
                    pinnedTo: fingerprint,
                    logs: logs
                ),
                delegateQueue: nil
            )
            url = try #require(URL(string: "https://\(host):8737/acceptance"))
        }
    }
}
