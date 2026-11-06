import Foundation

import ServerGitDomain
import ServerWorktreesDomain

struct FakeWorktreeDirectoryReading: WorktreeDirectoryReading {

    private let missingLocations: Set<RepositoryLocation>

    init(missingLocations: Set<RepositoryLocation> = []) {
        self.missingLocations = missingLocations
    }

    func exists(at location: RepositoryLocation) -> Bool {
        !missingLocations.contains(location)
    }

    func lastModified(at location: RepositoryLocation) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}
