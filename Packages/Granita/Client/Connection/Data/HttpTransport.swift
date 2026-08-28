import Foundation

import ClientConnectionDomain
import CorePairingDomain

/// One request, as the API client describes it and a transport performs it.
public struct HttpRequest: Hashable, Sendable {

    public enum Method: String, Hashable, Sendable, CaseIterable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public let method: Method
    public let url: URL
    public let headers: [String: String]
    public let body: Data?

    public init(method: Method, url: URL, headers: [String: String], body: Data?) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// What came back, before anything has decided what it means.
public struct HttpResponse: Hashable, Sendable {

    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// Performs a request against one Mac.
///
/// **A seam inside `Data`, not a protocol in `Domain`.** Nothing above this layer names HTTP, and
/// moving an HTTP vocabulary into `Domain` so that one type could be faked would be the leak the
/// layering exists to prevent — the implementation and its only caller both live here. What it buys
/// is that every rule the API client enforces, the bearer and the version header and the whole table
/// mapping a refusal to something the phone has a screen for, is asserted on the host with no server
/// and no network.
///
/// It throws `ApiFailure` rather than an error of its own because being unable to reach the Mac is
/// the only failure it can produce, and a second one-case enum above it would exist only to be
/// mapped away.
public protocol HttpTransport: Sendable {
    func send(_ request: HttpRequest) async throws(ApiFailure) -> HttpResponse

    /// The key the server presented, once a handshake has happened.
    ///
    /// **A pinned transport already knows this and a first-contact one only learns it**, which is
    /// the entire difference between the two credentials a reader can offer, and it is why this is
    /// asked rather than assumed anywhere above.
    ///
    /// `nil` before anything has been sent, and never after a request has succeeded.
    func trustedFingerprint() async -> SpkiFingerprint?
}
