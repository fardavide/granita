import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which files the continuous scroll draws shut, and the sentence each shut file owes the reader.
///
/// **`SPEC.md` §10 asks for two of these and design §4 for the other two**, and the four are one
/// question: a bar the reader can see is a bar that has to say why it is a bar. Without the reason
/// they open the file to learn there was nothing in it, which is the exact cost collapsing was
/// supposed to save.
@Suite("File collapsing")
struct FileCollapsingTests {

    // MARK: - What shuts on its own

    @Test
    func `given a file the reader has marked read when its collapse is asked for then it is shut`() {
        // given — `SPEC.md` §10: files marked viewed render collapsed. Until now the mark moved a
        // circle and a row in the selector and left the diff open underneath it.
        let file = aChangedFile(isViewed: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then
        #expect(collapse.isCollapsed)
        #expect(collapse.reason == .viewed)
    }

    @Test
    func `given an ordinary unread file when its collapse is asked for then it is open`() {
        // given
        let file = aChangedFile()

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then — open, and with no reason to print, because there is no bar to print one on.
        #expect(collapse.isCollapsed == false)
        #expect(collapse.reason == nil)
    }

    @Test
    func `given a diff longer than the limit when its collapse is asked for then it is shut and counted`() {
        // given — `SPEC.md` §10: over 500 diff lines a file starts collapsed with a Load diff
        // affordance, which is also what makes the count worth carrying on the bar.
        let file = aChangedFile(estimatedLineCount: 1_558)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then
        #expect(collapse.isCollapsed)
        #expect(collapse.reason == .tooLong(lines: 1_558))
    }

    @Test
    func `given a diff exactly at the limit when its collapse is asked for then it is open`() {
        // given — "over 500", so 500 is not over it. The boundary is asserted rather than assumed
        // because the sentence the bar prints changes on it.
        let file = aChangedFile(estimatedLineCount: FileCollapsing.longDiffLineCount)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then
        #expect(collapse.isCollapsed == false)
    }

    @Test
    func `given a binary file when its collapse is asked for then it is shut with no way to open it`() {
        // given
        let file = aChangedFile(isBinary: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then — design §4: a disclosure control that discloses nothing is the smallest possible
        // lie, so the chevron is absent rather than drawn and dimmed.
        #expect(collapse.isCollapsed)
        #expect(collapse.isCollapsible == false)
        #expect(collapse.reason == .binary)
    }

    @Test
    func `given a rename that changed nothing when its collapse is asked for then it says what it was called`() {
        // given
        let file = aChangedFile(
            path: "Packages/Granita/Server/Sessions/Data/SessionIndex.swift",
            oldPath: "Packages/Granita/Server/Sessions/Data/SessionStore.swift",
            status: .renamed,
            insertions: 0,
            deletions: 0
        )

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then — the filename rather than the path: the reader is being told which file this used
        // to be, and the directory it moved out of is the same one it moved into.
        #expect(collapse.isCollapsed)
        #expect(collapse.isCollapsible == false)
        #expect(collapse.reason == .renamedWithNoContentChange(from: "SessionStore.swift"))
    }

    @Test
    func `given a rename that also changed lines when its collapse is asked for then it opens like any file`() {
        // given — a rename with content in it is an ordinary diff that happens to have moved.
        let file = aChangedFile(
            path: "Packages/Granita/Server/Sessions/Data/SessionIndex.swift",
            oldPath: "Packages/Granita/Server/Sessions/Data/SessionStore.swift",
            status: .renamed,
            insertions: 14,
            deletions: 3
        )

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then
        #expect(collapse.isCollapsed == false)
        #expect(collapse.isCollapsible)
    }

    @Test
    func `given a rename the Mac did not say the old name of when its collapse is asked for then it opens`() {
        // given — `oldPath` is set only for a rename, so an absent one here is a Mac that reported
        // a rename it cannot name. Shutting the file behind a sentence with a hole in it is worse
        // than opening a diff with nothing in it.
        let file = aChangedFile(oldPath: nil, status: .renamed, insertions: 0, deletions: 0)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then
        #expect(collapse.isCollapsed == false)
        #expect(collapse.isCollapsible)
    }

    // MARK: - Which reason wins

    @Test
    func `given a binary file the reader has read when its collapse is asked for then it says binary`() {
        // given — both reasons are true and only one is useful. "There is nothing behind this" tells
        // the reader not to open it; "you read it" invites them to check.
        let file = aChangedFile(isBinary: true, isViewed: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then
        #expect(collapse.reason == .binary)
    }

    @Test
    func `given a long diff the reader has read when its collapse is asked for then it says viewed`() {
        // given
        let file = aChangedFile(estimatedLineCount: 1_558, isViewed: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: nil)

        // then — the mark is this product's one job, and it is the more useful of the two: a reader
        // who has read a long file does not need to be told how long it was.
        #expect(collapse.reason == .viewed)
    }

    // MARK: - What the reader overrides

    @Test
    func `given a read file the reader has opened when its collapse is asked for then it is open`() {
        // given
        let file = aChangedFile(isViewed: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: true)

        // then — and the reason goes with it, because a reason is what a bar prints and there is no
        // bar.
        #expect(collapse.isCollapsed == false)
        #expect(collapse.reason == nil)
    }

    @Test
    func `given a read file the reader opened and shut again when its collapse is asked for then it says viewed`() {
        // given — the automatic reason is computed whether or not the reader has an opinion, so
        // shutting a file by hand does not erase why it was shut in the first place.
        let file = aChangedFile(isViewed: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: false)

        // then
        #expect(collapse.isCollapsed)
        #expect(collapse.reason == .viewed)
    }

    @Test
    func `given an ordinary file the reader has shut when its collapse is asked for then it has no reason`() {
        // given
        let file = aChangedFile()

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: false)

        // then — **the bar is one line here rather than two**, which is the design being followed
        // rather than dropped: the four reasons §4 draws are the four the app decided on its own,
        // and telling a reader they shut a file they just shut is a line that says nothing.
        #expect(collapse.isCollapsed)
        #expect(collapse.reason == nil)
    }

    @Test
    func `given a binary file the reader somehow opened when its collapse is asked for then it stays shut`() {
        // given — unreachable through the bar, which draws no chevron for it, and asserted anyway:
        // a state that depends on a view not offering a control is a state one refactor away.
        let file = aChangedFile(isBinary: true)

        // when
        let collapse = FileCollapsing.state(of: file, openedByTheReader: true)

        // then
        #expect(collapse.isCollapsed)
        #expect(collapse.isCollapsible == false)
    }
}

// MARK: -

private func aChangedFile(
    path: String = "Packages/Granita/Server/Api/Presentation/ApiRoutes.swift",
    oldPath: String? = nil,
    status: FileStatus = .modified,
    isBinary: Bool = false,
    insertions: Int = 412,
    deletions: Int = 96,
    estimatedLineCount: Int = 32,
    isViewed: Bool = false
) -> FileChange {
    FileChange(
        id: FileID(repositoryRelativePath: path),
        path: path,
        oldPath: oldPath,
        status: status,
        isBinary: isBinary,
        isSubmodule: false,
        stats: ChangeStats(filesChanged: 1, insertions: insertions, deletions: deletions),
        contentHash: String(repeating: "c", count: 64),
        estimatedLineCount: estimatedLineCount,
        isViewed: isViewed,
        isTruncated: false,
        language: "swift"
    )
}
