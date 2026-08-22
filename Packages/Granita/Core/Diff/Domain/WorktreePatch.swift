/// A partial update of a worktree — the body of the one route that writes.
///
/// `Codable` decodes a missing key and an explicit `null` to the same `nil`, so a plain struct
/// cannot tell "clear the alias" from "leave the alias alone" — and both are things the phone asks
/// for. Presence and nullity are read separately here, which is the only way to tell them apart.
///
/// One type writes this and reads it, deliberately. The trap above is easy to get right on one side
/// and wrong on the other, and a phone whose encoder omitted the key where the Mac expected a null
/// would silently keep an alias the reader had just deleted.
public struct WorktreePatch: Codable, Hashable, Sendable {

    /// What the request says about the alias, and the reason this type is hand-coded.
    public enum AliasChange: Hashable, Sendable {
        case unchanged
        case cleared
        case set(String)
    }

    public let alias: AliasChange

    /// Absent means unchanged; there is no third state for a boolean.
    public let isPinned: Bool?

    public init(alias: AliasChange, isPinned: Bool?) {
        self.alias = alias
        self.isPinned = isPinned
    }

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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch alias {
        case .unchanged: break
        case .cleared: try container.encodeNil(forKey: .alias)
        case .set(let alias): try container.encode(alias, forKey: .alias)
        }
        try container.encodeIfPresent(isPinned, forKey: .isPinned)
    }

    private enum CodingKeys: String, CodingKey {
        case alias
        case isPinned
    }
}
