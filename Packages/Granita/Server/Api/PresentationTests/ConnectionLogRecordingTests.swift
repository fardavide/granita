import Hummingbird
import HummingbirdTesting
import Testing

import ServerApiDomain

/// The Advanced panel is only worth as much as what reaches it, so what the server records is
/// asserted at the boundary that records it rather than at the panel that draws it.
@Suite("Connection log recording", .serialized)
struct ConnectionLogRecordingTests {

    @Test
    func `given a request carrying no token when it is refused then the log says none was offered`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/projects", method: .get) { response in
                #expect(response.status == .unauthorized)
            }
        }

        // then
        let attempts = await scenario.recordedAttempts()
        #expect(attempts.count == 1)
        #expect(attempts.first?.outcome == .refused(.noToken))
    }

    @Test
    func `given a paired phone when it is served then the log names the device rather than the address`() async throws {
        // given — "something at 192.168.1.24 got in" does not answer whether *this* phone did.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }
        let paired = try await scenario.pairing.redeem(
            code: await scenario.pairing.invite().code,
            deviceName: "Davide's iPhone",
            platform: "ios"
        )

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/projects",
                method: .get,
                headers: [.authorization: "Bearer \(paired.token)"]
            ) { response in
                #expect(response.status == .ok)
            }
        }

        // then
        let attempts = await scenario.recordedAttempts()
        #expect(attempts.first?.outcome == .accepted(device: "Davide's iPhone"))
    }

    @Test
    func `given a phone speaking a newer contract when it is refused then the log says which version it sent`() async throws {
        // given — the two apps ship independently, so this is the refusal Davide sees after a
        // TestFlight build lands before the Mac app has caught up. Nothing about it is the phone's
        // fault, and the panel is where the number that explains it appears.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/projects",
                method: .get,
                headers: [.init("X-Granita-Api-Version")!: "2"]
            ) { response in
                #expect(response.status == .upgradeRequired)
            }
        }

        // then
        let attempts = await scenario.recordedAttempts()
        #expect(attempts.first?.outcome == .refused(.unsupportedApiVersion(sent: 2)))
    }

    @Test
    func `given a phone offering a token this Mac never issued when it keeps trying then the panel says both things`() async throws {
        // given — the two refusals mean different things to whoever is reading: one says pair this
        // phone again, the other says wait a minute. Fifty rows of the first would say neither.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when — five wrong tokens are tolerated and the sixth is turned away for another reason.
        try await scenario.application.test(.router) { client in
            for _ in 1...6 {
                try await client.execute(
                    uri: "/v1/projects",
                    method: .get,
                    headers: [.authorization: "Bearer not-a-token-this-mac-issued"]
                ) { _ in }
            }
        }

        // then
        let attempts = await scenario.recordedAttempts()
        #expect(attempts.count == 2)
        #expect(attempts.first?.outcome == .refused(.rateLimited))
        #expect(attempts.last?.outcome == .refused(.unknownToken))
    }
}
