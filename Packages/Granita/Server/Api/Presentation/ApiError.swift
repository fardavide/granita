import Foundation
import Hummingbird

import CoreApiDomain

extension ApiErrorCode {

    /// How each code travels. The status is the Mac's business — the phone branches on the code, and
    /// a screen that switched on a number would have to know the difference between two refusals
    /// this API deliberately spells the same way.
    var status: HTTPResponse.Status {
        switch self {
        case .unauthorized, .pairingExpired: .unauthorized
        case .rateLimited: .tooManyRequests
        case .projectNotVisible: .forbidden
        case .worktreeGone, .fileGone: .gone
        // The request was understood and the worktree is there; its state is what refuses.
        case .staleContentHash, .worktreeNotDeletable: .conflict
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
