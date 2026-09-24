import Foundation

import ServerGitDomain

/// The two facts about a checkout's directory that git does not answer.
///
/// **It exists so the registry can be `Domain`, and that is worth stating plainly.** The registry
/// composes the store and the git service into the worktrees a reader sees, which is logic with no
/// framework in it — but it also asks the filesystem whether a directory is still there and when it
/// was last touched, and two `FileManager` calls were enough to hold the whole type in a layer that
/// may not be imported by both the routes that serve a phone and the repository that reads this Mac
/// directly. Behind this protocol it may be imported by both.
///
/// Both answers are stats rather than reads, so both are synchronous: `resolve(_:)` asks the first
/// one once per candidate while walking every enabled project, and a suspension point per candidate
/// would buy nothing.
public protocol WorktreeDirectoryReading: Sendable {

    /// Whether the directory is still on disk.
    ///
    /// An agent removing a checkout between the enumeration and the read is the ordinary way this
    /// answers `false`, not the exceptional one — `git worktree list` keeps naming a directory that
    /// has been deleted until somebody prunes it.
    func exists(at location: RepositoryLocation) -> Bool

    /// When the directory itself was last written to.
    ///
    /// The distant past when it cannot be read, because this sorts a list rather than deciding
    /// anything: a row that cannot say when it changed belongs at the bottom, not absent.
    func lastModified(at location: RepositoryLocation) -> Date
}
