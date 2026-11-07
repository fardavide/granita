import Foundation

import ServerGitDomain
import ServerWorktreesDomain

struct FakeWorktreeFileReading: WorktreeFileReading {
    let answer: Result<Data, WorktreeFileError>

    func bytes(
        of path: RepositoryRelativePath,
        in worktree: RepositoryLocation,
        upTo maximumBytes: Int
    ) throws(WorktreeFileError) -> Data {
        try answer.get()
    }
}
