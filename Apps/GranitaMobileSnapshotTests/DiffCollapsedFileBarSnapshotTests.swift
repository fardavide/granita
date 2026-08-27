import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// The 44pt row a shut file becomes, and the sentence each one owes the reader.
///
/// **The reason is the field worth a picture.** Design §4 added it to the specification, and the
/// case for it is that a bar without one costs the reader exactly what collapsing was meant to save
/// — they open the file to learn there was nothing in it. Four sentences, plus the fifth case the
/// design does not draw: a file the reader shut by hand, which has nothing to say back to them and
/// is therefore one line rather than two.
///
/// The scroll's own suite photographs these in place; this one photographs them at a size where the
/// truncation and the two-line stack can be read.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Diff collapsed file bar")
@MainActor
struct DiffCollapsedFileBarSnapshotTests {

    @Test(arguments: CollapsedBarCase.all, SnapshotLayout.all)
    func `given a shut file when its bar renders then it matches its baseline`(
        subject: CollapsedBarCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            DiffCollapsedFileBar(file: subject.file, collapse: subject.collapse) { _, _ in }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which reason it captures, and so a failure names it too.
struct CollapsedBarCase: Sendable, CustomTestStringConvertible {

    let name: String
    let file: FileChange
    let collapse: FileCollapse

    var testDescription: String { name }

    /// **Built through `FileCollapsing` rather than by hand**, so a picture cannot show a pairing
    /// the domain would never produce — a chevron on a binary file, or a reason on an open one.
    private init(name: String, file: FileChange, openedByTheReader: Bool?) {
        self.name = name
        self.file = file
        collapse = FileCollapsing.state(of: file, openedByTheReader: openedByTheReader)
    }

    static let all: [CollapsedBarCase] = [
        // The mark, which is this product's one job. **"viewed" and not "viewed 4 minutes ago"**:
        // the Mac keeps a mark as the content hash it was set against and no time beside it, so the
        // elapsed reading is a number this phone would have to invent.
        CollapsedBarCase(
            name: "viewed",
            file: aFileOnABar(
                path: "Packages/Granita/Server/Api/Presentation/GranitaRouter.swift",
                status: .modified,
                insertions: 412,
                deletions: 96,
                estimatedLineCount: 508,
                isViewed: true
            ),
            openedByTheReader: nil
        ),

        // `SPEC.md` §10's *Load diff*, which is the one reason that is also an affordance: this
        // file's diff has deliberately not been fetched, and pressing the bar is what fetches it.
        CollapsedBarCase(
            name: "too-long",
            file: aFileOnABar(
                path: "Packages/Granita/Core/Diff/Domain/UnifiedDiffParser.swift",
                status: .modified,
                insertions: 1_240,
                deletions: 318,
                estimatedLineCount: 1_558,
                isViewed: false
            ),
            openedByTheReader: nil
        ),

        // No chevron, because there is nothing behind it.
        CollapsedBarCase(
            name: "binary",
            file: aFileOnABar(
                path: "Art/icon/granita-tinted.svg",
                status: .added,
                insertions: 0,
                deletions: 0,
                estimatedLineCount: 0,
                isViewed: false,
                isBinary: true
            ),
            openedByTheReader: nil
        ),

        // The other one with no chevron, and the only reason that names another file.
        CollapsedBarCase(
            name: "renamed-with-no-content-change",
            file: aFileOnABar(
                path: "Packages/Granita/Server/Sessions/Data/SessionIndex.swift",
                status: .renamed,
                insertions: 0,
                deletions: 0,
                estimatedLineCount: 0,
                isViewed: false,
                oldPath: "Packages/Granita/Server/Sessions/Data/SessionStore.swift"
            ),
            openedByTheReader: nil
        ),

        // **The case design §4 does not draw**, and the one that decides whether the bar is one line
        // or two: a file the reader shut themselves. Telling them they shut it is a line that says
        // nothing, so there is no second line and the row has to still look like a row.
        CollapsedBarCase(
            name: "shut-by-the-reader",
            file: aFileOnABar(
                path: "Packages/Granita/Client/Viewer/Ui/ContinuousDiffView.swift",
                status: .modified,
                insertions: 68,
                deletions: 12,
                estimatedLineCount: 80,
                isViewed: false
            ),
            openedByTheReader: false
        )
    ]
}

private func aFileOnABar(
    path: String,
    status: FileStatus,
    insertions: Int,
    deletions: Int,
    estimatedLineCount: Int,
    isViewed: Bool,
    isBinary: Bool = false,
    oldPath: String? = nil
) -> FileChange {
    FileChange(
        id: FileID(repositoryRelativePath: path),
        path: path,
        oldPath: oldPath,
        status: status,
        isBinary: isBinary,
        isSubmodule: false,
        stats: ChangeStats(filesChanged: 1, insertions: insertions, deletions: deletions),
        contentHash: String(repeating: "d", count: 64),
        estimatedLineCount: estimatedLineCount,
        isViewed: isViewed,
        isTruncated: false,
        language: isBinary ? nil : "swift"
    )
}
