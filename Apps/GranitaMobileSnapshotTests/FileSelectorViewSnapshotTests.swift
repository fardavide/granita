import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// Design §3's list, in each arrangement and each of the three states the review names.
///
/// **Rendered directly rather than presented**, which is this project's settled way of photographing
/// a sheet: a hosted view presents one into a window of its own and the raster does not include it,
/// so a baseline of the diff behind it would be a picture of the diff with nothing on top. What that
/// costs is the drawer's own chrome — the grabber and the detent — and what it keeps is every row,
/// which is where §3's arithmetic is.
///
/// Main-actor isolated, and it must be. Rendering off the main actor traps in a way that restarts the
/// test host, and the retry then reports "0 tests passed" — a suite that goes green having rendered
/// nothing.
@Suite("File selector")
@MainActor
struct FileSelectorViewSnapshotTests {

    @Test(arguments: FileSelectorCase.all, SnapshotLayout.all)
    func `given a listing when it renders then it matches its baseline`(
        subject: FileSelectorCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            FileSelectorView(
                listing: subject.listing,
                onChoose: { _ in },
                onToggleDirectory: { _ in },
                onChooseMode: { _ in }
            ),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
struct FileSelectorCase: Sendable, CustomTestStringConvertible {

    let name: String
    let listing: FileSelectorListing

    var testDescription: String { name }

    static let all: [FileSelectorCase] = [
        // The tree doing its job: two roots, a compacted chain, every status treatment §3 defines,
        // and one file already read so the dimmed name and the check are both in the picture.
        FileSelectorCase(
            name: "a-tree",
            listing: FileSelector.listing(
                of: aChangeSetWorthATree,
                mode: .tree,
                collapsed: [],
                isTruncated: false
            )
        ),

        // A shut directory, which is the only row that carries a summed total — and the row whose
        // name has to survive head truncation at the indent clamp.
        FileSelectorCase(
            name: "a-shut-directory",
            listing: FileSelector.listing(
                of: aChangeSetWorthATree,
                mode: .tree,
                collapsed: [aShutDirectory],
                isTruncated: false
            )
        ),

        // The same rows, differently labelled: the directory prefix secondary and the filename
        // primary, head-truncated so the prefix erodes and the name never does.
        FileSelectorCase(
            name: "flat",
            listing: FileSelector.listing(
                of: aChangeSetWorthATree,
                mode: .flat,
                collapsed: [],
                isTruncated: false
            )
        ),

        // Three files. No tree, and **no toggle at all** rather than a greyed one — there is no
        // second arrangement to offer, so a disabled control would be asking about one.
        FileSelectorCase(
            name: "too-few-files-for-a-tree",
            listing: FileSelector.listing(
                of: Array(aChangeSetWorthATree.prefix(3)),
                mode: .tree,
                collapsed: [],
                isTruncated: false
            )
        ),

        // More files changed than this Mac serves at once. A sentence rather than a *Load more* the
        // Mac's own limits would refuse.
        FileSelectorCase(
            name: "not-all-served",
            listing: FileSelector.listing(
                of: aChangeSetWorthATree,
                mode: .tree,
                collapsed: [],
                isTruncated: true
            )
        ),

        // Everything read. Deliberately not an unavailable-content view: the files are still there
        // and still openable, every name is secondary, every check is set, and the reader's next
        // move is to leave rather than to be congratulated.
        FileSelectorCase(
            name: "everything-viewed",
            listing: FileSelector.listing(
                of: aChangeSetWorthATree.map { $0.viewed(true) },
                mode: .tree,
                collapsed: [],
                isTruncated: false
            )
        ),

        // One file, read. A count has two spellings and only one of them is the plural — the state
        // that would otherwise ship as "All 1 files viewed." and be seen for the first time by
        // whoever changed one file.
        FileSelectorCase(
            name: "one-file-and-it-is-viewed",
            listing: FileSelector.listing(
                of: aChangeSetWorthATree.prefix(1).map { $0.viewed(true) },
                mode: .tree,
                collapsed: [],
                isTruncated: false
            )
        ),

        // The one state a reader reaches through the sidebar's *Show them anyway*. Nothing to list,
        // and nothing claimed about it — "All 0 files viewed" is the sentence this guards against.
        FileSelectorCase(
            name: "nothing-changed",
            listing: FileSelector.listing(of: [], mode: .tree, collapsed: [], isTruncated: false)
        )
    ]
}
