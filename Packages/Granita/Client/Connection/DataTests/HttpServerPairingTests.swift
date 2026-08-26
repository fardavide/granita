import Foundation
import Testing

import ClientConnectionData
import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain
import CorePairingDomain

/// The two routes a phone may reach before it has a token, and therefore the two an attacker on the
/// network may reach as well.
@Suite("Http server pairing")
struct HttpServerPairingTests {

    // MARK: - Health, which is asked before a code is ever spent

    @Test
    func `given a Mac when its health is read then it says which contract it serves`() async throws {
        // given
        let scenario = Scenario(
            status: 200,
            json: #"{"name":"Granita","apiVersion":1,"serverVersion":"0.4.2"}"#
        )

        // when
        let health = try await scenario.sut.health()

        // then
        #expect(health == HealthResponse(name: "Granita", apiVersion: 1, serverVersion: "0.4.2"))
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.method == .get)
        #expect(request.url.path() == "/v1/health")
    }

    @Test
    func `given health when it is read then no token is offered`() async throws {
        // given — this route answers before there is one, so sending an empty bearer would be a
        // failed authentication attempt counted against a phone that has done nothing wrong.
        let scenario = Scenario(
            status: 200,
            json: #"{"name":"Granita","apiVersion":1,"serverVersion":"0.4.2"}"#
        )

        // when
        _ = try await scenario.sut.health()

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.headers["Authorization"] == nil)
    }

    @Test
    func `when any request is made then it declares which contract this phone speaks`() async throws {
        // given
        let scenario = Scenario(
            status: 200,
            json: #"{"name":"Granita","apiVersion":1,"serverVersion":"0.4.2"}"#
        )

        // when
        _ = try await scenario.sut.health()

        // then — the Mac refuses a newer contract outright rather than serving something the phone
        // will misread, and a header it never sends cannot be refused.
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.headers[Branding.apiVersionHeader] == String(Branding.apiVersion))
    }

    // MARK: - What the handshake ended up trusting

    @Test
    func `given a Mac that presented a key when it is asked what it trusted then the transport answers`() async {
        // given — the spoken path carries no pin, so what got trusted does not exist until a
        // handshake has happened. Asking the transport is the whole implementation, and the reason
        // it is not remembered here: a fingerprint this type held would be one it was told rather
        // than one it saw.
        let scenario = Scenario(status: 200, json: acceptedPairing)
        await scenario.transport.present(SpkiFingerprint(rawValue: "9f86d081884c7d659a2feaa0c55ad015"))

        // when
        let trusted = await scenario.sut.trustedFingerprint()

        // then — this is the value that gets pinned for every later request, so a wrong one is a
        // phone that trusts a machine it never spoke to.
        #expect(trusted == SpkiFingerprint(rawValue: "9f86d081884c7d659a2feaa0c55ad015"))
    }

    // MARK: - Where a scanned link points

    @Test
    func `given a link the camera read when pairing then the request goes where the link said`() async throws {
        // given — the composition root used to build this address, which put URL construction in the
        // one layer no test can reach.
        let scenario = Scenario(
            mac: PairingLink(
                host: "mac-studio.local",
                port: 61022,
                code: "9d41e0c7a2b85f36",
                fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
            ),
            status: 200,
            json: acceptedPairing
        )

        // when
        _ = try await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))

        // then — https because the Mac serves TLS, and the port the link named rather than a default.
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.url.scheme == "https")
        #expect(request.url.host() == "mac-studio.local")
        #expect(request.url.port == 61022)
        #expect(request.url.path() == "/v1/pair")
    }

    @Test
    func `given a link naming an IPv6 address when pairing then the literal is bracketed`() async throws {
        // given — a QR minted on a Mac whose only address is v6, which is what a network with no
        // IPv4 on it produces. Bare, the colons read as the port separator and there is no URL at
        // the end of it.
        let scenario = Scenario(
            mac: PairingLink(
                host: "2001:db8::a1",
                port: 61022,
                code: "9d41e0c7a2b85f36",
                fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
            ),
            status: 200,
            json: acceptedPairing
        )

        // when
        _ = try await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.url.absoluteString == "https://[2001:db8::a1]:61022/v1/pair")
        #expect(request.url.port == 61022)
    }

    @Test
    func `given a Mac that answered on a link-local address when six words are spent then the zone survives`() async throws {
        // given — what `NWPath` hands back on a link-local route, zone attached, and the address
        // the words path borrows. Both halves need saying: without the brackets there is no URL,
        // and without `%25` in place of the `%` there is no zone — and a v6 link-local address
        // without its zone is not routable at all.
        let scenario = Scenario(
            mac: .spoken(code: "cabin-cactus-camera-candle-harbour-lantern", at: ServerAddress(host: "fe80::1%en0", port: 61022)),
            status: 200,
            json: acceptedPairing
        )

        // when
        _ = try await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.url.absoluteString == "https://[fe80::1%25en0]:61022/v1/pair")
        #expect(request.url.port == 61022)
    }

    @Test
    func `given six words resolved to a host that cannot go in a url then it addresses nothing rather than trapping`() async {
        // given — the twin of the case below, on the other credential. The spoken path takes the
        // address a browse resolved rather than one a QR carried, and a resolver that hands back
        // something no URL will hold must end as "could not reach your Mac" rather than as a trap on
        // the one screen a reader cannot leave.
        let scenario = Scenario(
            mac: .spoken(code: "cabin-cactus-camera-candle-harbour-lantern", at: ServerAddress(host: "not a host", port: 61022)),
            status: 200,
            json: acceptedPairing
        )

        // when - then
        await #expect(throws: Never.self) {
            _ = try? await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))
        }
    }

    @Test
    func `given a link whose host cannot go in a url then it addresses nothing rather than trapping`() async {
        // given — a damaged scan. The reader is pointing at the right screen and it is not working,
        // which is a sentence, not a crash.
        let scenario = Scenario(
            mac: PairingLink(
                host: "not a host",
                port: 61022,
                code: "9d41e0c7a2b85f36",
                fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
            ),
            status: 200,
            json: acceptedPairing
        )

        // when - then
        await #expect(throws: Never.self) {
            _ = try? await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))
        }
    }

    // MARK: - Pairing

    @Test
    func `given a code and a device when pairing then all three fields reach the pairing route`() async throws {
        // given
        let scenario = Scenario(status: 200, json: acceptedPairing)

        // when
        _ = try await scenario.sut.pair(
            with: "9d41e0c7a2b85f36",
            as: PairingDevice(name: "Davide's iPhone", platform: "iOS")
        )

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.method == .post)
        #expect(request.url.path() == "/v1/pair")
        let body = try #require(request.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object == [
            "code": "9d41e0c7a2b85f36",
            "deviceName": "Davide's iPhone",
            "platform": "iOS"
        ])
    }

    @Test
    func `given the Mac accepts when pairing then the token and both identifiers come back typed`() async throws {
        // given
        let scenario = Scenario(status: 200, json: acceptedPairing)

        // when
        let paired = try await scenario.sut.pair(
            with: "9d41e0c7a2b85f36",
            as: PairingDevice(name: "Davide's iPhone", platform: "iOS")
        )

        // then — three strings that must not be interchangeable, so they arrive as three types.
        #expect(paired == PairedDevice(
            token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
            deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
            serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
        ))
    }

    @Test
    func `given pairing when the request is made then it carries no bearer token`() async throws {
        // given — the whole point of this route is that the caller does not have one yet.
        let scenario = Scenario(status: 200, json: acceptedPairing)

        // when
        _ = try await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.headers["Authorization"] == nil)
    }

    // MARK: - The refusals

    @Test
    func `given a code the Mac refused when pairing then it is expired and nothing more is claimed`() async {
        // given — the Mac answers the same way whether the code never existed or merely ran out,
        // deliberately: a caller told which has an oracle for whether it is guessing in the right
        // shape at all. The phone must not invent the distinction back.
        let scenario = Scenario(status: 401, json: refusal("pairingExpired", "that pairing code has expired or was already used"))

        // when - then
        await #expect(throws: ApiFailure.pairingExpired) {
            try await scenario.sut.pair(with: "guess", as: PairingDevice(name: "iPhone", platform: "iOS"))
        }
    }

    @Test
    func `given five failures in a minute when pairing again then it is rate limited`() async {
        // given
        let scenario = Scenario(status: 429, json: refusal("rateLimited", "too many failed attempts; wait a minute"))

        // when - then
        await #expect(throws: ApiFailure.rateLimited) {
            try await scenario.sut.pair(with: "guess", as: PairingDevice(name: "iPhone", platform: "iOS"))
        }
    }

    @Test
    func `given the Mac cannot be reached when pairing then the system's own words survive`() async {
        // given — the diagnostic is what the screen prints in small print under a sentence of ours.
        let scenario = Scenario(failing: .unreachable(diagnostic: "Could not connect to the server."))

        // when - then
        await #expect(throws: ApiFailure.unreachable(diagnostic: "Could not connect to the server.")) {
            try await scenario.sut.health()
        }
    }

    @Test
    func `given a refusal code this version has never heard of then the message is what survives`() async {
        // given — a newer Mac may invent one. Failing to decode the body would throw away the only
        // sentence anybody could act on.
        let scenario = Scenario(status: 403, json: refusal("worktreeQuarantined", "that worktree is in quarantine"))

        // when - then
        await #expect(
            throws: ApiFailure.notUnderstood(diagnostic: "worktreeQuarantined: that worktree is in quarantine")
        ) {
            try await scenario.sut.health()
        }
    }

    @Test
    func `given a refusal that is not the contract at all then the status is all there is to say`() async {
        // given — a proxy, a captive portal or a load balancer answering for a Mac that never saw the
        // request. There is no code in the body to read, so the only true thing left is the number.
        let scenario = Scenario(status: 502, json: "<html><body>Bad Gateway</body></html>")

        // when - then
        await #expect(
            throws: ApiFailure.notUnderstood(
                diagnostic: "the Mac refused with 502 and a body this version could not read"
            )
        ) {
            try await scenario.sut.health()
        }
    }

    @Test
    func `given an answer that is not the contract when pairing then it is not understood`() async {
        // given — a captive portal, or a Mac from a future this build cannot read.
        let scenario = Scenario(status: 200, json: #"{"greeting":"hello"}"#)

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await scenario.sut.pair(with: "code", as: PairingDevice(name: "iPhone", platform: "iOS"))
        }

        // then
        if case .notUnderstood = failure {} else {
            Issue.record("expected an unreadable body to be reported as such, got \(String(describing: failure))")
        }
    }
}

// MARK: -

private struct Scenario {

    let sut: HttpServerPairing
    let transport: FakeHttpTransport

    init(status: Int, json: String) {
        transport = FakeHttpTransport(status: status, json: json)
        sut = HttpServerPairing(macAt: macAddress, transport: transport)
    }

    /// Addressed the way the app addresses it: from the link the camera read.
    init(mac link: PairingLink, status: Int, json: String) {
        transport = FakeHttpTransport(status: status, json: json)
        sut = HttpServerPairing(mac: link, transport: transport)
    }

    /// And the other way the app addresses it: from whichever credential the reader offered, which
    /// is the only path an address the Mac was *resolved* to travels on.
    init(mac attempt: PairingAttempt, status: Int, json: String) {
        transport = FakeHttpTransport(status: status, json: json)
        sut = HttpServerPairing(mac: attempt, transport: transport)
    }

    init(failing failure: ApiFailure) {
        transport = FakeHttpTransport(failing: failure)
        sut = HttpServerPairing(macAt: macAddress, transport: transport)
    }
}

/// Where the Mac is. A literal, so the failable initialiser Foundation offers cannot fail here.
private let macAddress = URL(string: "https://davides-macbook-pro.local:59144")!

private let acceptedPairing = """
    {
      "token": "1f0e4d7c6b5a49382736251403f2e1d0",
      "deviceId": "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001",
      "serverInstanceId": "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22"
    }
    """

private func refusal(_ code: String, _ message: String) -> String {
    #"{"error":{"code":"\#(code)","message":"\#(message)"}}"#
}
