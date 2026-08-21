import Foundation
import Hummingbird

/// The codes the client branches on.
///
/// Part of the wire contract rather than an implementation detail: the phone shows a different
/// screen for each of several of these, so adding one is a contract change and renaming one is a
/// version skew that reaches a reader as a screen that never appears.
public enum ApiErrorCode: String, Codable, Hashable, Sendable, CaseIterable {

    case unauthorized
    case pairingExpired
    case rateLimited

    /// The project exists but the user has not enabled it. Distinct from "not found" on purpose:
    /// the server declines to say whether an identifier it will not serve corresponds to anything.
    case projectNotVisible

    /// The worktree's directory or its entry in git is gone — an agent removed it while it was
    /// being read, which is ordinary rather than exceptional.
    case worktreeGone

    case fileGone

    /// The file changed since the reader marked it viewed, so the mark would be over a version
    /// nobody saw.
    case staleContentHash

    /// Carries git's own standard error, because nothing else makes a git failure diagnosable from
    /// a phone three rooms away.
    case gitFailure

    case tooLarge
    case badRequest

    /// The client speaks a newer version of this API than the Mac serves.
    case unsupportedApiVersion

    var status: HTTPResponse.Status {
        switch self {
        case .unauthorized, .pairingExpired: .unauthorized
        case .rateLimited: .tooManyRequests
        case .projectNotVisible: .forbidden
        case .worktreeGone, .fileGone: .gone
        case .staleContentHash: .conflict
        case .gitFailure: .internalServerError
        case .tooLarge: .contentTooLarge
        case .badRequest: .badRequest
        case .unsupportedApiVersion: .upgradeRequired
        }
    }
}

/// Every failure this API reports, in one shape.
///
/// Conforms to the framework's error protocol rather than merely being encodable, because an error
/// the framework does not recognise becomes an empty 500 — the one response that tells a reader
/// three rooms away precisely nothing.
public struct ApiError: Error, HTTPResponseError, Hashable, Sendable {

    public struct Body: ResponseEncodable, Hashable, Sendable {
        public let code: ApiErrorCode
        public let message: String
    }

    public let error: Body

    public init(_ code: ApiErrorCode, message: String) {
        error = Body(code: code, message: message)
    }

    public var status: HTTPResponse.Status { error.code.status }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        // The envelope, not the body: the contract is `{"error": {"code", "message"}}`, and
        // encoding the body alone produces the right words under no key at all.
        var response = try Envelope(error: error).response(from: request, context: context)
        response.status = status
        return response
    }

    private struct Envelope: ResponseEncodable, Hashable, Sendable {
        let error: Body
    }
}
