import Foundation
import Testing

import ClientConnectionDomain
import CoreApiDomain

@testable import ClientConnectionData

/// The two refusals a request produces before it has left the phone.
///
/// What this client does with an *answer* is asserted through the two route types that use it, which
/// is where the routes are. Only the pair of guards on the way out reaches from here: neither can be
/// provoked through a route, because every route is a literal path and every body is a type this app
/// wrote — and a guard that cannot be provoked is one nothing holds to its sentence.
@Suite("Granita http client")
struct GranitaHttpClientTests {

    @Test
    func `given a path that is not a route when a request is made then it names what it could not address`() async {
        // given — a route reads as the route SPEC §8 names, which is why the path replaces the base's
        // rather than being appended to it, and why the base carries no path of its own. A path with
        // no leading slash is not a route, and there is no URL at the end of one.
        let sut = GranitaHttpClient(
            baseUrl: macAddress,
            transport: FakeHttpTransport(status: 200, json: healthJson),
            authorization: .unauthenticated
        )

        // when - then — a sentence rather than a force-unwrap on the one value every request needs.
        await #expect(
            throws: ApiFailure.requestNotBuildable(
                diagnostic: "could not address v1/health on https://davides-macbook-pro.local:59144"
            )
        ) {
            try await sut.get("v1/health", returning: HealthResponse.self)
        }
    }

    @Test
    func `given a body that cannot be written when a request is made then the Mac is never asked`() async {
        // given
        let transport = FakeHttpTransport(status: 200, json: healthJson)
        let sut = GranitaHttpClient(baseUrl: macAddress, transport: transport, authorization: .unauthenticated)

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await sut.post("/v1/pair", body: ABodyThatWillNotBeWritten(), returning: HealthResponse.self)
        }

        // then — the failure names the request rather than the Mac, and no request went out: a body
        // that would not encode must not reach a Mac as an empty one it then refuses for being empty.
        if case .requestNotBuildable = failure {} else {
            Issue.record("expected a body that cannot be written to be refused as such, got \(String(describing: failure))")
        }
        #expect(await transport.sent.isEmpty)
    }
}

// MARK: -

/// The only way to reach the encoder's refusal: every body this app sends is a struct of strings,
/// so nothing a route passes can fail to encode.
private struct ABodyThatWillNotBeWritten: Encodable {

    func encode(to encoder: any Encoder) throws {
        throw EncodingError.invalidValue(
            "nothing",
            EncodingError.Context(codingPath: [], debugDescription: "this cannot be written down")
        )
    }
}

/// Where the Mac is. A literal, so the failable initialiser Foundation offers cannot fail here.
private let macAddress = URL(string: "https://davides-macbook-pro.local:59144")!

private let healthJson = #"{"name":"Granita","apiVersion":1,"serverVersion":"0.4.2"}"#
