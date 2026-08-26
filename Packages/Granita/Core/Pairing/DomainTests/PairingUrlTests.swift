import Foundation
import Testing

import CoreBrandingDomain
import CorePairingDomain

/// Both ends of one string. The Mac writes it into a QR and the phone reads it back out of a
/// camera, so the round trip is the contract — and the parsing half is asserted here rather than
/// when the phone grows a scanner, because a link nobody can read is a defect in the writer.
struct PairingLinkTests {

    // MARK: - Writing

    @Test func `when writing a link then it carries the host, port, code and fingerprint`() throws {
        // given
        let link = PairingLink(
            host: "macbook-pro.local",
            port: 8737,
            code: "5f1c9a2b",
            fingerprint: SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")
        )

        // when
        let url = try #require(URL(string: link.text))

        // then
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.scheme == Branding.urlScheme)
        #expect(parts.host == "pair")
        #expect(parts.queryItems?.first { $0.name == "host" }?.value == "macbook-pro.local")
        #expect(parts.queryItems?.first { $0.name == "port" }?.value == "8737")
        #expect(parts.queryItems?.first { $0.name == "code" }?.value == "5f1c9a2b")
        #expect(
            parts.queryItems?.first { $0.name == "spki" }?.value
                == "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ="
        )
    }

    @Test func `given a fingerprint containing base64 punctuation when writing then the link escapes it`() {
        // given
        let link = PairingLink(
            host: "macbook-pro.local",
            port: 8737,
            code: "5f1c9a2b",
            fingerprint: SpkiFingerprint(rawValue: "a+b/c=")
        )

        // when
        let text = link.text

        // then
        // All three are legal in a query and all three mean something else to a reader that decodes
        // one as a form body, so a fingerprint left raw is one that survives the camera and not the
        // parse.
        #expect(text.contains("spki=a%2Bb%2Fc%3D"))
    }

    // MARK: - Reading

    @Test func `given a written link when reading it back then every field survives`() throws {
        // given
        let written = PairingLink(
            host: "macbook-pro.local",
            port: 51234,
            code: "gale-harbor-ivory-kelp-lantern-meadow",
            fingerprint: SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")
        )

        // when
        let read = try PairingLink(url: #require(URL(string: written.text)))

        // then
        #expect(read == written)
    }

    @Test func `given a url of another scheme when reading it then it is refused as not ours`() throws {
        // given
        let url = try #require(URL(string: "https://example.com/pair?host=a&port=1&code=b&spki=c"))

        // when - then
        #expect(throws: PairingLinkError.notAPairingLink) {
            try PairingLink(url: url)
        }
    }

    @Test func `given our scheme but another action when reading it then it is refused as not ours`() throws {
        // given
        let url = try #require(URL(string: "\(Branding.urlScheme)://open?host=a&port=1&code=b&spki=c"))

        // when - then
        #expect(throws: PairingLinkError.notAPairingLink) {
            try PairingLink(url: url)
        }
    }

    @Test func `given our link with nothing on it when reading it then it names the first field it wants`() throws {
        // given — a QR read through a fingerprint, or a link truncated by whatever carried it. There
        // are no query items at all, which is a different absence from a field being empty and must
        // not be one: reading it as "no fields" is what turns it into the sentence below.
        let url = try #require(URL(string: "\(Branding.urlScheme)://pair"))

        // when - then
        #expect(throws: PairingLinkError.missingField(named: "host")) {
            try PairingLink(url: url)
        }
    }

    @Test func `given a link with no fingerprint when reading it then it names the field it wants`() throws {
        // given
        let url = try #require(URL(string: "\(Branding.urlScheme)://pair?host=a&port=1&code=b"))

        // when - then
        #expect(throws: PairingLinkError.missingField(named: "spki")) {
            try PairingLink(url: url)
        }
    }

    @Test func `given a port that is not a number when reading it then it says so`() throws {
        // given
        let url = try #require(URL(string: "\(Branding.urlScheme)://pair?host=a&port=eight&code=b&spki=c"))

        // when - then
        #expect(throws: PairingLinkError.malformedField(named: "port")) {
            try PairingLink(url: url)
        }
    }
}
