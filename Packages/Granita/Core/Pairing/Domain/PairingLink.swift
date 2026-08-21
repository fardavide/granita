import Foundation

import CoreBrandingDomain

/// Everything a phone needs to pair, in one string: where the Mac is, the one-time code, and the
/// public key to pin it by.
///
/// The QR is a picture of this and nothing more, which is why this type is the contract rather than
/// the image — a link tapped in Messages and a code read aloud carry the same fields.
///
/// The fingerprint travels **with** the code rather than being fetched from the server it
/// authenticates, which is the entire point: a Mac impersonating another one can answer any request
/// it likes, and cannot produce the key whose hash the reader already has on screen.
public struct PairingLink: Hashable, Sendable {

    /// The name or address the phone should connect to. A name this Mac answers to, never a path.
    public let host: String

    public let port: Int

    /// The one-time code, spent by `/v1/pair`. Either the code the QR carries or the spoken words
    /// typed instead of it — the server accepts both for one pairing.
    public let code: String

    public let fingerprint: SpkiFingerprint

    public init(host: String, port: Int, code: String, fingerprint: SpkiFingerprint) {
        self.host = host
        self.port = port
        self.code = code
        self.fingerprint = fingerprint
    }

    /// Reads one back — from a scanned QR, or from a link tapped anywhere the system offers it.
    public init(url: URL) throws(PairingLinkError) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == Branding.urlScheme,
              parts.host?.lowercased() == Self.action
        else {
            throw PairingLinkError.notAPairingLink
        }

        let fields = parts.queryItems ?? []
        func field(_ name: String) throws(PairingLinkError) -> String {
            guard let value = fields.first(where: { $0.name == name })?.value, value.isEmpty == false else {
                throw PairingLinkError.missingField(named: name)
            }
            return value
        }

        host = try field("host")
        guard let port = Int(try field("port")) else {
            throw PairingLinkError.malformedField(named: "port")
        }
        self.port = port
        code = try field("code")
        fingerprint = SpkiFingerprint(rawValue: try field("spki"))
    }

    /// The `granita://pair?host=&port=&code=&spki=` form SPEC §8 specifies.
    ///
    /// A string rather than a `URL`, because that is what every consumer of it actually wants — a
    /// QR encodes bytes, the terminal prints a line — and because building a `URL` here would put
    /// an optional in the middle of a value that cannot fail to exist.
    public var text: String {
        let query = [
            ("host", host),
            ("port", String(port)),
            ("code", code),
            ("spki", fingerprint.rawValue)
        ]
        .map { name, value in "\(name)=\(Self.escaped(value))" }
        .joined(separator: "&")
        return "\(Branding.urlScheme)://\(Self.action)?\(query)"
    }

    /// The URL's authority, which is what this link asks for rather than where it points.
    private static let action = "pair"

    /// Everything outside RFC 3986's unreserved set is escaped, rather than only what a query
    /// forbids. A base64 fingerprint routinely contains `+`, `/` and `=`: all three are legal in a
    /// query and all three mean something else to a reader that treats one as a form body — and a
    /// fingerprint that survives the camera but not the parse is exactly the failure this string
    /// exists to prevent.
    private static func escaped(_ value: String) -> String {
        // Non-optional in practice: the initialiser only returns nil for a string that is not
        // valid Unicode, which nothing here can be. Handled rather than forced.
        value.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? value
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}

public enum PairingLinkError: Error, Hashable, Sendable {

    /// Some other URL entirely — a web page, or another app's scheme. Common enough to be a case
    /// rather than a failure: a camera pointed at a poster finds QR codes all the time.
    case notAPairingLink

    case missingField(named: String)
    case malformedField(named: String)
}
