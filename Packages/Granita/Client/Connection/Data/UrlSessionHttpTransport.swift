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

    public init(pinnedTo fingerprint: SpkiFingerprint) {
        // Ephemeral: nothing about a diff belongs in a URL cache on disk, and a 304 against a
        // revision the phone is polling for would be a change it never learns about.
        session = URLSession(
            configuration: .ephemeral,
            delegate: PinnedServerTrust(pinnedTo: fingerprint),
            delegateQueue: nil
        )
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
        } catch let failure as ApiFailure {
            throw failure
        } catch {
            // The diagnostic, not the advice. `URLError` writes "the operation couldn't be
            // completed", which is true of every failure there has ever been; the screen supplies
            // the sentence and prints this underneath in small print.
            throw ApiFailure.unreachable(diagnostic: "\(error)")
        }
    }
}
