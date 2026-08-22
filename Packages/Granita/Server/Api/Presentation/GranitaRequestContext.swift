import Foundation
import Hummingbird
import NIOCore

/// The per-request context, carrying the one thing the framework's own does not: where the request
/// came from.
///
/// **The `Host` header is not a source address.** It is what the client dialled, so every client
/// sends the same one — this Mac's name — and a rate limit counted against it is a global limit
/// that one misconfigured phone can use to lock out every other device. A connection log built from
/// it says where the request went rather than where it came from, which is the one fact that panel
/// exists to report.
public struct GranitaRequestContext: RequestContext, RemoteAddressRequestContext {

    public var coreContext: CoreRequestContextStorage

    public let remoteAddress: SocketAddress?

    public init(source: ApplicationRequestContextSource) {
        coreContext = .init(source: source)
        remoteAddress = source.channel.remoteAddress
    }

    /// Timestamps on the wire are ISO 8601, said here rather than inherited.
    ///
    /// The framework's default happens to be the same today, and that is exactly the problem: the
    /// phone decodes with a strategy it has to choose deliberately, so leaving this end to a default
    /// makes a dependency upgrade a phone that reads every worktree as modified in 1970. Stated on
    /// both sides, a change to either is a change somebody wrote.
    public var responseEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public var requestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// How a source is named in the connection log and counted against a rate limit.
    ///
    /// The address without its port, so that a phone retrying is one source rather than a new one
    /// on every connection — which is what a port would make it, and what would leave the limit
    /// counting to five forever.
    public var source: String {
        remoteAddress?.ipAddress ?? "unknown"
    }
}
