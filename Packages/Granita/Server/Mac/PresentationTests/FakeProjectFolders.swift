import Foundation

import ServerMacDomain

/// This Mac's disk, without a disk.
///
/// It records which folders were **counted** rather than which were read, because the assertion that
/// matters most on this tab is a negative one: the expensive question is asked of the projects whose
/// figure is drawn and of nothing else.
actor FakeProjectFolders: ProjectFolders {

    private(set) var counted: [String] = []

    private let contentsByPath: [String: ProjectContents]
    private let worktreesWithChangesByPath: [String: Int]
    private let candidates: [RepositoryCandidate]

    init(
        contents: [String: ProjectContents],
        worktreesWithChanges: [String: Int],
        candidates: [RepositoryCandidate]
    ) {
        contentsByPath = contents
        worktreesWithChangesByPath = worktreesWithChanges
        self.candidates = candidates
    }

    /// A path nothing was said about is a folder that is not there, which is the answer that makes a
    /// test forgetting to describe one fail rather than quietly read as an empty repository.
    func contents(ofFolderAt path: String) -> ProjectContents {
        contentsByPath[path] ?? .folderNotFound
    }

    func worktreesWithChanges(inFolderAt path: String) -> Int {
        counted.append(path)
        return worktreesWithChangesByPath[path] ?? 0
    }

    func repositories(under root: URL) -> [RepositoryCandidate] {
        candidates
    }
}
