import Foundation

import ServerGitDomain
import ServerMacDomain
import ServerWorktreesDomain

/// What the Projects tab can find on this Mac's own disk.
///
/// Two prices, kept apart, and that separation is the whole design of this type. Reading what is
/// behind a project is one git invocation; counting what has *changed* behind it is one per
/// worktree, measured at roughly a second each on a large repository. The tab draws with the first
/// and fills in the second.
public struct FileSystemProjectFolders: ProjectFolders {

    private let service: WorktreeService

    public init(service: WorktreeService) {
        self.service = service
    }

    public func contents(ofFolderAt path: String) async -> ProjectContents {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .folderNotFound
        }
        guard let records = try? await service.worktrees(in: RepositoryLocation(path: path)) else {
            return .notARepository
        }
        return .worktrees(count: records.count)
    }

    public func worktreesWithChanges(inFolderAt path: String) async -> Int {
        let location = RepositoryLocation(path: path)
        guard let records = try? await service.worktrees(in: location) else { return 0 }

        var dirty = 0
        for record in records {
            // One worktree refusing is ordinary — a directory deleted without git being told is the
            // usual way — and it must not take the figure for the whole project down with it. A
            // project reported as having no changes because one of its worktrees is broken is a
            // smaller lie than a project reported as having none at all.
            if (try? await service.hasChanges(in: record.location)) == true { dirty += 1 }
        }
        return dirty
    }

    public func repositories(under root: URL) async -> [RepositoryCandidate] {
        var found: [RepositoryCandidate] = []
        collect(into: &found, at: root, relativePath: "", depth: 0)
        // Sorted by the name a reader is reading, which is what the sheet lists them under and what
        // makes two scans of one folder offer the same list in the same order. Depth-first order is
        // the walk's business and means nothing to the person choosing.
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - The walk

    /// Written out rather than handed to `FileManager.enumerator`, because the two rules that matter
    /// are both about **not** descending — stop at a repository, refuse the specification's list —
    /// and an enumerator expresses those by asking it to skip children it has already produced.
    ///
    /// `relativePath` is carried down rather than derived from the two paths afterwards. On this
    /// platform a folder under `/var` is reached through a symbolic link and comes back spelled
    /// `/private/var`, so the root is not a prefix of its own children and subtracting one from the
    /// other yields an absolute path — which is the one thing this tab must never show as a
    /// relative one.
    private func collect(
        into found: inout [RepositoryCandidate],
        at url: URL,
        relativePath: String,
        depth: Int
    ) {
        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
                options: []
            )
        } catch {
            // A folder that cannot be read is a folder with nothing to offer, and there is nobody to
            // tell: a scan reports what it found. The alternative is a sheet that refuses outright
            // because one directory somewhere under a home folder was not readable.
            return
        }

        for child in children {
            let name = child.lastPathComponent
            guard RepositoryScan.descends(into: name) else { continue }

            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
            // A symbolic link is somewhere else's directory reached by a second name. Following one
            // offers the same repository twice under two paths, and a link back up the tree is a
            // walk that does not end.
            guard values?.isDirectory == true,
                  values?.isSymbolicLink != true,
                  values?.isPackage != true else { continue }

            let childRelativePath = relativePath.isEmpty ? name : relativePath + "/" + name
            if isRepositoryRoot(child) {
                found.append(RepositoryCandidate(
                    path: canonicalPath(of: child),
                    name: name,
                    relativePath: childRelativePath
                ))
                // Not descended into, which is the rule git itself follows: what is inside a
                // checkout belongs to that checkout, and a vendored copy or a submodule is not a
                // project anybody filed.
                continue
            }
            guard depth + 1 < RepositoryScan.maximumDepth else { continue }
            collect(into: &found, at: child, relativePath: childRelativePath, depth: depth + 1)
        }
    }

    /// A `.git` **directory**, and not a `.git` file.
    ///
    /// The difference is a linked worktree, whose `.git` is a file pointing back at the repository
    /// it belongs to. Offering one as a project would enumerate exactly the worktrees the repository
    /// already offers, under a second name, with a second switch.
    private func isRepositoryRoot(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.appending(path: ".git").path(percentEncoded: false),
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    /// No trailing separator, because a project's identifier is a hash of this string: the same
    /// folder spelled with and without one is two projects that cannot both be switched on.
    private func canonicalPath(of url: URL) -> String {
        var path = url.standardizedFileURL.path(percentEncoded: false)
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
