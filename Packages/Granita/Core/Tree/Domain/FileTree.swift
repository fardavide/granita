import Foundation

/// Arranges a worktree's changed files into the tree the file selector renders.
public enum FileTree {

    public static func build(from entries: [FileTreeEntry]) -> [FileTreeNode] {
        rows(of: entries.map(PlacedFile.init), depth: 0, under: "")
    }
}

/// A file alongside its split path, so the recursion below indexes components instead of splitting
/// the same path once per level.
private struct PlacedFile {

    let entry: FileTreeEntry
    let components: [Substring]

    init(_ entry: FileTreeEntry) {
        self.entry = entry
        components = entry.path.split(separator: "/")
    }
}

/// The rows one level of the tree contributes: a file row for every entry that ends here, and a
/// directory row for every distinct component the deeper ones share.
private func rows(of placed: [PlacedFile], depth: Int, under prefix: String) -> [FileTreeNode] {
    let files = placed
        .filter { $0.components.count == depth + 1 }
        .map { FileTreeNode.file($0.entry) }
    let directories = Dictionary(grouping: placed.filter { $0.components.count > depth + 1 }) {
        String($0.components[depth])
    }
    return (directories.map { name, members in
        let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
        return FileTreeNode.directory(compacted(FileTreeDirectory(
            name: name,
            path: path,
            children: rows(of: members, depth: depth + 1, under: path)
        )))
    } + files).sorted(by: precedes)
}

/// Folds a directory whose only child is another directory into the single row the spec asks for,
/// so `app/src/main/kotlin/com/example` reads as one row rather than five.
///
/// One fold is enough however long the chain: the children were built first and are therefore
/// already compacted, so absorbing the only one absorbs everything below it. A directory whose only
/// child is a **file** is left alone — the chain is a chain of directories, and the file is content
/// the row contains rather than another step of the path.
private func compacted(_ directory: FileTreeDirectory) -> FileTreeDirectory {
    guard directory.children.count == 1, case .directory(let only) = directory.children[0] else {
        return directory
    }
    return FileTreeDirectory(
        name: "\(directory.name)/\(only.name)",
        path: only.path,
        children: only.children
    )
}

/// Directories above files, then alphabetically — the arrangement a project view uses, rather than
/// git's own byte order over whole paths, which interleaves the two.
///
/// The comparison is case-insensitive so that `README.md` sits where a reader looks for it, and
/// falls back to the raw names so that two spellings of one word still order deterministically.
/// Nothing here is locale-sensitive: two devices showing the same worktree must show it identically.
private func precedes(_ one: FileTreeNode, _ other: FileTreeNode) -> Bool {
    switch (one, other) {
    case (.directory, .file): true
    case (.file, .directory): false
    case (.directory(let lhs), .directory(let rhs)): orders(lhs.name, before: rhs.name)
    case (.file(let lhs), .file(let rhs)): orders(lhs.name, before: rhs.name)
    }
}

private func orders(_ one: String, before other: String) -> Bool {
    let folded = (one.lowercased(), other.lowercased())
    return folded.0 == folded.1 ? one < other : folded.0 < folded.1
}
