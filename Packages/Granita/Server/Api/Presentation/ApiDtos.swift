import Foundation
import Hummingbird

import CoreDiffDomain

/// What `/changes` answers with.
public struct ChangesResponse: ResponseEncodable, Hashable, Sendable {

    public let revision: String
    public let stats: ChangeStats
    public let files: [FileChange]

    /// Whether more files changed than this worktree serves at once.
    public let isTruncated: Bool
}

/// What `/lines` answers with.
public struct LinesResponse: ResponseEncodable, Hashable, Sendable {
    public let lines: [String]
    public let eof: Bool
}

/// What `/pair` is asked.
public struct PairRequest: Decodable, Hashable, Sendable {
    public let code: String
    public let deviceName: String
    public let platform: String
}

/// What `/pair` answers with.
///
/// The token is returned exactly once and stored hashed on this side, so a store that leaks leaks
/// nothing usable.
public struct PairResponse: ResponseEncodable, Hashable, Sendable {
    public let token: String
    public let deviceId: String
    public let serverInstanceId: String
}

/// What `/viewed` is told.
public struct ViewedRequest: Decodable, Hashable, Sendable {
    public let viewed: Bool

    /// The content the reader actually saw. A mark against anything else is refused rather than
    /// applied, so a file that changed while it was open cannot be marked read.
    public let contentHash: String
}

/// A partial update of a worktree.
///
/// `Codable` decodes a missing key and an explicit `null` to the same `nil`, so a plain struct
/// cannot tell "clear the alias" from "leave the alias alone" — and both are things the phone
/// asks for. Presence and nullity are read separately here, which is the only way to tell them
/// apart.
public struct WorktreePatch: Decodable, Hashable, Sendable {

    /// What the request said about the alias.
    public enum AliasChange: Hashable, Sendable {
        case unchanged
        case cleared
        case set(String)
    }

    public let alias: AliasChange

    /// Absent means unchanged; there is no third state for a boolean.
    public let isPinned: Bool?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.alias) == false {
            alias = .unchanged
        } else if try container.decodeNil(forKey: .alias) {
            alias = .cleared
        } else {
            alias = .set(try container.decode(String.self, forKey: .alias))
        }
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned)
    }

    private enum CodingKeys: String, CodingKey {
        case alias
        case isPinned
    }
}

// The domain models are the wire contract, so they are what the routes return. Conformance is
// added here rather than in the domain because `ResponseEncodable` is Hummingbird's, and a Domain
// module that imported a web framework would be the first crack in the rule that keeps it testable
// without one.
extension Project: ResponseEncodable {}
extension Worktree: ResponseEncodable {}
extension FileDiff: ResponseEncodable {}
