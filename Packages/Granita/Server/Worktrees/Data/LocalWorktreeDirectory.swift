import Foundation

import ServerGitDomain
import ServerWorktreesDomain

/// The filesystem's own answers, which is the only implementation there will be.
public struct LocalWorktreeDirectory: WorktreeDirectoryReading {

    public init() {}

    public func exists(at location: RepositoryLocation) -> Bool {
        FileManager.default.fileExists(atPath: location.path)
    }

    public func lastModified(at location: RepositoryLocation) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: location.path)
        return attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
    }
}
