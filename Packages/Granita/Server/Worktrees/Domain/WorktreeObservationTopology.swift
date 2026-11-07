import Foundation

import CoreDiffDomain
import ServerGitDomain

public enum WorktreeObservationEvent: Hashable, Sendable {
    case changed([RepositoryLocation])
    case rescanRequired
}

public enum WorktreeObservationReaction: Hashable, Sendable {
    case refresh(Set<WorktreeID>)
    case reconcile
    case ignore
}

public struct WorktreeObservationTarget: Hashable, Sendable {
    public let location: RepositoryLocation
    public let gitDirectory: RepositoryLocation
    public let commonGitDirectory: RepositoryLocation

    public init(
        location: RepositoryLocation,
        gitDirectory: RepositoryLocation,
        commonGitDirectory: RepositoryLocation
    ) {
        self.location = location
        self.gitDirectory = gitDirectory
        self.commonGitDirectory = commonGitDirectory
    }
}

public struct WorktreeObservationTopology: Sendable {
    public let targets: [WorktreeObservationTarget]

    public init(targets: [WorktreeObservationTarget]) {
        self.targets = targets
    }

    public func reaction(to event: WorktreeObservationEvent) -> WorktreeObservationReaction {
        switch event {
        case .rescanRequired:
            return .reconcile
        case .changed(let locations):
            var affected: Set<WorktreeID> = []
            for location in locations {
                if targets.contains(where: {
                    location == $0.location || location == $0.gitDirectory || location == $0.commonGitDirectory
                        || location.path == $0.location.path + "/.git"
                }) {
                    return .reconcile
                }
                var shared: Set<WorktreeID> = []
                for target in targets {
                    let root = target.commonGitDirectory.path + "/"
                    guard location.path.hasPrefix(root) else { continue }
                    let relative = String(location.path.dropFirst(root.count))
                    if relative == "worktrees" || relative.hasPrefix("worktrees/") {
                        let belongsToKnownGitDirectory = targets.contains {
                            $0.gitDirectory != $0.commonGitDirectory && location.path.hasPrefix($0.gitDirectory.path + "/")
                        }
                        if belongsToKnownGitDirectory == false { return .reconcile }
                    }
                    if relative.hasPrefix("refs/") || ["packed-refs", "config", "info/exclude"].contains(relative) {
                        shared.formUnion(targets.filter {
                            $0.commonGitDirectory == target.commonGitDirectory
                        }.map { WorktreeID(canonicalPath: $0.location.path) })
                    }
                }
                if shared.isEmpty == false {
                    affected.formUnion(shared)
                    continue
                }
                let gitTarget = targets.filter {
                    location.path == $0.gitDirectory.path || location.path.hasPrefix($0.gitDirectory.path + "/")
                }.max { $0.gitDirectory.path.count < $1.gitDirectory.path.count }
                if let gitTarget {
                    let relative = String(location.path.dropFirst(gitTarget.gitDirectory.path.count + 1))
                    if relative == "commondir" || relative == "gitdir" { return .reconcile }
                    if ["HEAD", "index", "MERGE_HEAD", "REBASE_HEAD", "ORIG_HEAD", "config.worktree", "locked"].contains(relative) {
                        affected.insert(WorktreeID(canonicalPath: gitTarget.location.path))
                    }
                    continue
                }
                // A linked checkout can sit below another checkout. Its file belongs to the
                // longest matching root, rather than to every ancestor that happens to contain it.
                let target = targets.filter {
                    location.path == $0.location.path || location.path.hasPrefix($0.location.path + "/")
                }.max { $0.location.path.count < $1.location.path.count }
                if let target {
                    let relative = location.path.dropFirst(target.location.path.count + 1)
                    let ignored: Set<Substring> = ["node_modules", ".build", "DerivedData", "Pods", "target", "dist"]
                    if relative.split(separator: "/").contains(where: ignored.contains) { continue }
                    affected.insert(WorktreeID(canonicalPath: target.location.path))
                }
            }
            return affected.isEmpty ? .ignore : .refresh(affected)
        }
    }
}
