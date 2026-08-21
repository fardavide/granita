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

    public init(pinnedTo pinned: SpkiFingerprint) {
        self.pinned = pinned
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
        guard method == NSURLAuthenticationMethodServerTrust else {
            // Not ours to answer. Granita issues no client certificate and no HTTP credential, so
            // anything else is the framework's business and cancelling it here would refuse a
            // challenge this app has no opinion about.
            return (.performDefaultHandling, nil)
        }
        guard let trust, let key = Self.leafPublicKey(of: trust) else {
            return (.cancelAuthenticationChallenge, nil)
        }
        guard PinnedTrust.isTrusted(leafPublicKeyX963: key, against: pinned) else {
            return (.cancelAuthenticationChallenge, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let answer = disposition(
            forAuthenticationMethod: challenge.protectionSpace.authenticationMethod,
            trust: challenge.protectionSpace.serverTrust
        )
        completionHandler(answer.disposition, answer.credential)
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
}
