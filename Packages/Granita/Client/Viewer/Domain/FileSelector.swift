import CoreDiffDomain
import CoreTreeDomain

/// Design §3's rules, as one pure function over a change set.
///
/// It lives here rather than on the model for the reason `ContinuousDiffLoading` does: every rule in
/// §3 is arithmetic whose only symptom, when it is wrong, is a number on a row somebody misreads —
/// a total that double-counts, a check mark that says a subtree is finished when one file in it is
/// not. A policy buried in a model is a policy nobody tests directly.
///
/// **The structure comes from `CoreTreeDomain` and is not re-derived here.** `FileTree` already
/// compacts single-child chains, puts directories above files and orders both deterministically;
/// what this adds is the join with each file's own state, the collapse rules, and the two cases
/// where a tree is ceremony.
public enum FileSelector {

    /// The rows to draw, and what the list says about itself.
    ///
    /// `mode` is what the reader asked for and not necessarily what comes back: over three files or
    /// fewer, and over a change set that is all one directory, the answer is flat whatever was
    /// asked, and the toggle is absent rather than disabled.
    public static func listing(
        of files: [FileChange],
        mode: FileSelectorMode,
        collapsed: Set<String>,
        isTruncated: Bool
    ) -> FileSelectorListing {
        let tree = FileTree.build(from: files.map { FileTreeEntry(id: $0.id, path: $0.path) })
        let state = Dictionary(files.map { ($0.id, $0) }) { first, _ in first }
        let worthATree = hasStructureWorthATree(tree, fileCount: files.count)
        let resolved: FileSelectorMode = worthATree ? mode : .flat

        return FileSelectorListing(
            mode: resolved,
            rows: resolved == .tree
                ? rows(of: tree, joining: state, collapsed: collapsed, depth: 0)
                : flatRows(of: tree, joining: state),
            offersModeToggle: worthATree,
            footer: footer(of: files, isTruncated: isTruncated)
        )
    }

    /// Which directories are shut the first time a worktree is opened.
    ///
    /// Design §3: above roughly twenty children a directory arrives collapsed, which is what makes
    /// the eighty-directory change set readable. Twenty itself stays open — the boundary is stated
    /// here rather than left to a comparison in a view.
    public static func initiallyCollapsed(in files: [FileChange]) -> Set<String> {
        var shut: Set<String> = []
        collect(
            &shut,
            in: FileTree.build(from: files.map { FileTreeEntry(id: $0.id, path: $0.path) })
        )
        return shut
    }
}

// MARK: -

/// Fewer than this and the tree is two rows of ceremony for one row of content.
private let minimumFilesForATree = 3

/// The child count above which a directory arrives shut.
private let crowdedDirectory = 20

/// Whether a tree would say anything the flat list does not.
///
/// Design §3 names the two cases where it would not: three files or fewer, and a change set that is
/// all one directory — where the whole tree is one row above exactly the same list of files.
private func hasStructureWorthATree(_ tree: [FileTreeNode], fileCount: Int) -> Bool {
    guard fileCount > minimumFilesForATree else { return false }
    guard tree.count == 1, case .directory(let only) = tree[0] else { return true }
    // One root directory is still worth a tree when something under it branches — what is not worth
    // a tree is one directory holding nothing but files.
    return only.children.contains { child in
        switch child {
        case .directory: true
        case .file: false
        }
    }
}

private func collect(_ shut: inout Set<String>, in nodes: [FileTreeNode]) {
    for node in nodes {
        guard case .directory(let directory) = node else { continue }
        if directory.children.count > crowdedDirectory {
            shut.insert(directory.path)
        }
        collect(&shut, in: directory.children)
    }
}

private func rows(
    of nodes: [FileTreeNode],
    joining state: [FileID: FileChange],
    collapsed: Set<String>,
    depth: Int
) -> [FileSelectorRow] {
    nodes.flatMap { node -> [FileSelectorRow] in
        switch node {
        case .file(let entry):
            return fileRow(of: entry, joining: state, depth: depth).map { [$0] } ?? []
        case .directory(let directory):
            let isExpanded = collapsed.contains(directory.path) == false
            let beneath = files(under: directory, joining: state)
            let row = FileSelectorRow.directory(FileSelectorDirectory(
                path: directory.path,
                name: directory.name,
                depth: depth,
                isExpanded: isExpanded,
                // Only while it is shut. Open, its children carry their own numbers and the
                // parent's total is a figure the reader has to subtract.
                stats: isExpanded ? nil : beneath.reduce(ChangeStats.zero) { $0 + $1.stats },
                // Every *descendant*, not every child: a directory that calls itself finished while
                // one file two levels down is unread is the one lie this list can tell.
                isEntirelyViewed: beneath.isEmpty == false && beneath.allSatisfy(\.isViewed)
            ))
            guard isExpanded else { return [row] }
            return [row] + rows(
                of: directory.children,
                joining: state,
                collapsed: collapsed,
                depth: depth + 1
            )
        }
    }
}

/// The same files in the same order, without the directories.
///
/// Walking the tree rather than the change set is what makes flat "the same list, differently
/// labelled": git's own order interleaves directories and files, and a toggle that reshuffled the
/// list would lose the reader's place every time they pressed it.
private func flatRows(of nodes: [FileTreeNode], joining state: [FileID: FileChange]) -> [FileSelectorRow] {
    nodes.flatMap { node -> [FileSelectorRow] in
        switch node {
        case .file(let entry): fileRow(of: entry, joining: state, depth: 0).map { [$0] } ?? []
        case .directory(let directory): flatRows(of: directory.children, joining: state)
        }
    }
}

/// A file the tree named and the change set does not describe is dropped rather than drawn from
/// nothing, which cannot happen — both come from the same list — and which would otherwise be a row
/// claiming a status nobody reported.
private func fileRow(
    of entry: FileTreeEntry,
    joining state: [FileID: FileChange],
    depth: Int
) -> FileSelectorRow? {
    guard let change = state[entry.id] else { return nil }
    return .file(FileSelectorFile(
        id: entry.id,
        path: entry.path,
        directoryPrefix: String(entry.path.dropLast(entry.name.count)),
        name: entry.name,
        depth: depth,
        status: change.status,
        stats: change.stats,
        isViewed: change.isViewed
    ))
}

private func files(under directory: FileTreeDirectory, joining state: [FileID: FileChange]) -> [FileChange] {
    directory.children.flatMap { child -> [FileChange] in
        switch child {
        case .file(let entry): state[entry.id].map { [$0] } ?? []
        case .directory(let nested): files(under: nested, joining: state)
        }
    }
}

/// One slot, and truncation wins it.
///
/// Both can be true at once, and a reader told they have read everything when the Mac declined to
/// serve part of the change set has been told something that is not true of the worktree.
private func footer(of files: [FileChange], isTruncated: Bool) -> FileSelectorFooter? {
    if isTruncated {
        return .notAllServed(shown: files.count)
    }
    guard files.isEmpty == false, files.allSatisfy(\.isViewed) else { return nil }
    return .everythingViewed(count: files.count)
}
