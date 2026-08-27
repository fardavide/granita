import Foundation

import ClientConnectionDomain
import CorePairingDomain

/// Reaches one Mac, and refuses to reach any other.
///
/// The session is built around a `PinnedServerTrust` for one fingerprint, so a request sent to the
/// wrong address fails in the handshake rather than reading private source code off a machine
/// nobody paired with. One of these per paired Mac, for the life of the app: a session per request
/// would leak a delegate and a connection pool every time the phone polls.
public final class UrlSessionHttpTransport: HttpTransport {

    private let session: URLSession

    /// What this transport ended up trusting. A closure because the two ways of building one answer
    /// it from different places — a pin is known at construction, a first contact only after a
    /// handshake — and the caller above must not have to know which kind it holds.
    private let trusted: @Sendable () async -> SpkiFingerprint?

    public init(pinnedTo fingerprint: SpkiFingerprint) {
        // Ephemeral: nothing about a diff belongs in a URL cache on disk, and a 304 against a
        // revision the phone is polling for would be a change it never learns about.
        session = URLSession(
            configuration: .ephemeral,
            delegate: PinnedServerTrust(pinnedTo: fingerprint),
            delegateQueue: nil
        )
        // A pinned session refuses everything else, so what it trusted is the pin by construction.
        trusted = { fingerprint }
    }

    /// A transport for a Mac nobody vouched for, which is what six typed words amount to.
    ///
    /// **Only ever for the pairing handshake.** What comes back from `trustedFingerprint()` is what
    /// the repository's own transport is then pinned to, so the window in which anything is
    /// unpinned is one exchange long and ends the moment pairing does. The screen that offers this
    /// path says what it means; see `.claude/docs/decisions.md`.
    public init(trustingFirstAnswer: Void = ()) {
        let trust = FirstContactServerTrust()
        session = URLSession(configuration: .ephemeral, delegate: trust, delegateQueue: nil)
        trusted = { await trust.fingerprint() }
    }

    public func trustedFingerprint() async -> SpkiFingerprint? {
        await trusted()
    }

    public func send(_ request: HttpRequest) async throws(ApiFailure) -> HttpResponse {
        var outgoing = URLRequest(url: request.url)
        outgoing.httpMethod = request.method.rawValue
        outgoing.httpBody = request.body
        for (name, value) in request.headers {
            outgoing.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (body, response) = try await session.data(for: outgoing)
            guard let http = response as? HTTPURLResponse else {
                throw ApiFailure.notUnderstood(diagnostic: "the reply was not an HTTP response")
            }
            return HttpResponse(statusCode: http.statusCode, body: body)
        } catch {
            // **What the failure means is `ApiFailure`'s to say, not this file's.** Nothing can
            // build a `URLSession` in a test binary, so a decision written here is one nothing holds
            // to its behaviour — and the decision that used to live here was wrong: a cancelled
            // request was reported as the Mac being unreachable.
            throw ApiFailure.forTransport(error)
        }
    }
}
