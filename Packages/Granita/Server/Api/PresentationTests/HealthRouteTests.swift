import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import CoreApiDomain
import CoreBrandingDomain

@testable import ServerApiPresentation

/// `/v1/health` is the one route that answers before a device is paired, so it is what the phone
/// uses to tell "wrong address" from "wrong version" from "not authorised".
@Suite("Health route")
struct HealthRouteTests {

    @Test
    func `when getting health then it answers without a token`() async throws {
        // given
        let scenario = Scenario(serverVersion: "0.0.1")

        // when - then
        try await scenario.sut.test(.router) { client in
            let response = try await client.execute(uri: "/v1/health", method: .get)
            #expect(response.status == .ok)
        }
    }

    @Test
    func `when getting health then it reports the product name and the api version`() async throws {
        // given
        let scenario = Scenario(serverVersion: "0.4.2")

        // when
        let health = try await scenario.health()

        // then
        #expect(health == HealthResponse(name: "Granita", apiVersion: 1, serverVersion: "0.4.2", wakeAddresses: []))
    }

    @Test
    func `given the branding changes when getting health then the payload follows it`() async throws {
        // given - when
        let health = try await Scenario(serverVersion: "0.0.1").health()

        // then — the wire contract is fed by Branding, not by a second copy of the same strings.
        #expect(health.name == Branding.productName)
        #expect(health.apiVersion == Branding.apiVersion)
    }

    // MARK: - Waking

    @Test
    func `given a Mac that knows its hardware addresses when getting health then the answer carries them`() async throws {
        // given — two, and deliberately unalike, so an implementation that reported only the first
        // or sorted them would fail here rather than pass by coincidence.
        let scenario = Scenario(serverVersion: "0.5.0", wakeAddresses: ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"])

        // when
        let health = try await scenario.health()

        // then
        #expect(health.wakeAddresses == ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"])
    }

    @Test
    func `given a Mac that knows no hardware address when getting health then the answer carries an empty list`() async throws {
        // given
        let scenario = Scenario(serverVersion: "0.5.0", wakeAddresses: [])

        // when
        let health = try await scenario.health()

        // then — empty rather than absent. A phone reads absent as "this Mac is too old to say" and
        // empty as "this Mac has nothing that can be woken", and it does different things about each.
        #expect(health.wakeAddresses == [])
    }
}

// MARK: -

private struct Scenario {

    let sut: any ApplicationProtocol

    init(serverVersion: String, wakeAddresses: [String] = []) {
        sut = Application(
            router: GranitaRouter.build(
                ApiScenario.healthOnlyDependencies(serverVersion: serverVersion, wakeAddresses: wakeAddresses)
            )
        )
    }

    /// Decodes the health payload, so a test asserts on the model rather than on a JSON string and
    /// therefore fails on a changed key as loudly as on a changed value.
    func health() async throws -> HealthResponse {
        try await sut.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                try JSONDecoder().decode(HealthResponse.self, from: Data(buffer: response.body))
            }
        }
    }
}

