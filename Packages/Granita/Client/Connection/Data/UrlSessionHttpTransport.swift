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

    private let session: any SessionRequests
    private let logs: ConnectionLogs
    private let requestTimeout: Duration
    private let elapsedSince: @Sendable (ContinuousClock.Instant) -> Duration

    /// What this transport ended up trusting. A closure because the two ways of building one answer
    /// it from different places — a pin is known at construction, a first contact only after a
    /// handshake — and the caller above must not have to know which kind it holds.
    private let trusted: @Sendable () async -> SpkiFingerprint?

    public init(pinnedTo fingerprint: SpkiFingerprint, logs: ConnectionLogs) {
        // Ephemeral: nothing about a diff belongs in a URL cache on disk, and a 304 against a
        // revision the phone is polling for would be a change it never learns about.
        session = UrlSessionRequests(session: URLSession(
            configuration: .ephemeral,
            delegate: PinnedServerTrust(pinnedTo: fingerprint, logs: logs),
            delegateQueue: nil
        ))
        self.logs = logs
        requestTimeout = .seconds(60)
        elapsedSince = { $0.duration(to: ContinuousClock.now) }
        // A pinned session refuses everything else, so what it trusted is the pin by construction.
        trusted = { fingerprint }
    }

    public convenience init(pinnedTo fingerprint: SpkiFingerprint, logs: ConnectionLogs, requestTimeout: Duration) {
        self.init(
            performing: UrlSessionRequests(session: URLSession(
                configuration: Self.sessionConfiguration(requestTimeout: requestTimeout),
                delegate: PinnedServerTrust(pinnedTo: fingerprint, logs: logs),
                delegateQueue: nil
            )),
            trusting: { fingerprint },
            logs: logs,
            requestTimeout: requestTimeout
        )
    }

    /// A transport for a Mac nobody vouched for, which is what six typed words amount to.
    ///
    /// **Only ever for the pairing handshake.** What comes back from `trustedFingerprint()` is what
    /// the repository's own transport is then pinned to, so the window in which anything is
    /// unpinned is one exchange long and ends the moment pairing does. The screen that offers this
    /// path says what it means; see `.ai/docs/decisions.md`.
    public init(trustingFirstAnswer: Void, logs: ConnectionLogs) {
        let trust = FirstContactServerTrust()
        session = UrlSessionRequests(session: URLSession(configuration: .ephemeral, delegate: trust, delegateQueue: nil))
        self.logs = logs
        requestTimeout = .seconds(60)
        elapsedSince = { $0.duration(to: ContinuousClock.now) }
        trusted = { await trust.fingerprint() }
    }

    init(
        performing session: any SessionRequests,
        trusting trusted: @escaping @Sendable () async -> SpkiFingerprint?,
        logs: ConnectionLogs,
        requestTimeout: Duration = .seconds(60),
        elapsedSince: @escaping @Sendable (ContinuousClock.Instant) -> Duration = { $0.duration(to: ContinuousClock.now) }
    ) {
        self.session = session
        self.trusted = trusted
        self.logs = logs
        self.requestTimeout = requestTimeout
        self.elapsedSince = elapsedSince
    }

    public func trustedFingerprint() async -> SpkiFingerprint? {
        await trusted()
    }

    static func sessionConfiguration(requestTimeout: Duration) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        let timeout = requestTimeout.components
        let seconds = Double(timeout.seconds) + Double(timeout.attoseconds) / 1e18
        configuration.timeoutIntervalForRequest = seconds
        configuration.timeoutIntervalForResource = seconds
        return configuration
    }

    public func send(_ request: HttpRequest) async throws(ApiFailure) -> HttpResponse {
        guard request.url.scheme == "https" else {
            throw .requestNotBuildable(diagnostic: "Granita connections require HTTPS")
        }
        var outgoing = URLRequest(url: request.url)
        let timeout = requestTimeout.components
        outgoing.timeoutInterval = Double(timeout.seconds) + Double(timeout.attoseconds) / 1e18
        outgoing.httpMethod = request.method.rawValue
        outgoing.httpBody = request.body
        for (name, value) in request.headers {
            outgoing.setValue(value, forHTTPHeaderField: name)
        }

        let started = ContinuousClock.now
        await logs.record(.requestStarted(method: request.method, url: request.url))
        do {
            let (body, response) = try await session.data(for: outgoing)
            guard let http = response as? HTTPURLResponse else {
                throw ApiFailure.notUnderstood(diagnostic: "the reply was not an HTTP response")
            }
            await logs.record(.requestFinished(method: request.method, url: request.url, statusCode: http.statusCode))
            await logs.record(.requestTimed(method: request.method, url: request.url, duration: elapsedSince(started), outcome: .succeeded))
            return HttpResponse(statusCode: http.statusCode, body: body)
        } catch {
            await logs.record(.requestFailed(
                method: request.method,
                url: request.url,
                errors: ConnectionLogError.chain(for: error)
            ))
            // **What the failure means is `ApiFailure`'s to say, not this file's.** Nothing can
            // build a `URLSession` in a test binary, so a decision written here is one nothing holds
            // to its behaviour — and the decision that used to live here was wrong: a cancelled
            // request was reported as the Mac being unreachable.
            let failure = ApiFailure.forTransport(error)
            await logs.record(.requestTimed(method: request.method, url: request.url, duration: elapsedSince(started), outcome: failure == .cancelled ? .cancelled : .failed))
            throw failure
        }
    }
}
