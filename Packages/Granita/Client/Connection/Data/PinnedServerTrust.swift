import Foundation
import Security

import CorePairingDomain

/// The `URLSession` delegate that decides whether a Mac is the Mac this phone paired with.
///
/// **It replaces the system's evaluation; it does not add to it.** The reasoning lives on
/// `PinnedTrust`, which is where the decision is and where the tests are. What is here is the
/// adaptation: pull the leaf key out of a `SecTrust`, ask, and turn the answer into a disposition.
///
/// One of these per paired Mac, because one fingerprint is one Mac. A session built with this
/// delegate can reach exactly one server, which is the property that makes a mixed-up base URL a
/// refused handshake rather than a silent read from the wrong machine.
public final class PinnedServerTrust: NSObject, URLSessionDelegate, Sendable {

    private let pinned: SpkiFingerprint
    private let logs: ConnectionLogs

    public init(pinnedTo pinned: SpkiFingerprint, logs: ConnectionLogs) {
        self.pinned = pinned
        self.logs = logs
    }

    /// What to do about a challenge, separated from the callback so it can be asserted without a
    /// server on the other end.
    ///
    /// Returns the credential alongside the disposition because `URLSession` wants both, and
    /// building the credential at the point of decision is what keeps "accepted" from being
    /// expressible without one.
    public func disposition(
        forAuthenticationMethod method: String,
        trust: SecTrust?
    ) -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {
        judgment(forAuthenticationMethod: method, trust: trust).answer
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let judgment = judgment(
            forAuthenticationMethod: challenge.protectionSpace.authenticationMethod,
            trust: challenge.protectionSpace.serverTrust
        )
        let answer = judgment.answer
        let event: ConnectionLogs.Event
        switch judgment {
        case .unhandledChallenge:
            completionHandler(answer.disposition, answer.credential)
            return
        case .serverTrustUnavailable:
            event = .serverTrustUnavailable(
                host: challenge.protectionSpace.host, port: challenge.protectionSpace.port
            )
        case .publicKeyUnavailable:
            event = .publicKeyUnavailable(
                host: challenge.protectionSpace.host, port: challenge.protectionSpace.port
            )
        case .pinnedKeyMismatched:
            event = .pinnedKeyMismatched(
                host: challenge.protectionSpace.host, port: challenge.protectionSpace.port
            )
        case .pinnedKeyMatched:
            event = .pinnedKeyMatched(
                host: challenge.protectionSpace.host, port: challenge.protectionSpace.port
            )
        }
        Task {
            await logs.record(event)
            completionHandler(answer.disposition, answer.credential)
        }
    }

    private func judgment(forAuthenticationMethod method: String, trust: SecTrust?) -> Judgment {
        guard method == NSURLAuthenticationMethodServerTrust else {
            // Granita issues no client certificate or HTTP credential; other challenges remain
            // the framework's business rather than being refused by our pinning decision.
            return .unhandledChallenge
        }
        guard let trust else {
            return .serverTrustUnavailable
        }
        guard let key = Self.leafPublicKey(of: trust) else {
            return .publicKeyUnavailable
        }
        guard let fingerprint = PinnedTrust.fingerprint(ofLeafPublicKeyX963: key) else {
            return .publicKeyUnavailable
        }
        guard pinned.matches(fingerprint) else {
            return .pinnedKeyMismatched
        }
        return .pinnedKeyMatched(trust)
    }

    /// The public key of the certificate the server presented, in the X9.63 form CryptoKit reads.
    ///
    /// The leaf, index zero, and never a chain: a self-signed certificate is its own chain, and a
    /// Granita that ever served an intermediate would be pinned by the wrong end of it.
    private static func leafPublicKey(of trust: SecTrust) -> Data? {
        guard
            let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            let leaf = chain.first,
            let key = SecCertificateCopyKey(leaf),
            let representation = SecKeyCopyExternalRepresentation(key, nil)
        else {
            return nil
        }
        return representation as Data
    }

    private enum Judgment {
        case unhandledChallenge
        case serverTrustUnavailable
        case publicKeyUnavailable
        case pinnedKeyMismatched
        case pinnedKeyMatched(SecTrust)

        var answer: (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {
            switch self {
            case .unhandledChallenge:
                (.performDefaultHandling, nil)
            case .serverTrustUnavailable, .publicKeyUnavailable, .pinnedKeyMismatched:
                (.cancelAuthenticationChallenge, nil)
            case .pinnedKeyMatched(let trust):
                (.useCredential, URLCredential(trust: trust))
            }
        }
    }
}
