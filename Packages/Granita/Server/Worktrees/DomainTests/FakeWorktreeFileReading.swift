import Foundation

import ServerGitDomain
import ServerWorktreesDomain

/// Hands back the bytes it was given for a path, and refuses everything else the way the disk does.
///
/// An actor because it records what it was asked for: which path a side was read from is the
/// assertion that matters for a rename, where the two sides live at two different ones.
actor FakeWorktreeFileReading: WorktreeFileReading {

    private let contents: [String: Data]
    private let failure: WorktreeFileError?

    private(set) var received: [RepositoryRelativePath] = []
    private(set) var ceilings: [Int] = []

    init(contents: [String: Data] = [:], failing failure: WorktreeFileError? = nil) {
        self.contents = contents
        self.failure = failure
    }

    func bytes(
        of path: RepositoryRelativePath,
        in worktree: RepositoryLocation,
        upTo maximumBytes: Int
    ) async throws(WorktreeFileError) -> Data {
        received.append(path)
        ceilings.append(maximumBytes)
        if let failure {
            throw failure
        }
        guard let content = contents[path.text] else {
            throw .unreadable(reason: "no such file")
        }
        guard content.count <= maximumBytes else { throw .tooLarge }
        return content
    }
}
