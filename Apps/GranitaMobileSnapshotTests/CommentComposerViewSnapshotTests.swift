import ClientViewerDomain
import ClientViewerUi
import SwiftUI
import Testing

/// Design §7.2's composer, in the three states a reader can land in.
///
/// **Rendered directly rather than through the sheet that presents it**, and that is a limit worth
/// stating: a hosted view presents a sheet into its own window and the raster does not include it, so
/// the 300pt detent, the grabber and the background interaction are not photographable at all. What
/// these hold is the composer's own contents — which is the half that can be wrong in a way a reader
/// would notice.
///
/// Main-actor isolated, and it must be: rendering touches UIKit view properties, and doing that off
/// the main actor traps in a way that restarts the test host and reports "0 tests passed".
@Suite("Comment composer", .serialized)
@MainActor
struct CommentComposerViewSnapshotTests {

    @Test(arguments: ComposerCase.all, SnapshotLayout.all)
    func `given a composer state when it renders then it matches its baseline`(
        subject: ComposerCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            CommentComposerView(
                anchorLabel: subject.anchorLabel,
                excerpt: subject.excerpt,
                isEditing: subject.isEditing,
                text: .constant(subject.text),
                onCancel: {},
                onSave: {},
                onDelete: {}
            )
            // The height the sheet would give it, so the baseline is the shape a reader sees rather
            // than the shape a view takes when nothing constrains it.
            .frame(height: CommentComposerView.detentHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct ComposerCase: Sendable, CustomTestStringConvertible {

    let name: String
    let anchorLabel: String
    let quoted: [(Int, String)]
    let isEditing: Bool
    let text: String

    var testDescription: String { name }

    /// The rows as the composer takes them, numbers and all.
    var excerpt: [ExcerptLine] {
        quoted.map { ExcerptLine(number: $0.0, text: $0.1) }
    }

    static let all: [ComposerCase] = [
        // A new comment on a run of four. The excerpt is three rows and a count, which is the
        // receipt for an 18pt aim: a reader who landed one row off can see it here, before they
        // type, rather than on the Mac afterwards.
        ComposerCase(
            name: "a-new-comment",
            anchorLabel: "Turbine.swift:41-44",
            quoted: [
                (41, "func awaitItem() async throws -> Element {"),
                (42, "  try await withTimeout(.seconds(1)) {"),
                (43, "    try await self.awaitNext()"),
                (44, "  }")
            ],
            isEditing: false,
            text: ""
        ),

        // **The same sheet with one row added**, which is design §7.2's rule: Delete exists only for
        // a comment that already does. On a new one there is nothing to delete and Cancel is the
        // answer.
        ComposerCase(
            name: "an-existing-comment",
            anchorLabel: "Lce.swift:8",
            quoted: [(8, "extension Lce: Sendable where C: Sendable, E: Sendable {}")],
            isEditing: true,
            text: "This is unconditional. C and E are already constrained, so drop the where clause."
        ),

        // **Longer than the sheet, and the sheet does not grow.** The field scrolls inside its own
        // frame with the anchor pinned above it, because the one thing a reader must never lose sight
        // of while writing is which lines they are writing about.
        ComposerCase(
            name: "a-comment-longer-than-the-sheet",
            anchorLabel: "Turbine.swift:41-44",
            quoted: [
                (41, "func awaitItem() async throws -> Element {"),
                (42, "  try await withTimeout(.seconds(1)) {"),
                (43, "    try await self.awaitNext()"),
                (44, "  }")
            ],
            isEditing: true,
            text: """
                Take the timeout as a parameter and default it to five. One second is too short for \
                CI. The three call sites in this file all pass a literal, so the change is mechanical. \
                While you are here: awaitNext() swallows cancellation, which is why the timeout looks \
                like it works.
                """
        ),

        // **A run of seven, which is the only subject that draws the plural.** Three rows and a
        // count is the shape §7.2 specifies, and the count was `+1 more line` in every other case
        // here — so `+N more lines` was a string this app had never rendered on any screen or in any
        // baseline, on an ordinary selection the design names by hand.
        ComposerCase(
            name: "a-run-longer-than-the-excerpt",
            anchorLabel: "Turbine.swift:41-47",
            quoted: [
                (41, "func awaitItem() async throws -> Element {"),
                (42, "  try await withTimeout(.seconds(1)) {"),
                (43, "    try await self.awaitNext()"),
                (44, "  }"),
                (45, "}"),
                (46, ""),
                (47, "func expectNoItems() async throws {")
            ],
            isEditing: false,
            text: ""
        )
    ]
}
