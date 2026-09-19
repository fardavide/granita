import ClientConnectionDomain
import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
import ClientWorktreesPresentation
import CoreDiffDomain
import CoreReviewDomain
import Foundation
import SwiftUI
import Synchronization

/// Diff lines a real repository would produce, for the screens design §4 draws.
///
/// **Every one of these is a case the layout has to get right rather than a case that looks nice.**
/// A run of plain context lines photographs a monospaced font; what is worth a baseline is the
/// deletion with no new number, the pair the parser segmented, the tab that has to land on the grid
/// the server measured, the wide character that would make one row taller than the number beside it,
/// and the conflict marker that arrives looking like ordinary content.

// MARK: - The lines

/// A change to one Swift function, as the parser hands it over: context, a segmented pair, and the
/// two numbers moving independently through it.
nonisolated let aChangedFunction: [DiffLine] = [
    context(old: 138, new: 138, "    /// Reads the Mac's health before spending anything."),
    context(old: 139, new: 139, "    func health() async throws(ApiFailure) -> HealthResponse {"),
    // The tab is deliberate and it is the only one here: this repository indents with spaces, and a
    // line that does not is exactly the line whose gutter alignment nobody would have checked.
    context(old: 140, new: 140, "\tlet request = Request(path: \"/v1/health\")"),
    deletion(
        old: 141,
        "        let trust = try await verify(cert)",
        segments: [
            unchanged("        let trust = try await verify("),
            changed("cert"),
            unchanged(")")
        ]
    ),
    addition(
        new: 141,
        "        let trust = try await verify(certificate)",
        segments: [
            unchanged("        let trust = try await verify("),
            changed("certificate"),
            unchanged(")")
        ]
    ),
    addition(new: 142, "        guard trust.isPinned else { throw .notUnderstood(diagnostic: nil) }"),
    context(old: 142, new: 143, "    }")
]

/// A line long enough to leave the screen, which is the whole of what wrap-off means: the code runs
/// past the trailing edge, and the numbers beside it do not go with it.
nonisolated let aLineThatRunsOffTheEdge: [DiffLine] = [
    context(old: 1_203, new: 1_203, "    private let reshapingScriptRanges: [ClosedRange<UInt32>] = ["),
    addition(
        new: 1_204,
        "        0x0590...0x08FF, // Hebrew, Arabic, Syriac, Thaana, N'Ko, Samaritan, Arabic extended A"
    ),
    context(old: 1_204, new: 1_205, "    ]")
]

/// The one status design §4 gives a badge to. They arrive as ordinary diff lines, so the parser's
/// own kind is the only thing that makes them findable.
nonisolated let aConflictedHunk: [DiffLine] = [
    context(old: 61, new: 61, "    let segments = pair(old, new)"),
    conflictMarker(old: 62, new: 62, "<<<<<<< HEAD"),
    context(old: 63, new: 63, "    return segments.merged()"),
    conflictMarker(old: 64, new: 64, "======="),
    addition(new: 65, "    return segments.collapsed()"),
    conflictMarker(old: 66, new: 66, ">>>>>>> feat/word-diff")
]

/// A wide character, a pair with no word diff, and the marker that is rendered and never counted as
/// content — three lines that each measure differently from how they look, and the reason the row
/// height is taken from the font rather than from whatever is in the row.
nonisolated let theAwkwardLines: [DiffLine] = [
    context(old: 7, new: 7, "let label = \"図形\""),
    deletion(old: 8, "let done = false"),
    addition(new: 8, "let done = true"),
    DiffLine(
        kind: .noNewlineMarker,
        oldNumber: nil,
        newNumber: nil,
        text: "\\ No newline at end of file",
        displayColumns: 27,
        segments: nil
    )
]

/// A hundred lines cut from the end of a file, so the old side runs into four figures while the new
/// side stops at two.
///
/// **The one column has to be sized from the larger of the two**, and this is the case that says so:
/// measured on the new maximum, `1041` would be drawn into a column cut for `12`.
nonisolated let anOldSideThatOutrunsTheNew: [DiffLine] = [
    context(old: 1_038, new: 11, "    // Everything below here moved to LegacyExport.swift."),
    deletion(old: 1_039, "    func exportAsPropertyList() throws -> Data {"),
    deletion(old: 1_040, "        try PropertyListEncoder().encode(self)"),
    deletion(old: 1_041, "    }"),
    context(old: 1_042, new: 12, "}")
]

// MARK: - Builders

private func context(old: Int, new: Int, _ text: String) -> DiffLine {
    DiffLine(
        kind: .context,
        oldNumber: old,
        newNumber: new,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: nil
    )
}

private func addition(new: Int, _ text: String, segments: [WordSegment]? = nil) -> DiffLine {
    DiffLine(
        kind: .addition,
        oldNumber: nil,
        newNumber: new,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: segments
    )
}

private func deletion(old: Int, _ text: String, segments: [WordSegment]? = nil) -> DiffLine {
    DiffLine(
        kind: .deletion,
        oldNumber: old,
        newNumber: nil,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: segments
    )
}

private func conflictMarker(old: Int, new: Int, _ text: String) -> DiffLine {
    DiffLine(
        kind: .conflictMarker,
        oldNumber: old,
        newNumber: new,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: nil
    )
}

private func unchanged(_ text: String) -> WordSegment {
    WordSegment(text: text, isChanged: false)
}

private func changed(_ text: String) -> WordSegment {
    WordSegment(text: text, isChanged: true)
}

/// A stand-in for the column count the server sends, near enough for a fixture: nothing on screen
/// branches on it yet, and the thing that will — wrap on — is not built.
private enum DisplayColumns {

    static func of(_ text: String) -> Int {
        text.count
    }
}

// MARK: - Whole files

/// Two hunks in one file, and the second one has no section heading.
///
/// That second case is the ordinary one rather than the odd one: git omits the heading whenever
/// nothing encloses the change, which is most changes near the top of a file. Design §4 draws only
/// the case where a heading exists, so the band without one is a state somebody has to have looked
/// at.
nonisolated let aFileWithTwoHunks: [Hunk] = [
    Hunk(
        index: 0,
        oldStart: 138,
        oldCount: 5,
        newStart: 138,
        newCount: 6,
        sectionHeading: "func health() async throws(ApiFailure) -> HealthResponse",
        lines: aChangedFunction
    ),
    Hunk(
        index: 1,
        oldStart: 1_203,
        oldCount: 2,
        newStart: 1_204,
        newCount: 3,
        sectionHeading: nil,
        lines: aLineThatRunsOffTheEdge
    )
]

/// One hunk whose numbers reach four figures, so the gutter is sized from the file rather than from
/// whichever hunk is on screen — the first hunk's numbers are two figures and get the file's width.
nonisolated let aFileWhoseHunksDisagreeOnWidth: [Hunk] = [
    Hunk(
        index: 0,
        oldStart: 61,
        oldCount: 5,
        newStart: 61,
        newCount: 5,
        sectionHeading: "func merged() -> [WordSegment]",
        lines: aConflictedHunk
    ),
    Hunk(
        index: 1,
        oldStart: 1_203,
        oldCount: 2,
        newStart: 1_204,
        newCount: 3,
        sectionHeading: "private let reshapingScriptRanges",
        lines: aLineThatRunsOffTheEdge
    )
]

/// A file whose one hunk runs from its first line to its last, so neither expand control has a gap
/// to open and neither is drawn.
///
/// **The control render for the two above**, which each photograph a band carrying both chevrons: a
/// picture of a chevron says nothing about whether it appears only where it should.
nonisolated let aWholeFileInOneHunk = FileDiff(
    file: aChangedFile(
        path: "Packages/Granita/Core/Branding/Domain/Branding.swift",
        status: .modified,
        insertions: 2,
        deletions: 1,
        estimatedLineCount: 4
    ),
    hunks: [
        Hunk(
            index: 0,
            oldStart: 1,
            oldCount: 3,
            newStart: 1,
            newCount: 4,
            sectionHeading: "enum Branding",
            lines: [
                context(old: 1, new: 1, "enum Branding {"),
                deletion(old: 2, "    static let name = \"Granita\""),
                addition(new: 2, "    static let name = \"Granita\"  // the product"),
                addition(new: 3, "    static let scheme = \"granita\""),
                context(old: 3, new: 4, "}")
            ]
        )
    ],
    oldLineCount: 3,
    newLineCount: 4,
    isTruncated: false,
    truncationReason: nil
)

/// The same change in a file that carries on afterwards, which is the expander **torn below**.
///
/// There is nothing above the hunk to reveal and nineteen lines after it, so the row names its
/// destination rather than a declaration — design §4: "downward there is no such thing to name, so
/// it names the destination instead."
nonisolated let aFileWithLinesAfterItsChange = FileDiff(
    file: aChangedFile(
        path: "SwiftlyCore/Sources/Currency/Domain/Models/CurrencyRate.swift",
        status: .modified,
        insertions: 1,
        deletions: 1,
        estimatedLineCount: 23
    ),
    hunks: [
        Hunk(
            index: 0,
            oldStart: 1,
            oldCount: 4,
            newStart: 1,
            newCount: 4,
            sectionHeading: nil,
            lines: [
                context(old: 1, new: 1, "import Foundation"),
                context(old: 2, new: 2, ""),
                deletion(old: 3, "public struct CurrencyRate: Equatable {"),
                addition(new: 3, "public struct CurrencyRate: Equatable, Sendable {"),
                context(old: 4, new: 4, "}")
            ]
        )
    ],
    oldLineCount: 23,
    newLineCount: 23,
    isTruncated: false,
    truncationReason: nil
)

/// A change the diff had to skip into, which is the expander **torn above**.
///
/// Seven lines are missing before it and none after, so the row carries git's own heading for the
/// hunk below it — the declaration the reader lost by arriving in the middle of the file.
nonisolated let aFileWithLinesBeforeItsChange = FileDiff(
    file: aChangedFile(
        path: "SwiftlyCore/Sources/Currency/Domain/Models/CurrencyWithRate.swift",
        status: .modified,
        insertions: 1,
        deletions: 1,
        estimatedLineCount: 11
    ),
    hunks: [
        Hunk(
            index: 0,
            oldStart: 8,
            oldCount: 4,
            newStart: 8,
            newCount: 4,
            sectionHeading: "public struct CurrencyWithRate",
            lines: [
                context(old: 8, new: 8, "  let currency: Currency"),
                deletion(old: 9, "  let rate: Double"),
                addition(new: 9, "  let rate: CurrencyRate"),
                context(old: 10, new: 10, "}"),
                context(old: 11, new: 11, "")
            ]
        )
    ],
    oldLineCount: 11,
    newLineCount: 11,
    isTruncated: false,
    truncationReason: nil
)

/// Two changes with four lines between them, which is the expander **torn both ways** — the only
/// form with two controls and the only one whose count moves into its label.
///
/// Both ends of this file are drawn, so it is the middle gap alone. That is what makes it the control
/// for the two above: a picture of a row torn on one edge says nothing about whether the other edge
/// is torn only when it should be.
nonisolated let aFileWithAGapBetweenItsHunks = FileDiff(
    file: aChangedFile(
        path: "SwiftlyCore/Sources/Currency/Domain/Models/CurrencyValue.swift",
        status: .modified,
        insertions: 2,
        deletions: 2,
        estimatedLineCount: 12
    ),
    hunks: [
        Hunk(
            index: 0,
            oldStart: 1,
            oldCount: 4,
            newStart: 1,
            newCount: 4,
            sectionHeading: nil,
            lines: [
                context(old: 1, new: 1, "import Foundation"),
                context(old: 2, new: 2, ""),
                deletion(old: 3, "public struct CurrencyValue: Equatable {"),
                addition(new: 3, "public struct CurrencyValue: Equatable, Sendable {"),
                context(old: 4, new: 4, "  let amount: Decimal")
            ]
        ),
        Hunk(
            index: 1,
            oldStart: 9,
            oldCount: 4,
            newStart: 9,
            newCount: 4,
            sectionHeading: "func formatted() -> String",
            lines: [
                context(old: 9, new: 9, "  func formatted() -> String {"),
                deletion(old: 10, "    amount.description"),
                addition(new: 10, "    amount.formatted(.currency(code: code))"),
                context(old: 11, new: 11, "  }"),
                context(old: 12, new: 12, "}")
            ]
        )
    ],
    oldLineCount: 12,
    newLineCount: 12,
    isTruncated: false,
    truncationReason: nil
)

/// A file with no old side at all, which is an agent writing a new file — the ordinary case, and one
/// no baseline has ever held.
///
/// **It is the gutter's own fallback.** The old column is sized from the file's highest old line
/// number and there is not one, so the width falls back to nothing; every row's old figure is blank
/// on the iPad, where both columns are drawn.
nonisolated let aFileThatIsAllAdditions = FileDiff(
    file: aChangedFile(
        path: "Packages/Granita/Client/Viewer/Ui/DiffCollapsedFileBar.swift",
        status: .added,
        insertions: 4,
        deletions: 0,
        estimatedLineCount: 4
    ),
    hunks: [
        Hunk(
            index: 0,
            oldStart: 0,
            oldCount: 0,
            newStart: 1,
            newCount: 4,
            sectionHeading: nil,
            lines: [
                addition(new: 1, "public struct DiffCollapsedFileBar: View {"),
                addition(new: 2, "    public static let height: CGFloat = 44"),
                addition(new: 3, "    private let file: FileChange"),
                addition(new: 4, "}")
            ]
        )
    ],
    oldLineCount: 0,
    newLineCount: 4,
    isTruncated: false,
    truncationReason: nil
)

/// The mirror: a file an agent removed, which has no new side and therefore no new number on any
/// row. Design §4 says the column is blank on a deletion row; this is the whole file of them.
nonisolated let aFileThatIsAllDeletions = FileDiff(
    file: aChangedFile(
        path: "Packages/Granita/Client/Viewer/Ui/WorktreeNotReadyView.swift",
        status: .deleted,
        insertions: 0,
        deletions: 3,
        estimatedLineCount: 3
    ),
    hunks: [
        Hunk(
            index: 0,
            oldStart: 1,
            oldCount: 3,
            newStart: 0,
            newCount: 0,
            sectionHeading: nil,
            lines: [
                deletion(old: 1, "struct WorktreeNotReadyView: View {"),
                deletion(old: 2, "    var body: some View { Text(\"Not built yet\") }"),
                deletion(old: 3, "}")
            ]
        )
    ],
    oldLineCount: 3,
    newLineCount: 0,
    isTruncated: false,
    truncationReason: nil
)

/// A file long enough that both of its hunks have somewhere left to expand into.
nonisolated func aFileOf(_ hunks: [Hunk], newLineCount: Int) -> FileDiff {
    FileDiff(
        file: aChangedFile(
            path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
            status: .modified,
            insertions: 12,
            deletions: 4,
            estimatedLineCount: hunks.reduce(0) { $0 + $1.lines.count }
        ),
        hunks: hunks,
        oldLineCount: newLineCount,
        newLineCount: newLineCount,
        isTruncated: false,
        truncationReason: nil
    )
}

// MARK: - The change set, as the continuous scroll sees it

/// Three files: one fetched, one still on its way, one fetched and conflicted.
///
/// **The middle one is the case worth photographing.** Every file is drawn from the first frame,
/// whether or not its diff has arrived, and the one that has not reserves its height from the
/// server's estimate — which is what stops the content below it moving when the diff lands.
nonisolated let aChangeSetPartlyArrived: [ContinuousDiffEntry] = [
    .ready(
        FileDiff(
            file: aChangedFile(
                path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
                status: .modified,
                insertions: 12,
                deletions: 4,
                estimatedLineCount: 16
            ),
            hunks: aFileWithTwoHunks,
            oldLineCount: 1_204,
            newLineCount: 1_205,
            isTruncated: false,
            truncationReason: nil
        )
    ),
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Client/Viewer/Ui/ContinuousDiffView.swift",
            status: .added,
            insertions: 68,
            deletions: 0,
            estimatedLineCount: 20
        )
    ),
    .ready(
        FileDiff(
            file: aChangedFile(
                path: "Packages/Granita/Core/Diff/Domain/WordDiff.swift",
                status: .conflicted,
                insertions: 3,
                deletions: 2,
                estimatedLineCount: 6
            ),
            hunks: [aConflictedFileHunk],
            oldLineCount: 66,
            newLineCount: 66,
            isTruncated: false,
            truncationReason: nil
        )
    )
]

/// A one-line file on its way, above a file large enough to measure it against.
///
/// **The 18pt end of design §9's range**, which is the one that catches an answer sized to its own
/// content: a `+1` file reserves `max(1, 1) × 18` and the sentence is the whole of it. Nothing may be
/// clipped, nothing may be centred in a space too small for it, and the file below has to keep its
/// 10pt gap.
nonisolated let aChangeSetWithAOneLineFile: [ContinuousDiffEntry] = [
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Client/Viewer/Domain/DiffFileWait.swift",
            status: .added,
            insertions: 1,
            deletions: 0,
            estimatedLineCount: 1
        )
    ),
    .failed(
        aChangedFile(
            path: "Packages/Granita/Core/Diff/Domain/WordDiff.swift",
            status: .modified,
            insertions: 3,
            deletions: 2,
            estimatedLineCount: 1
        )
    ),
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Client/Viewer/Ui/ContinuousDiffView.swift",
            status: .modified,
            insertions: 68,
            deletions: 4,
            estimatedLineCount: 24
        )
    )
]

/// A re-recorded snapshot baseline beside the source file that moved it.
///
/// **The picture's diff is a real answer with no hunks in it**, which is exactly what the Mac sends
/// for a PNG: git prints `Binary files a/… and b/… differ` and the parser finds nothing to put in
/// it. Before the card existed that landed as an empty file; it is what the two frames are drawn
/// instead of, so the entry has to be `ready` for the card to be reached at all.
///
/// The bytes are not in here. They arrive through the two requests the model makes once this lands,
/// which is the path the app takes and the only one that exercises it.
nonisolated let aChangeSetWithAPicture: [ContinuousDiffEntry] = [
    .ready(
        FileDiff(
            file: aChangedFile(
                path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/the-drawer-is-up-iPhone-light.png",
                status: .modified,
                insertions: 0,
                deletions: 0,
                estimatedLineCount: 0,
                isBinary: true
            ),
            hunks: [],
            oldLineCount: 0,
            newLineCount: 0,
            isTruncated: false,
            truncationReason: nil
        )
    ),
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Client/Viewer/Ui/FileSelectorView.swift",
            status: .modified,
            insertions: 12,
            deletions: 3,
            estimatedLineCount: 15
        )
    )
]

private nonisolated let aConflictedFileHunk = Hunk(
    index: 0,
    oldStart: 61,
    oldCount: 5,
    newStart: 61,
    newCount: 5,
    sectionHeading: "func merged() -> [WordSegment]",
    lines: aConflictedHunk
)

/// The four reasons design §4 draws a bar for, in one scroll, and one file left open under them.
///
/// **Every one of these is a different sentence and two of them are a different row**, which is the
/// whole of what the section argues: a binary file and a rename that changed nothing get no chevron,
/// because there is nothing behind them and a disclosure control that discloses nothing is the
/// smallest possible lie. The fifth file is what a bar is measured against.
nonisolated let aChangeSetOfShutFiles: [ContinuousDiffEntry] = [
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Server/Api/Presentation/GranitaRouter.swift",
            status: .modified,
            insertions: 412,
            deletions: 96,
            estimatedLineCount: 508,
            isViewed: true
        )
    ),
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Core/Diff/Domain/UnifiedDiffParser.swift",
            status: .modified,
            insertions: 1_240,
            deletions: 318,
            estimatedLineCount: 1_558,
            isViewed: false
        )
    ),
    .awaiting(
        aChangedFile(
            path: "Art/icon/granita-tinted.svg",
            status: .added,
            insertions: 0,
            deletions: 0,
            estimatedLineCount: 0,
            isViewed: false,
            isBinary: true
        )
    ),
    .awaiting(
        aChangedFile(
            path: "Packages/Granita/Server/Sessions/Data/SessionIndex.swift",
            status: .renamed,
            insertions: 0,
            deletions: 0,
            estimatedLineCount: 0,
            isViewed: false,
            oldPath: "Packages/Granita/Server/Sessions/Data/SessionStore.swift"
        )
    ),
    .ready(
        FileDiff(
            file: aChangedFile(
                path: "Packages/Granita/Core/Diff/Domain/WordDiff.swift",
                status: .conflicted,
                insertions: 3,
                deletions: 2,
                estimatedLineCount: 6
            ),
            hunks: [aConflictedFileHunk],
            oldLineCount: 66,
            newLineCount: 66,
            isTruncated: false,
            truncationReason: nil
        )
    )
]

// MARK: - The change set, as design §3's selector sees it

/// A change set with structure worth a tree: two roots, a compacted chain deep enough to reach the
/// indent clamp, one directory shut, one file already read, and every colour treatment §3 defines.
///
/// **Every path here is one of this repository's own**, which is what makes the truncation states
/// real rather than contrived: the 77-character compacted path §3 measures its 33-character clamp
/// against is in this list, and so is the depth that clamp exists for.
nonisolated let aChangeSetWorthATree: [FileChange] = [
    aChangedFile(
        path: "Packages/Granita/Client/Connection/Domain/DiscoveryState.swift",
        status: .modified,
        insertions: 12,
        deletions: 3,
        estimatedLineCount: 15,
        isViewed: true
    ),
    aChangedFile(
        path: "Packages/Granita/Client/Connection/Domain/PinnedCertificate.swift",
        status: .added,
        insertions: 84,
        deletions: 0,
        estimatedLineCount: 84,
        isViewed: false
    ),
    aChangedFile(
        path: "Packages/Granita/Client/Connection/Ui/ServerDiscoveryView.swift",
        status: .renamed,
        insertions: 31,
        deletions: 18,
        estimatedLineCount: 49,
        isViewed: false
    ),
    aChangedFile(
        path: "Packages/Granita/Core/Diff/Domain/WordDiff.swift",
        status: .conflicted,
        insertions: 184,
        deletions: 7,
        estimatedLineCount: 191,
        isViewed: false
    ),
    aChangedFile(
        path: "Packages/Granita/Core/Diff/Domain/DiffModels.swift",
        status: .deleted,
        insertions: 0,
        deletions: 26,
        estimatedLineCount: 26,
        isViewed: false
    ),
    aChangedFile(
        path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/ServerDiscoveryViewSnapshotTests/a-mac-found.png",
        status: .untracked,
        insertions: 1,
        deletions: 0,
        estimatedLineCount: 1,
        isViewed: false
    ),
    aChangedFile(
        path: "project.yml",
        status: .typeChanged,
        insertions: 3,
        deletions: 1,
        estimatedLineCount: 4,
        isViewed: false
    )
]

/// The one directory a reader would shut first — the deepest, and the one whose name has to survive
/// head truncation at the clamp.
nonisolated let aShutDirectory = "Apps/GranitaMobileSnapshotTests/__Snapshots__/ServerDiscoveryViewSnapshotTests"

/// One changed file, as the change set reports it. A factory rather than a memberwise call, which is
/// where this repository allows defaults to live.
///
/// Not `private`: the file header's own suite photographs each of the seven statuses through it, and
/// a second builder beside this one is a second set of defaults to keep in step.
func aChangedFile(
    path: String,
    status: FileStatus,
    insertions: Int,
    deletions: Int,
    estimatedLineCount: Int,
    isViewed: Bool = false,
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
        contentHash: String(repeating: "b", count: 64),
        estimatedLineCount: estimatedLineCount,
        isViewed: isViewed,
        isTruncated: false,
        language: isBinary ? nil : "swift"
    )
}

// MARK: - A Mac for the screens that build a whole viewer

/// Answers the two read routes the diff screen uses, from the change set above.
///
/// It exists so the split screen's own baselines photograph **the real destination** rather than a
/// stand-in: what those pictures are for is that a chosen row leads somewhere, and a stub behind the
/// row would assert that a stub leads somewhere.
/// A class rather than a struct, and only so it can count: a `Mutex` is non-copyable, and the read
/// ordinal has to survive being handed to a model as an existential.
final class FakeDiffRepository: GranitaRepository {

    let files: [FileChange]
    let diffs: [FileID: FileDiff]

    /// What every batch comes back with, when it comes back refused.
    let refusal: ApiFailure?

    /// How many change-set reads answer before the rest park until they are cancelled.
    ///
    /// **Parked rather than spun**, and the difference took four suites down: a
    /// `while … { await Task.yield() }` gate never stops being runnable, so a read left open for a
    /// baseline keeps the cooperative pool busy for the rest of the run — and because every suite
    /// here shares one window, the renders after it came back blank. A sleep suspends and wakes on
    /// cancellation, which is what the caller does once the shutter has closed.
    let readsAnsweringAtAll: Int

    private let readOrdinals = Mutex<Int>(0)

    init(
        entries: [ContinuousDiffEntry],
        refusing refusal: ApiFailure? = nil,
        answeringOnly readsAnsweringAtAll: Int = .max
    ) {
        files = entries.map(\.file)
        self.refusal = refusal
        self.readsAnsweringAtAll = readsAnsweringAtAll
        diffs = Dictionary(
            uniqueKeysWithValues: entries.compactMap { entry in
                guard case .ready(let diff) = entry.content else { return nil }
                return (entry.id, diff)
            }
        )
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        let ordinal = readOrdinals.withLock { count in
            count += 1
            return count
        }
        if ordinal > readsAnsweringAtAll {
            try? await Task.sleep(for: .seconds(60 * 60))
        }
        return WorktreeChanges(
            revision: "9d41e0c7",
            stats: ChangeStats(filesChanged: files.count, insertions: 83, deletions: 6),
            files: files,
            isTruncated: false
        )
    }

    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        if let refusal {
            throw refusal
        }
        return files.compactMap { diffs[$0] }
    }

    func projects() async throws(ApiFailure) -> [Project] { [] }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] { [] }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        throw .worktreeGone
    }

    func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        throw .worktreeGone
    }

    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        throw .fileGone
    }

    /// A drawable picture per side, so a baseline photographs two real pictures rather than two
    /// failure frames.
    ///
    /// **Refused when the side is not one this file has**, which is the fake behaving like the Mac
    /// rather than being lenient: a card asking for a side `ImageSides` says is absent would then
    /// photograph green where the app photographs a refusal.
    func image(of file: FileID, in worktree: WorktreeID, side: DiffSide) async throws(ApiFailure) -> Data {
        if let refusal {
            throw refusal
        }
        guard let change = files.first(where: { $0.id == file }),
              ImageSides.forStatus(change.status).contains(side) else {
            throw .fileGone
        }
        return SnapshotPicture.bytes(for: side)
    }

    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        throw .fileGone
    }

    // A baseline never reaches the review's routes: the sheet is handed a store directly.
    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] { [] }
    func putReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(ApiFailure) {}
    func reviewSettings() async throws(ApiFailure) -> ReviewSettings { .unset }
    func updateReviewSettings(
        _ patch: ReviewSettingsPatch
    ) async throws(ApiFailure) -> ReviewSettings { .unset }
}

/// A viewer model that has already read its change set and fetched the first window.
///
/// **Loaded before the render rather than during it**, which is the difference between a baseline
/// and a race: the diff screen loads from its own `.task`, so a screen handed a fresh model
/// photographs whichever of the spinner and the content won — and the first recording of it caught
/// the spinner. Awaiting here settles the raster, and it is why the two suites that use this are
/// `async`.
@MainActor
func aLoadedViewerModel(in layout: SnapshotLayout) async -> ClientViewerModel {
    await aLoadedViewerModel(of: aChangeSetPartlyArrived, in: layout)
}

@MainActor
func aLoadedViewerModel(of entries: [ContinuousDiffEntry], in layout: SnapshotLayout) async -> ClientViewerModel {
    await aLoadedViewerModel(of: entries, holding: [], in: layout)
}

/// The same model with a review already written against it, for the states §7 draws.
///
/// **The layout is here for the highlighter and for nothing else.** The lexer bakes an appearance
/// into what it answers, and `WorktreeDiffScreen` reports the one it is drawing in from a `.task`
/// that a synchronous render never lets finish — so the model is told here instead, and every
/// baseline photographs the palette its own appearance asks for.
/// The same model with a second read of the file list still in flight, which is the state the
/// toolbar reports and the one a reader lands in every time they come back to a worktree.
///
/// **The read is parked rather than released**, because a baseline only needs it to still be
/// running when the shutter opens and a released one would settle into the resting screen this
/// suite already has. **The task comes back with it, and cancelling it is not optional**: a read
/// left open outlives the test, and every suite here shares one window.
@MainActor
func aRefreshingViewerModel(in layout: SnapshotLayout) async -> (ClientViewerModel, Task<Void, Never>) {
    let model = await aLoadedViewerModel(
        of: aChangeSetPartlyArrived,
        holding: [],
        in: layout,
        answeringOnly: 1,
        // Announced at once here, because the threshold is what every *other* baseline in this
        // suite relies on to stay resting — this is the one picture that is about the spinner.
        announcingRefreshAfter: .zero
    )
    let refresh = Task { await model.load() }
    while model.isRefreshing == false {
        await Task.yield()
    }
    return (model, refresh)
}

@MainActor
func aLoadedViewerModel(
    of entries: [ContinuousDiffEntry],
    holding comments: [ReviewComment],
    in layout: SnapshotLayout,
    refusing refusal: ApiFailure? = nil,
    answeringOnly readsAnsweringAtAll: Int = .max,
    announcingRefreshAfter refreshAnnouncementDelay: Duration = UnaskedForRefresh.announcementDelay
) async -> ClientViewerModel {
    let model = ClientViewerModel(
        worktree: WorktreeID(rawValue: "w-the-one-that-was-tapped"),
        macName: "MacBook Pro",
        repository: FakeDiffRepository(
            entries: entries,
            refusing: refusal,
            answeringOnly: readsAnsweringAtAll
        ),
        // In memory rather than this simulator's defaults: a baseline must photograph the same
        // screen on the tenth run as on the first, and a store that persists would carry whatever
        // the last recording wrote into the next one.
        commentStore: FakeReviewCommentStore(holding: comments),
        pasteboard: FakeReviewPasteboard(),
        // **The real lexer, not a fake, which is the only thing that holds highlight.js to
        // answering at all.** `ClientViewerUi` has no unit test target, so without this the one
        // dependency that turns every line of every file a different colour would be exercised by
        // nothing — the shape of a control that looks finished in every layer and does nothing.
        highlighter: theHighlighter,
        copyingLogs: FakeDiagnosticLogsCopying(),
        // Nothing rendered here listens, and a baseline cannot hear anyway — what the sentence says
        // is asserted in `DiffBatchFailureTests` and how often it is said in the model's own suite.
        announcing: SilentDiffReadAnnouncements(),
        // Nothing here waits, so the threshold is never reached and the rows keep their first word.
        // The second one has a subject of its own in the scroll's suite, set directly.
        longWait: DiffFileWait.longWait,
        refreshAnnouncementDelay: refreshAnnouncementDelay
    )
    await model.load()
    await model.reading(0)
    // Xcode's pair, because that is what an unconfigured app draws and every diff baseline in this
    // suite predates the setting. The chooser's own subjects are drawn from `CodeTheme`'s frozen
    // palettes rather than from a lexed model, so no baseline here needs a second theme.
    await model.drawing(in: layout.appearance, themed: .default, at: Double(layout.codePointSize))
    return model
}

/// A renderer has no VoiceOver to talk to, so the announcement goes nowhere here.
struct SilentDiffReadAnnouncements: DiffReadAnnouncing {

    func announce(_ failure: DiffBatchFailure) {}
}

/// One lexer for the whole suite, for the reason the app holds one: building it evaluates the whole
/// highlight.js bundle, and eighty-odd renders would each pay that.
@MainActor
private let theHighlighter = HighlightrSyntaxHighlighter()

/// A review of the first file in `aChangeSetPartlyArrived`, anchored to rows that file really has.
///
/// **It has to be the arrived file**, because a comment cannot attach to a diff that has not landed
/// and a rail cannot be drawn beside rows that are not there — which is the same rule the model
/// enforces and the reason a screen baseline showing a rail cannot use the all-awaiting change set.
///
/// Two comments: a run of three rows and a single row above it, so the header's chip reads 2 and the
/// two rails have a gap between them.
nonisolated let aReviewOfTheFirstFile: [ReviewComment] = [
    ReviewComment(
        anchor: CommentAnchor(
            file: FileID(repositoryRelativePath: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift"),
            first: DiffLinePosition(oldNumber: 138, newNumber: 138),
            last: DiffLinePosition(oldNumber: 138, newNumber: 138)
        ),
        path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
        lines: CommentedLines(side: .new, first: 138, last: 138),
        language: "swift",
        quotedLines: ["    /// Reads the Mac's health before spending anything."],
        text: "This comment is now wrong — it also spends the code."
    ),
    ReviewComment(
        anchor: CommentAnchor(
            file: FileID(repositoryRelativePath: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift"),
            first: DiffLinePosition(oldNumber: 140, newNumber: 140),
            last: DiffLinePosition(oldNumber: 141, newNumber: nil)
        ),
        path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
        lines: CommentedLines(side: .new, first: 140, last: 140),
        language: "swift",
        quotedLines: [
            "\tlet request = Request(path: \"/v1/health\")",
            "        let trust = try await verify(cert)"
        ],
        text: "Take the certificate as a parameter rather than reading it back off the session."
    )
]

/// A row of the first file that really exists, so the instruction bar names something.
nonisolated let aRowOfTheFirstFile = DiffLinePosition(oldNumber: 140, newNumber: 140)

/// The same review with a comment the diff can no longer place.
///
/// **Without this, the amber row was asserted only as a detached component.** Every screen baseline
/// holding a review anchored to rows that resolve, so `ContinuousDiffView`'s own stale branch ran in
/// no test at all — invert the filter or unwire the button and everything stayed green, which is the
/// shape of the defect this repository shipped for eight releases.
nonisolated let aReviewWithOneCommentAdrift: [ReviewComment] = aReviewOfTheFirstFile + [
    ReviewComment(
        anchor: CommentAnchor(
            file: FileID(repositoryRelativePath: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift"),
            first: DiffLinePosition(oldNumber: nil, newNumber: 906),
            last: DiffLinePosition(oldNumber: nil, newNumber: 906)
        ),
        path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
        lines: CommentedLines(side: .new, first: 906, last: 906),
        language: "swift",
        quotedLines: ["    private let session: URLSession"],
        text: "This wants to be injected rather than built here."
    )
]

/// One file in a language the phone's copy of highlight.js does not carry.
///
/// **Not contrived: the two halves are updated separately.** The Mac names a file's language from its
/// extension and the phone lexes with whatever bundle shipped in the app, so a Mac that learned a new
/// extension before the phone did sends a name this build has never heard of. It is also the only one
/// of the highlighter's three refusals a rendered screen can reach — the other two are a JavaScript
/// context that would not build and a lexer that answered with nothing.
nonisolated let aChangeSetTheLexerCannotRead: [ContinuousDiffEntry] = [
    .ready(
        FileDiff(
            file: FileChange(
                id: FileID(repositoryRelativePath: "Sources/render.zig"),
                path: "Sources/render.zig",
                oldPath: nil,
                status: .modified,
                isBinary: false,
                isSubmodule: false,
                stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 1),
                contentHash: String(repeating: "c", count: 64),
                estimatedLineCount: 4,
                isViewed: false,
                isTruncated: false,
                // What a newer Mac would send, and what this bundle cannot lex.
                language: "zig"
            ),
            hunks: [
                Hunk(
                    index: 0,
                    oldStart: 1,
                    oldCount: 3,
                    newStart: 1,
                    newCount: 3,
                    sectionHeading: "pub fn draw",
                    lines: [
                        context(old: 1, new: 1, "pub fn draw(frame: *Frame) void {"),
                        deletion(old: 2, "    frame.clear();"),
                        addition(new: 2, "    frame.clear(.transparent);"),
                        context(old: 3, new: 3, "}")
                    ]
                )
            ],
            oldLineCount: 3,
            newLineCount: 3,
            isTruncated: false,
            truncationReason: nil
        )
    )
]

/// The change set above with every file still on its way, which is what the selector reads from —
/// the file list arrives whole and the diffs follow.
nonisolated let aChangeSetToSelectFrom: [ContinuousDiffEntry] = aChangeSetWorthATree.map(
    ContinuousDiffEntry.awaiting
)
