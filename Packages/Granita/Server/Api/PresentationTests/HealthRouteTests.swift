import CoreBrandingDomain
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

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
        #expect(health == HealthResponse(name: "Granita", apiVersion: 1, serverVersion: "0.4.2"))
    }

    @Test
    func `given the branding changes when getting health then the payload follows it`() async throws {
        // given - when
        let health = try await Scenario(serverVersion: "0.0.1").health()

        // then — the wire contract is fed by Branding, not by a second copy of the same strings.
        #expect(health.name == Branding.productName)
        #expect(health.apiVersion == Branding.apiVersion)
    }
}

// MARK: -

private struct Scenario {

    let sut: any ApplicationProtocol

    init(serverVersion: String) {
        sut = Application(router: GranitaRouter.build(ApiScenario.healthOnlyDependencies(serverVersion: serverVersion)))
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

