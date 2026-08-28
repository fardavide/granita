import ClientConnectionDomain
import ClientViewerDomain
import ClientViewerPresentation
import ClientWorktreesPresentation
import CoreDiffDomain
import Foundation
import SwiftUI

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
private func aChangedFile(
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
struct FakeDiffRepository: GranitaRepository {

    let files: [FileChange]
    let diffs: [FileID: FileDiff]

    init(entries: [ContinuousDiffEntry]) {
        files = entries.map(\.file)
        diffs = Dictionary(
            uniqueKeysWithValues: entries.compactMap { entry in
                guard case .ready(let diff) = entry.content else { return nil }
                return (entry.id, diff)
            }
        )
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        WorktreeChanges(
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
        files.compactMap { diffs[$0] }
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

    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        throw .fileGone
    }
}

/// A viewer model that has already read its change set and fetched the first window.
///
/// **Loaded before the render rather than during it**, which is the difference between a baseline
/// and a race: the diff screen loads from its own `.task`, so a screen handed a fresh model
/// photographs whichever of the spinner and the content won — and the first recording of it caught
/// the spinner. Awaiting here settles the raster, and it is why the two suites that use this are
/// `async`.
@MainActor
func aLoadedViewerModel() async -> ClientViewerModel {
    await aLoadedViewerModel(of: aChangeSetPartlyArrived)
}

@MainActor
func aLoadedViewerModel(of entries: [ContinuousDiffEntry]) async -> ClientViewerModel {
    let model = ClientViewerModel(
        worktree: WorktreeID(rawValue: "w-the-one-that-was-tapped"),
        repository: FakeDiffRepository(entries: entries)
    )
    await model.load()
    await model.reading(0)
    return model
}

/// The change set above with every file still on its way, which is what the selector reads from —
/// the file list arrives whole and the diffs follow.
nonisolated let aChangeSetToSelectFrom: [ContinuousDiffEntry] = aChangeSetWorthATree.map(
    ContinuousDiffEntry.awaiting
)
