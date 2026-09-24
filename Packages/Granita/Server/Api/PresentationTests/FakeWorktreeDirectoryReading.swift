import Foundation

import ServerGitDomain
import ServerWorktreesDomain

/// The filesystem, answering whatever a test needs it to.
struct FakeWorktreeDirectoryReading: WorktreeDirectoryReading {

    private let directoriesExist: Bool
    private let modified: Date

    init(directoriesExist: Bool = true, modified: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.directoriesExist = directoriesExist
        self.modified = modified
    }

    func exists(at location: RepositoryLocation) -> Bool {
        directoriesExist
    }

    func lastModified(at location: RepositoryLocation) -> Date {
        modified
    }
}
