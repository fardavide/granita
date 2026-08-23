import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing

import ServerApiDomain
import ServerApiPresentation
import ServerGitData
import ServerStoreDomain
import ServerWorktreesDomain

/// `/v1/pair` from the outside: the one route an unpaired phone may reach, and therefore the one
/// route an attacker may reach too.
///
/// Every case here ends in the connection log as well as in a status code, because a phone that
/// will not pair is the thing the Advanced panel exists for — "it did not work" is not actionable
/// and "the code it sent had already been spent" is.
struct PairingRouteTests {

    // MARK: - Pairing

    @Test func `given an offered pairing when a phone redeems it then it is given a token`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: offered.code)) { response in
                // then
                #expect(response.status == .ok)
                #expect(token(in: response)?.isEmpty == false)
            }
        }
    }

    @Test func `given an offered pairing when a phone redeems it then the log says which device got in`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        try await scenario.application.test(.router) { client in
            _ = try await client.execute(uri: "/v1/pair", method: .post, body: body(code: offered.code)) { $0 }
        }

        // then
        // Against the device the store actually recorded, rather than against a name: the Devices
        // tab joins a sighting to a row on this identifier, so the row a `paired` line refers to has
        // to be the one that exists.
        let recorded = try #require(await scenario.store.state().devices.first)
        #expect(await scenario.attempts().map(\.outcome) == [
            .paired(device: "Davide's iPhone", id: recorded.id)
        ])
    }

    // MARK: - Refusals, told apart

    @Test func `given a code nobody issued when a phone offers it then the log calls it unknown`() async throws {
        // given
        let scenario = Scenario()

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: "invented")) { response in
                #expect(response.status == .unauthorized)
                #expect(errorCode(in: response) == "pairingExpired")
            }
        }

        // then
        #expect(await scenario.attempts().map(\.outcome) == [.refused(.pairingCodeUnknown)])
    }

    @Test func `given a pairing left too long when a phone offers it then the log calls it expired`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()
        scenario.clock.advance(by: 121)

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: offered.code)) { response in
                // then
                // The same code on the wire as an unknown one, deliberately: telling an
                // unauthenticated caller which of the two it was turns the route into an oracle
                // for "was this ever a real code". The log is where the difference is spent,
                // because the log is read by the one person who is entitled to it.
                #expect(response.status == .unauthorized)
                #expect(errorCode(in: response) == "pairingExpired")
            }
        }

        #expect(await scenario.attempts().map(\.outcome) == [.refused(.pairingCodeExpired)])
    }

    // MARK: - Guessing

    @Test func `given five refused pairings when a sixth is offered then it is rate limited`() async throws {
        // given
        let scenario = Scenario()

        // when
        try await scenario.application.test(.router) { client in
            for attempt in 0..<5 {
                _ = try await client.execute(uri: "/v1/pair", method: .post, body: body(code: "guess-\(attempt)")) { $0 }
            }

            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: "guess-5")) { response in
                // then
                // Without this the route is a free oracle: a code is short enough to be worth
                // guessing at network speed and lives for two minutes.
                #expect(response.status == .tooManyRequests)
                #expect(errorCode(in: response) == "rateLimited")
            }
        }

        #expect(await scenario.attempts().first?.outcome == .refused(.rateLimited))
    }

    @Test func `given a rate limited source when the real code is offered then it is still refused`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        try await scenario.application.test(.router) { client in
            for attempt in 0..<5 {
                _ = try await client.execute(uri: "/v1/pair", method: .post, body: body(code: "guess-\(attempt)")) { $0 }
            }

            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: offered.code)) { response in
                // then
                // The limit is on the source, not on the code. Anything else lets a guesser keep
                // going by interleaving a plausible attempt.
                #expect(response.status == .tooManyRequests)
            }
        }

        #expect(await scenario.store.state().devices.isEmpty)
    }

    @Test func `given four refused pairings when the real code is offered then the count is forgiven`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        try await scenario.application.test(.router) { client in
            for attempt in 0..<4 {
                _ = try await client.execute(uri: "/v1/pair", method: .post, body: body(code: "guess-\(attempt)")) { $0 }
            }
            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: offered.code)) { response in
                #expect(response.status == .ok)
            }

            // then
            // Someone who mistypes the words four times and then gets them right must not be
            // locked out of the Mac they are standing next to.
            let second = await scenario.pairing.invite()
            try await client.execute(uri: "/v1/pair", method: .post, body: body(code: second.code)) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: - Where a request came from

    @Test func `given a served request when it is logged then the source is the address it came from`() async throws {
        // given
        let scenario = Scenario()

        // when
        try await scenario.application.test(.live) { client in
            _ = try await client.execute(uri: "/v1/pair", method: .post, body: body(code: "invented")) { $0 }
        }

        // then
        // **The Host header is not a source address.** Every client sends the same one — it names
        // this Mac — so a limit counted against it is a global limit, and a log built from it says
        // where the request went rather than where it came from.
        let source = await scenario.attempts().first?.source
        #expect(source == "127.0.0.1" || source == "::1")
    }

    // MARK: -

    private struct Scenario {

        let clock = Clock()
        let store = FakeStore()
        let pairing: Pairing
        let application: any ApplicationProtocol

        private let connectionLog: InMemoryConnectionLog

        init() {
            let clock = clock
            let store = store
            pairing = Pairing(store: store, now: { clock.reading })
            connectionLog = InMemoryConnectionLog(now: { clock.reading })

            // Never invoked: none of these routes reaches git or a worktree. Present because the
            // router is assembled once, for every route it serves.
            let service = WorktreeService(
                git: ProcessGitClient(
                    executablePath: "/usr/bin/git",
                    outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
                    timeout: ProcessGitClient.defaultTimeout
                ),
                limits: .standard
            )
            application = Application(
                router: GranitaRouter.build(
                    ApiDependencies(
                        registry: WorktreeRegistry(store: store, service: service, suggestedAliases: { _ in [:] }),
                        service: service,
                        store: store,
                        pairing: pairing,
                        failedAttempts: FailedAttempts(now: { clock.reading }),
                        connectionLog: connectionLog,
                        serverVersion: "0.0.6",
                        requiresAuthentication: true
                    )
                )
            )
        }

        func attempts() async -> [ConnectionAttempt] {
            var readings = await connectionLog.attempts().makeAsyncIterator()
            return await readings.next() ?? []
        }
    }
}

// MARK: -

private func body(code: String) -> ByteBuffer {
    ByteBuffer(
        string: """
            { "code": "\(code)", "deviceName": "Davide's iPhone", "platform": "iOS" }
            """
    )
}

private func token(in response: TestResponse) -> String? {
    guard let body = try? JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any] else {
        return nil
    }
    return body["token"] as? String
}

private func errorCode(in response: TestResponse) -> String? {
    guard let body = try? JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any],
          let error = body["error"] as? [String: Any]
    else {
        return nil
    }
    return error["code"] as? String
}
