import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Design §3's rules, as a pure function over a change set.
///
/// They are asserted here rather than through the list that draws them because every one of them is
/// arithmetic a photograph cannot check: a summed total on a shut directory, a check mark that means
/// *this whole subtree is done*, and the two cases where a tree over a handful of files is ceremony
/// rather than structure.
@Suite("File selector")
struct FileSelectorTests {

    // MARK: - The tree

    @Test
    func `given files under directories when listing as a tree then directories lead and carry their depth`() {
        // given
        let files = [
            aChangedFile(path: "Package.swift"),
            aChangedFile(path: "Sources/Client/Viewer.swift"),
            aChangedFile(path: "Sources/Client/Gutter.swift"),
            aChangedFile(path: "Sources/Client/Model.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then — `Sources/Client` is one row rather than two, because a single-child chain compacts.
        #expect(listing.rows.map(\.id) == [
            .directory("Sources/Client"),
            .file(FileID(repositoryRelativePath: "Sources/Client/Gutter.swift")),
            .file(FileID(repositoryRelativePath: "Sources/Client/Model.swift")),
            .file(FileID(repositoryRelativePath: "Sources/Client/Viewer.swift")),
            .file(FileID(repositoryRelativePath: "Package.swift"))
        ])
        #expect(listing.rows.map(\.depth) == [0, 1, 1, 1, 0])
    }

    @Test
    func `given a shut directory when listing as a tree then its children are gone and it carries their total`() {
        // given — the summed figure is the whole reason a shut row is readable: without it a reader
        // has to open a directory to find out whether it is worth opening.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", insertions: 12, deletions: 4),
            aChangedFile(path: "Sources/Client/Gutter.swift", insertions: 30, deletions: 1),
            aChangedFile(path: "Package.swift", insertions: 2, deletions: 0),
            aChangedFile(path: "Tests/ViewerTests.swift", insertions: 7, deletions: 0)
        ]

        // when
        let listing = FileSelector.listing(
            of: files,
            mode: .tree,
            collapsed: ["Sources/Client"],
            isTruncated: false
        )

        // then
        #expect(listing.rows.map(\.id) == [
            .directory("Sources/Client"),
            .directory("Tests"),
            .file(FileID(repositoryRelativePath: "Tests/ViewerTests.swift")),
            .file(FileID(repositoryRelativePath: "Package.swift"))
        ])
        #expect(listing.rows.first?.directory?.stats == ChangeStats(filesChanged: 2, insertions: 42, deletions: 5))
        #expect(listing.rows.first?.directory?.isExpanded == false)
    }

    @Test
    func `given an open directory when listing as a tree then it carries no total at all`() {
        // given — its children are right there with their own numbers, and the parent's total
        // becomes noise the reader has to mentally subtract.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", insertions: 12, deletions: 4),
            aChangedFile(path: "Sources/Client/Gutter.swift", insertions: 30, deletions: 1),
            aChangedFile(path: "Package.swift"),
            aChangedFile(path: "Tests/ViewerTests.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.rows.first?.directory?.stats == nil)
        #expect(listing.rows.first?.directory?.isExpanded == true)
    }

    @Test
    func `given every descendant viewed when listing as a tree then the directory says so at either state`() {
        // given — "this whole subtree is done" is the most useful thing the tree can tell a reader,
        // so unlike the total it survives the row being open.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", isViewed: true),
            aChangedFile(path: "Sources/Client/Gutter.swift", isViewed: true),
            aChangedFile(path: "Package.swift", isViewed: false),
            aChangedFile(path: "Tests/ViewerTests.swift", isViewed: false)
        ]

        // when
        let open = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)
        let shut = FileSelector.listing(
            of: files,
            mode: .tree,
            collapsed: ["Sources/Client"],
            isTruncated: false
        )

        // then
        #expect(open.rows.first?.directory?.isEntirelyViewed == true)
        #expect(shut.rows.first?.directory?.isEntirelyViewed == true)
    }

    @Test
    func `given one unread file deep in a subtree when listing as a tree then no directory above it is done`() {
        // given — the check has to mean every descendant rather than every child, or a reader closes
        // a directory believing they have finished it.
        let files = [
            aChangedFile(path: "Sources/Client/Ui/Viewer.swift", isViewed: true),
            aChangedFile(path: "Sources/Client/Ui/Gutter.swift", isViewed: false),
            aChangedFile(path: "Sources/Client/Model.swift", isViewed: true),
            aChangedFile(path: "Package.swift", isViewed: true)
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        let directories = listing.rows.compactMap(\.directory)
        #expect(directories.map(\.path) == ["Sources/Client", "Sources/Client/Ui"])
        #expect(directories.allSatisfy { $0.isEntirelyViewed == false })
    }

    @Test
    func `given a row deeper than four when it is indented then the indent stops`() {
        // given - when - then — 56pt of indent at the clamp, the disclosure triangle 22, and about
        // 284pt left for the name. Past the fourth level the tree would be spending the row's only
        // useful width on saying how deep it is.
        #expect(FileSelectorRow.indentLevel(atDepth: 0) == 0)
        #expect(FileSelectorRow.indentLevel(atDepth: 3) == 3)
        #expect(FileSelectorRow.indentLevel(atDepth: 4) == 4)
        #expect(FileSelectorRow.indentLevel(atDepth: 9) == 4)
    }

    // MARK: - Flat

    @Test
    func `given flat mode when a file is listed then the directories above it are a run of their own`() {
        // given — one row implementation, two labels: the prefix erodes under truncation and the
        // filename never does, which only works if the two are separate runs.
        let files = [aChangedFile(path: "Sources/Client/Viewer/Ui/Viewer.swift")]

        // when
        let listing = FileSelector.listing(of: files, mode: .flat, collapsed: [], isTruncated: false)

        // then
        #expect(listing.rows.first?.file?.directoryPrefix == "Sources/Client/Viewer/Ui/")
        #expect(listing.rows.first?.file?.name == "Viewer.swift")
        #expect(listing.rows.first?.depth == 0)
    }

    @Test
    func `given a file at the root when it is listed flat then it has no prefix rather than an empty one`() {
        // given — the one row where the two-tone label has only one tone.
        let files = [aChangedFile(path: "Package.swift"), aChangedFile(path: "a/b/Other.swift")]

        // when
        let listing = FileSelector.listing(of: files, mode: .flat, collapsed: [], isTruncated: false)

        // then
        #expect(listing.rows.compactMap(\.file?.directoryPrefix) == ["a/b/", ""])
    }

    @Test
    func `given flat mode when the files are listed then no directory row survives`() {
        // given
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift"),
            aChangedFile(path: "Sources/Client/Gutter.swift"),
            aChangedFile(path: "Package.swift"),
            aChangedFile(path: "Tests/ViewerTests.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .flat, collapsed: [], isTruncated: false)

        // then — and in the order the tree would have used, which is what stops the toggle
        // reshuffling a list the reader was reading.
        #expect(listing.rows.compactMap(\.directory).isEmpty)
        #expect(listing.rows.compactMap(\.file?.name) == [
            "Gutter.swift",
            "Viewer.swift",
            "ViewerTests.swift",
            "Package.swift"
        ])
    }

    // MARK: - When a tree is ceremony

    @Test
    func `given three files or fewer when listing then it is flat and the toggle is not offered`() {
        // given — a tree over three files is two rows of ceremony for one row of content.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift"),
            aChangedFile(path: "Sources/Server/Router.swift"),
            aChangedFile(path: "Package.swift")
        ]

        // when — asked for a tree, and the answer is still flat.
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.mode == .flat)
        #expect(listing.offersModeToggle == false)
        #expect(listing.rows.compactMap(\.directory).isEmpty)
    }

    @Test
    func `given every file in one directory when listing then it is flat and the toggle is not offered`() {
        // given — a single directory row above everything says nothing the rows do not already say.
        let files = (0..<8).map { aChangedFile(path: "Sources/Client/File\($0).swift") }

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.mode == .flat)
        #expect(listing.offersModeToggle == false)
    }

    @Test
    func `given files across two directories when listing then the toggle is offered`() {
        // given
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift"),
            aChangedFile(path: "Sources/Client/Gutter.swift"),
            aChangedFile(path: "Sources/Server/Router.swift"),
            aChangedFile(path: "Package.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.mode == .tree)
        #expect(listing.offersModeToggle)
    }

    // MARK: - What arrives shut

    @Test
    func `given a directory with more than twenty children when the selector opens then it arrives shut`() {
        // given — the rule that makes an eighty-directory change set readable at all.
        let files = (0..<21).map { aChangedFile(path: "Sources/Big/File\($0).swift") }
            + [aChangedFile(path: "Sources/Small/One.swift"), aChangedFile(path: "Package.swift")]

        // when
        let collapsed = FileSelector.initiallyCollapsed(in: files)

        // then
        #expect(collapsed == ["Sources/Big"])
    }

    @Test
    func `given a directory with twenty children when the selector opens then it arrives open`() {
        // given — the boundary, stated rather than left to a comparison nobody reads.
        let files = (0..<20).map { aChangedFile(path: "Sources/Big/File\($0).swift") }
            + [aChangedFile(path: "Package.swift")]

        // when
        let collapsed = FileSelector.initiallyCollapsed(in: files)

        // then
        #expect(collapsed.isEmpty)
    }

    // MARK: - The footer

    @Test
    func `given a change set the Mac could not serve whole when listing then the footer says so`() {
        // given — and it says "not served" rather than offering to load more, because the Mac's
        // limits will not serve them and a button that cannot succeed is worse than a sentence.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift"),
            aChangedFile(path: "Sources/Server/Router.swift"),
            aChangedFile(path: "Package.swift"),
            aChangedFile(path: "Tests/ViewerTests.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: true)

        // then
        #expect(listing.footer == .notAllServed(shown: 4))
    }

    @Test
    func `given every file viewed when listing then the footer counts them and the rows stay openable`() {
        // given — not an unavailable-content view: the files are still there and still worth
        // re-reading, and the reader's next move is to leave rather than to be congratulated.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", isViewed: true),
            aChangedFile(path: "Sources/Server/Router.swift", isViewed: true),
            aChangedFile(path: "Package.swift", isViewed: true),
            aChangedFile(path: "Tests/ViewerTests.swift", isViewed: true)
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.footer == .everythingViewed(count: 4))
        #expect(listing.rows.compactMap(\.file).count == 4)
    }

    @Test
    func `given a truncated change set that is entirely viewed when listing then truncation is what it says`() {
        // given — both footers apply and there is one slot. The incomplete list wins, because a
        // reader told they have read everything is told something that is not true of the worktree.
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", isViewed: true),
            aChangedFile(path: "Sources/Server/Router.swift", isViewed: true),
            aChangedFile(path: "Package.swift", isViewed: true),
            aChangedFile(path: "Tests/ViewerTests.swift", isViewed: true)
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: true)

        // then
        #expect(listing.footer == .notAllServed(shown: 4))
    }

    @Test
    func `given an ordinary change set when listing then there is no footer at all`() {
        // given
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", isViewed: true),
            aChangedFile(path: "Sources/Server/Router.swift"),
            aChangedFile(path: "Package.swift"),
            aChangedFile(path: "Tests/ViewerTests.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.footer == nil)
    }

    @Test
    func `given no files at all when listing then nothing is claimed about them`() {
        // given — reachable through the sidebar's *Show them anyway*, which opens a worktree the
        // reader has been told is clean. "All 0 files viewed" is the sentence this guards against.
        // when
        let listing = FileSelector.listing(of: [], mode: .tree, collapsed: [], isTruncated: false)

        // then
        #expect(listing.rows.isEmpty)
        #expect(listing.footer == nil)
        #expect(listing.offersModeToggle == false)
    }

    // MARK: - What a row carries

    @Test
    func `given a file when it is listed then it carries what its row reads`() {
        // given
        let files = [
            aChangedFile(path: "Sources/Client/Viewer.swift", insertions: 12, deletions: 4, isViewed: true),
            aChangedFile(path: "Sources/Server/Router.swift"),
            aChangedFile(path: "Package.swift"),
            aChangedFile(path: "Tests/ViewerTests.swift")
        ]

        // when
        let listing = FileSelector.listing(of: files, mode: .flat, collapsed: [], isTruncated: false)
        let row = listing.rows.compactMap(\.file).first { $0.name == "Viewer.swift" }

        // then
        #expect(row?.id == FileID(repositoryRelativePath: "Sources/Client/Viewer.swift"))
        #expect(row?.status == .modified)
        #expect(row?.stats == ChangeStats(filesChanged: 1, insertions: 12, deletions: 4))
        #expect(row?.isViewed == true)
    }
}

// MARK: -

private func aChangedFile(
    path: String,
    insertions: Int = 3,
    deletions: Int = 1,
    isViewed: Bool = false
) -> FileChange {
    FileChange(
        id: FileID(repositoryRelativePath: path),
        path: path,
        oldPath: nil,
        status: .modified,
        isBinary: false,
        isSubmodule: false,
        stats: ChangeStats(filesChanged: 1, insertions: insertions, deletions: deletions),
        contentHash: String(repeating: "d", count: 64),
        estimatedLineCount: insertions + deletions,
        isViewed: isViewed,
        isTruncated: false,
        language: "swift"
    )
}
