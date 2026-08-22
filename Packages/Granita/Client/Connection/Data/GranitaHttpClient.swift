import Foundation

import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain

/// Turns a call into a request, a reply into a value, and a refusal into an `ApiFailure`.
///
/// Everything the two API surfaces share is here and nowhere else: the contract version on every
/// request, the bearer on the ones that carry one, and the single table that says what each refusal
/// code means. A second copy of that table would be a screen that quietly stops appearing.
struct GranitaHttpClient: Sendable {

    /// Whether this client speaks for a device that has a token.
    ///
    /// Two named cases rather than an optional token: `unauthenticated` is a property of the two
    /// routes that answer before pairing, not an absence somebody forgot to fill in.
    enum Authorization: Hashable, Sendable {
        case unauthenticated
        case bearer(PairingToken)
    }

    /// Scheme, host and port, and nothing else — the route supplies the whole path.
    let baseUrl: URL

    let transport: any HttpTransport
    let authorization: Authorization

    func get<Value: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        returning: Value.Type
    ) async throws(ApiFailure) -> Value {
        try decode(returning, from: try await perform(.get, path, query: query, body: nil))
    }

    func post<Value: Decodable>(
        _ path: String,
        body: some Encodable,
        returning: Value.Type
    ) async throws(ApiFailure) -> Value {
        try decode(returning, from: try await perform(.post, path, query: [], body: try encode(body)))
    }

    /// A route that answers 204 and has nothing to decode.
    func post(_ path: String, body: some Encodable) async throws(ApiFailure) {
        _ = try await perform(.post, path, query: [], body: try encode(body))
    }

    func patch<Value: Decodable>(
        _ path: String,
        body: some Encodable,
        returning: Value.Type
    ) async throws(ApiFailure) -> Value {
        try decode(returning, from: try await perform(.patch, path, query: [], body: try encode(body)))
    }

    private func perform(
        _ method: HttpRequest.Method,
        _ path: String,
        query: [URLQueryItem],
        body: Data?
    ) async throws(ApiFailure) -> Data {
        var headers = [Branding.apiVersionHeader: String(Branding.apiVersion)]
        if case .bearer(let token) = authorization {
            headers["Authorization"] = "Bearer \(token.rawValue)"
        }
        if body != nil {
            headers["Content-Type"] = "application/json"
        }

        let response = try await transport.send(
            HttpRequest(
                method: method,
                url: try url(for: path, query: query),
                headers: headers,
                body: body
            )
        )
        guard (200..<300).contains(response.statusCode) else {
            throw refusal(status: response.statusCode, body: response.body)
        }
        return response.body
    }

    /// What a non-2xx reply means, decided by the **code** in the body and never by the status.
    ///
    /// SPEC §8 makes the codes the contract for exactly this reason: two refusals the Mac spells
    /// differently on purpose share a status, and a mapping that read the number could not tell them
    /// apart. The status only ever reaches a diagnostic string.
    private func refusal(status: Int, body: Data) -> ApiFailure {
        guard let refused = try? decoder.decode(Refusal.self, from: body) else {
            return .notUnderstood(
                diagnostic: "the Mac refused with \(status) and a body this version could not read"
            )
        }
        guard let code = ApiErrorCode(rawValue: refused.error.code) else {
            // A newer Mac may invent one. Failing to decode would throw away the only sentence
            // anybody could act on.
            return .notUnderstood(diagnostic: "\(refused.error.code): \(refused.error.message)")
        }
        switch code {
        case .unauthorized: return .unauthorized
        case .pairingExpired: return .pairingExpired
        case .rateLimited: return .rateLimited
        case .projectNotVisible: return .projectNotVisible
        case .worktreeGone: return .worktreeGone
        case .fileGone: return .fileGone
        case .staleContentHash: return .staleContentHash
        case .gitFailure: return .gitFailure(message: refused.error.message)
        case .tooLarge: return .tooLarge
        case .badRequest: return .badRequest(message: refused.error.message)
        case .unsupportedApiVersion: return .unsupportedApiVersion
        }
    }

    /// The address of a route on this Mac.
    ///
    /// The path is replaced rather than appended, so a route reads as the route SPEC §8 names. The
    /// base carries scheme, host and port and never a path of its own, which is what makes that safe.
    private func url(for path: String, query: [URLQueryItem]) throws(ApiFailure) -> URL {
        var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else {
            throw .requestNotBuildable(diagnostic: "could not address \(path) on \(baseUrl)")
        }
        return url
    }

    private func encode(_ body: some Encodable) throws(ApiFailure) -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw .requestNotBuildable(diagnostic: "could not write the body of the request: \(error)")
        }
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws(ApiFailure) -> Value {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw .notUnderstood(diagnostic: "the Mac's answer was not a \(type): \(error)")
        }
    }

    /// Timestamps on the wire are ISO 8601, stated here because the Mac states it too. A decoder is
    /// a class and is not `Sendable`, so it is made per call rather than held.
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// `{"error": {"code": …, "message": …}}`, read leniently.
///
/// The code is a `String` rather than the enumeration on purpose: a Mac from a version this build
/// has never seen must not turn a refusal into a body that fails to decode at all.
private struct Refusal: Decodable {

    struct Reason: Decodable {
        let code: String
        let message: String
    }

    let error: Reason
}
