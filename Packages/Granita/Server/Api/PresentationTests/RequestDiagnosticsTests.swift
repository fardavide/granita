import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import CoreDiagnosticsDomain
import CorePairingDomain
import ServerApiDomain
import ServerGitData
import ServerStoreDomain
import ServerWorktreesDomain

@testable import ServerApiPresentation

/// What a reader finds in the system log about the requests this Mac answered.
///
/// Design §7's footnote is the specification — *verbose logging records every request and every git
/// invocation* — and this is the request half. Driven through the real router rather than by calling
/// the middleware, because the thing worth asserting is that it is **on the router** and not on the
/// authenticated group: the requests most worth reading about are the ones that never got that far.
@Suite("Request diagnostics")
struct RequestDiagnosticsTests {

    @Test
    func `when a request is answered then what was asked is recorded`() async throws {
        // given
        let scenario = Scenario()

        // when
        try await scenario.sut.test(.router) { client in
            _ = try await client.execute(uri: "/v1/health", method: .get)
        }

        // then
        #expect(scenario.diagnostics.details.contains("GET /v1/health"))
    }

    @Test
    func `when a request is answered then the status it answered with is recorded`() async throws {
        // given
        let scenario = Scenario()

        // when
        try await scenario.sut.test(.router) { client in
            _ = try await client.execute(uri: "/v1/health", method: .get)
        }

        // then — the pair is what makes a run readable after the fact. An asked line with no
        // answered line beside it is how a reader sees a request that never came back.
        #expect(scenario.diagnostics.details.contains("GET /v1/health → 200"))
    }

    @Test
    func `given a request without a token when it is refused then the refusal is not behind the switch`() async throws {
        // given — two things at once, and both are why this middleware is on the router rather than
        // on the authenticated group: a phone that cannot get in is being turned away *before* that
        // group, and a group's middleware would be silent about exactly that.
        let scenario = Scenario()

        // when
        try await scenario.sut.test(.router) { client in
            _ = try await client.execute(uri: "/v1/projects", method: .get)
        }

        // then — the refusal arrives as a thrown error rather than as a returned 401, so it takes
        // the note path. That is the right half to land in: a request nobody could make is why
        // somebody is reading this, and a reader who had to turn verbose on first finds out after
        // it stopped mattering.
        #expect(scenario.diagnostics.details.contains("GET /v1/projects"))
        #expect(scenario.diagnostics.notes.contains { $0.hasPrefix("GET /v1/projects failed:") })
    }

    @Test
    func `when a request carries a query then the query is not recorded`() async throws {
        // given — `?projectID=` resolves to a folder on this Mac, and a log has a different
        // lifetime and different readers than the thing it was taken from.
        let scenario = Scenario()

        // when
        try await scenario.sut.test(.router) { client in
            _ = try await client.execute(uri: "/v1/worktrees?projectID=abc123", method: .get)
        }

        // then
        #expect(scenario.diagnostics.details.contains { $0.contains("abc123") } == false)
    }

    // MARK: -

    private struct Scenario {

        let sut: any ApplicationProtocol
        let diagnostics: FakeDiagnostics

        init() {
            let store = FakeStore()
            // Never invoked: every route these tests reach is refused or answered before anything
            // asks git. Present because the router is assembled once, for every route it serves.
            let service = WorktreeService(
                git: ProcessGitClient(
                    executablePath: "/usr/bin/git",
                    outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
                    timeout: ProcessGitClient.defaultTimeout
                ),
                limits: .standard
            )
            diagnostics = FakeDiagnostics()
            sut = Application(router: GranitaRouter.build(ApiDependencies(
                registry: WorktreeRegistry(store: store, service: service, suggestedAliases: { _ in [:] }),
                service: service,
                store: store,
                pairing: Pairing(store: store, now: { Date(timeIntervalSince1970: 0) }),
                failedAttempts: FailedAttempts(now: { Date(timeIntervalSince1970: 0) }),
                connectionLog: InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 0) }),
                diagnostics: diagnostics,
                serverVersion: "0.0.17",
                // On, because the point of the third test is a route that refuses before it
                // reaches anything.
                requiresAuthentication: true
            )))
        }
    }
}
