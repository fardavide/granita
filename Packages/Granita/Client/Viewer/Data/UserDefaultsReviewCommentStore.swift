import Foundation

import ClientViewerDomain
import CoreDiffDomain

/// The review a reader has written, in this phone's user defaults.
///
/// Defaults rather than a file, for the reason the sidebar's arrangement is there: it is small, it
/// is this phone's own, and it wants to survive being backgrounded rather than being durable.
/// A review that is lost is a review the reader writes again; nothing here is the Mac's account of
/// anything. See `ReviewCommentStore` for why it is not on the Mac yet.
// `UserDefaults` is documented as thread-safe and carries no `Sendable` conformance, so the
// invariant the compiler cannot see is upheld by the class itself rather than by anything here.
public struct UserDefaultsReviewCommentStore: ReviewCommentStore, @unchecked Sendable {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Exposed because it is a storage contract rather than an implementation detail: a test
    /// asserting what happens to bytes no release ever wrote has to be able to write some.
    public static func key(for worktree: WorktreeID) -> String {
        "granita.viewer.comments.\(worktree.rawValue)"
    }

    /// Bytes that do not decode answer with no comments rather than refusing to answer.
    ///
    /// They can only come from a defaults file edited by hand or from a release that spelled a
    /// comment differently, and in both cases what a reader needs is a screen that opens. A review
    /// they have to write again is a worse afternoon than one that never existed; a viewer that
    /// cannot draw a diff is not a viewer.
    public func comments(in worktree: WorktreeID) -> [ReviewComment] {
        guard let stored = defaults.data(forKey: Self.key(for: worktree)),
              let decoded = try? JSONDecoder().decode([ReviewComment].self, from: stored) else {
            return []
        }
        return decoded
    }

    public func save(_ comments: [ReviewComment], in worktree: WorktreeID) {
        // `JSONEncoder` throws only for a value it cannot represent, and every field reachable here
        // is a string, an integer or an array of them. So the branch is unreachable rather than
        // unhandled, and what it does is leave the stored review as it was — inventing a refusal for
        // a failure that cannot happen would put a sentence on screen nobody could ever act on.
        guard let encoded = try? JSONEncoder().encode(comments) else { return }
        defaults.set(encoded, forKey: Self.key(for: worktree))
    }
}
