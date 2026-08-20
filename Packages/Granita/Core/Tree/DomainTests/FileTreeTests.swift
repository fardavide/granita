import Testing

import CoreDiffDomain
@testable import CoreTreeDomain

@Suite("File tree")
struct FileTreeTests {

    @Test
    func `given no changed files when building the tree then it has no rows`() {
        // given - when
        let tree = FileTree.build(from: [])

        // then
        #expect(tree.isEmpty)
    }

    @Test
    func `given files at the repository root when building the tree then each is a row of its own`() {
        // given
        let readme = entry("README.md")
        let makefile = entry("Makefile")

        // when
        let tree = FileTree.build(from: [readme, makefile])

        // then
        #expect(tree == [.file(makefile), .file(readme)])
    }

    @Test
    func `given two files in one directory when building the tree then they share a directory row`() {
        // given
        let parser = entry("Sources/Parser.swift")
        let lexer = entry("Sources/Lexer.swift")

        // when
        let tree = FileTree.build(from: [parser, lexer])

        // then
        #expect(tree == [
            .directory(FileTreeDirectory(
                name: "Sources",
                path: "Sources",
                children: [.file(lexer), .file(parser)]
            ))
        ])
    }

    // MARK: - Compaction

    @Test
    func `given a chain of single-child directories when building the tree then it is one row`() {
        // given
        let main = entry("app/src/main/kotlin/com/example/Main.kt")

        // when
        let tree = FileTree.build(from: [main])

        // then — the row reads as the whole chain, and is identified by its deepest directory, so
        // collapsing it collapses the one thing the reader sees.
        #expect(tree == [
            .directory(FileTreeDirectory(
                name: "app/src/main/kotlin/com/example",
                path: "app/src/main/kotlin/com/example",
                children: [.file(main)]
            ))
        ])
    }

    @Test
    func `given a directory holding one file when building the tree then the file keeps its own row`() {
        // given — the chain is a chain of directories. A file is content the row contains, so
        // folding it in would leave nowhere to render its status, stats and viewed checkbox.
        let script = entry("Scripts/release.sh")

        // when
        let tree = FileTree.build(from: [script])

        // then
        #expect(tree == [
            .directory(FileTreeDirectory(name: "Scripts", path: "Scripts", children: [.file(script)]))
        ])
    }

    @Test
    func `given a chain that branches when building the tree then compaction stops at the branch`() {
        // given
        let deep = entry("Packages/Granita/Core/Tree.swift")
        let shallow = entry("Packages/Granita/Package.swift")

        // when
        let tree = FileTree.build(from: [deep, shallow])

        // then — `Packages/Granita` folds because it is a single-child chain; `Core` does not,
        // because `Granita` holds a second row beside it.
        #expect(tree == [
            .directory(FileTreeDirectory(
                name: "Packages/Granita",
                path: "Packages/Granita",
                children: [
                    .directory(FileTreeDirectory(
                        name: "Core",
                        path: "Packages/Granita/Core",
                        children: [.file(deep)]
                    )),
                    .file(shallow)
                ]
            ))
        ])
    }

    // MARK: - Ordering

    @Test
    func `given a mixture of files and directories when building the tree then directories come first`() {
        // given — git orders these by whole-path bytes, which puts `Makefile` between the two
        // directories. A project view does not.
        let entries = [entry("Makefile"), entry("Sources/App.swift"), entry("Apps/Shell.swift")]

        // when
        let tree = FileTree.build(from: entries)

        // then
        #expect(tree.map(\.rowText) == ["Apps", "Sources", "Makefile"])
    }

    @Test
    func `given names differing only in case when building the tree then they order case-insensitively`() {
        // given
        let entries = [entry("zebra.txt"), entry("Apple.txt"), entry("banana.txt")]

        // when
        let tree = FileTree.build(from: entries)

        // then — a case-sensitive comparison would sort every capitalised name above every
        // lowercase one, which is not where a reader looks for it.
        #expect(tree.map(\.rowText) == ["Apple.txt", "banana.txt", "zebra.txt"])
    }

    @Test
    func `given the same files in a different order when building the tree then the tree is the same`() {
        // given
        let entries = [entry("b/two.txt"), entry("a/one.txt"), entry("c.txt")]

        // when
        let tree = FileTree.build(from: entries)

        // then — the order files arrive in is the order of the diff, and the tree does not inherit
        // it: two devices showing one worktree must show it identically.
        #expect(tree == FileTree.build(from: entries.reversed()))
        #expect(tree.map(\.rowText) == ["a", "b", "c.txt"])
    }
}

/// The tree is addressed by identifier, so every entry derives one the way the git layer will.
private func entry(_ path: String) -> FileTreeEntry {
    FileTreeEntry(id: FileID(repositoryRelativePath: path), path: path)
}

private extension FileTreeNode {

    /// What the row reads, whichever kind it is — the ordering rules span both.
    var rowText: String {
        switch self {
        case .directory(let directory): directory.name
        case .file(let file): file.name
        }
    }
}
