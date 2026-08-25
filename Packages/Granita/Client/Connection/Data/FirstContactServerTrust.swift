import Foundation
import Security

import CorePairingDomain

/// The `URLSession` delegate for a Mac nobody vouched for, which is what six typed words amount to.
///
/// **A type of its own rather than a `nil` pin on `PinnedServerTrust`, and that is the whole
/// design.** The two differ by one word — record versus judge — and collapsing them would leave
/// "accept anything" one optional away from the delegate every authenticated request in this app
/// goes through. Two names cannot be confused by a caller passing the wrong argument; one name with
/// a mode can. The cost is a second small class, and it is worth it.
///
/// What this accepts is any P-256 leaf, and what it does with it is remember it. That is trust on
/// first use: whoever answers at that address in that moment becomes the Mac, and everything after
/// pairing is pinned strictly to whatever this recorded. The screen offering this path says so, in
/// as many words, because a risk nobody is told about is one nobody accepted.
public final class FirstContactServerTrust: NSObject, URLSessionDelegate, Sendable {

    private let observed = Observed()

    public override init() {
        super.init()
    }

    /// The key the Mac presented, or nothing if no handshake has happened yet.
    public func fingerprint() async -> SpkiFingerprint? {
        await observed.fingerprint
    }

    /// What to do about a challenge, separated from the callback so it can be asserted without a
    /// server on the other end — the same split `PinnedServerTrust` makes and for the same reason.
    public func disposition(
        forAuthenticationMethod method: String,
        trust: SecTrust?
    ) async -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {
        guard method == NSURLAuthenticationMethodServerTrust else {
            // Not ours to answer. Granita issues no client certificate and no HTTP credential.
            return (.performDefaultHandling, nil)
        }
        guard
            let trust,
            let key = Self.leafPublicKey(of: trust),
            let fingerprint = PinnedTrust.fingerprint(ofLeafPublicKeyX963: key)
        else {
            // Nothing to record is not the same as nothing to check: a handshake this phone cannot
            // describe afterwards is one it must not build a pinned session from, so it is refused
            // here rather than accepted and forgotten.
            return (.cancelAuthenticationChallenge, nil)
        }
        await observed.record(fingerprint)
        return (.useCredential, URLCredential(trust: trust))
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let method = challenge.protectionSpace.authenticationMethod
        let trust = challenge.protectionSpace.serverTrust
        Task {
            let answer = await disposition(forAuthenticationMethod: method, trust: trust)
            completionHandler(answer.disposition, answer.credential)
        }
    }

    /// The public key of the certificate the server presented, in the X9.63 form CryptoKit reads.
    ///
    /// The leaf, index zero, and never a chain: a self-signed certificate is its own chain.
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

    /// **The first key wins.** A session that handshook once and was challenged again mid-pairing
    /// must not silently adopt a second Mac's key, which is the one way a first-contact delegate
    /// could be turned into a moving target.
    private actor Observed {

        private(set) var fingerprint: SpkiFingerprint?

        func record(_ observed: SpkiFingerprint) {
            guard fingerprint == nil else { return }
            fingerprint = observed
        }
    }
}
