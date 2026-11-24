import Foundation

import ServerGitDomain

public struct WorktreeRegistrationName: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) throws(WorktreePruneError) {
        let disallowed = CharacterSet.controlCharacters.union(.newlines)
        guard !rawValue.isEmpty, rawValue != ".", rawValue != "..", !rawValue.contains("/"),
              rawValue.rangeOfCharacter(from: disallowed) == nil,
              !rawValue.unicodeScalars.contains("\u{fffd}") else {
            throw .unavailable
        }
        self.rawValue = rawValue
    }

    public static func == (left: Self, right: Self) -> Bool {
        left.rawValue.utf8.elementsEqual(right.rawValue.utf8)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(Data(rawValue.utf8))
    }
}

public protocol WorktreeRegistrationBackingUp: Sendable {
    /// Moves just these registration directories to a recoverable backup within the common Git directory.
    func backUp(
        _ registrations: [WorktreeRegistrationName],
        in commonGitDirectory: RepositoryLocation
    ) throws(WorktreePruneError)
}
