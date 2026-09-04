import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// The file row the diff design review redrew, in the four layouts it has to survive.
///
/// **Seven statuses and two states, and the reason each is here is that a photograph is the only
/// thing that can check them.** The colour a status resolves to is a `switch` a unit test could
/// assert, but whether the 3pt bar is visible against the card in dark mode, whether a 45% row still
/// reads, and whether a middle-truncated module path keeps both of its ends at 320pt are all
/// questions about rendering.
///
/// Main-actor isolated for the reason every suite here is: Swift Testing runs `@Test` functions off
/// the main actor, and rendering touches UIKit view properties that trap when it does.
@Suite("Diff file header", .serialized)
@MainActor
struct DiffFileHeaderSnapshotTests {

    @Test(arguments: FileHeaderCase.all, SnapshotLayout.all)
    func `given a file header when it renders then it matches its baseline`(
        subject: FileHeaderCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            DiffFileHeader(
                file: subject.file,
                commentCount: subject.commentCount,
                onSetOpen: { _, _ in },
                onSetViewed: { _, _ in }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which case it captures, and so a failure names it too.
struct FileHeaderCase: Sendable, CustomTestStringConvertible {

    let name: String
    let file: FileChange

    /// Zero for every case that predates §7, so none of their baselines moves.
    var commentCount = 0

    var testDescription: String { name }

    static let all: [FileHeaderCase] = [
        // The ordinary row: four in five are modified, and it is the one that has to be quiet.
        FileHeaderCase(
            name: "modified",
            file: aChangedFile(
                path: "SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift",
                status: .modified,
                insertions: 1,
                deletions: 1,
                estimatedLineCount: 40
            )
        ),

        // **The trail.** Rule 5 drops a reviewed file to 45% and fills the circle green — and the
        // circle deliberately does *not* dim with the rest, because it is the control for undoing
        // the state it reports.
        FileHeaderCase(
            name: "viewed",
            file: aChangedFile(
                path: "SwiftlyCore/Sources/Common/Utils/GenericError.swift",
                status: .modified,
                insertions: 1,
                deletions: 1,
                estimatedLineCount: 30,
                isViewed: true
            )
        ),

        // The one status that also gets a badge, and the only one whose bar and badge have to agree.
        FileHeaderCase(
            name: "conflicted",
            file: aChangedFile(
                path: "SwiftlyCore/Sources/Common/Utils/Lce.swift",
                status: .conflicted,
                insertions: 4,
                deletions: 2,
                estimatedLineCount: 60
            )
        ),

        // Green, red and indigo, so a rename is never read as an addition — the mistake the indigo
        // exists to prevent.
        FileHeaderCase(
            name: "added",
            file: aChangedFile(
                path: "CurrencyConverter/Domain/SelectedCurrencies.swift",
                status: .added,
                insertions: 32,
                deletions: 0,
                estimatedLineCount: 32
            )
        ),
        FileHeaderCase(
            name: "deleted",
            file: aChangedFile(
                path: "CurrencyConverter/Domain/LegacyExport.swift",
                status: .deleted,
                insertions: 0,
                deletions: 96,
                estimatedLineCount: 96
            )
        ),
        FileHeaderCase(
            name: "renamed",
            file: aChangedFile(
                path: "SwiftlyCore/Sources/Common/Test/Turbine.swift",
                status: .renamed,
                insertions: 95,
                deletions: 3,
                estimatedLineCount: 120,
                oldPath: "SwiftlyCore/Sources/Common/Turbine.swift"
            )
        ),

        // **Modified's own amber, next to a status that is not it.** `typeChanged` shares modified's
        // treatment, so this row and the first must come out identical apart from their paths — and
        // neither may be mistaken for the orange the conflicted row above uses.
        FileHeaderCase(
            name: "type-changed",
            file: aChangedFile(
                path: "Scripts/make-fixture-repo.sh",
                status: .typeChanged,
                insertions: 2,
                deletions: 2,
                estimatedLineCount: 200
            )
        ),

        // Untracked shares added's green: to a reader of uncommitted work the difference is git
        // bookkeeping, and the accessibility label is where it survives.
        FileHeaderCase(
            name: "untracked",
            file: aChangedFile(
                path: "Notes/scratch.md",
                status: .untracked,
                insertions: 8,
                deletions: 0,
                estimatedLineCount: 8
            )
        ),

        // **No second line at all**, which is the empty-directory branch: a file at the repository
        // root has no place to show, and a line that says nothing is worse than no line.
        FileHeaderCase(
            name: "at-the-repository-root",
            file: aChangedFile(
                path: "README.md",
                status: .modified,
                insertions: 12,
                deletions: 3,
                estimatedLineCount: 900
            )
        ),

        // **The review's sixth fault, photographed.** Head truncation rendered this as
        // `…out/Presentation/Models/AboutState.swift` and deleted the module; middle truncation has
        // to keep both `Packages` and `Models` on screen at 320pt.
        FileHeaderCase(
            name: "a-path-too-long-for-any-width",
            file: aChangedFile(
                path: "Packages/Granita/Client/Viewer/Presentation/Models/ContinuousDiffEntry.swift",
                status: .modified,
                insertions: 6,
                deletions: 2,
                estimatedLineCount: 140
            )
        ),

        // **Design §7.3's chip, which is what the rail cannot cover.** Two comments a screen apart in
        // one file are two rails a reader never sees together, so the header carries the count. It
        // sits before the stats rather than after them, because `2 +95 −3` reads as one figure.
        FileHeaderCase(
            name: "carrying-comments",
            file: aChangedFile(
                path: "SwiftlyCore/Sources/Common/Test/Turbine.swift",
                status: .modified,
                insertions: 95,
                deletions: 3,
                estimatedLineCount: 140
            ),
            commentCount: 2
        )
    ]
}
