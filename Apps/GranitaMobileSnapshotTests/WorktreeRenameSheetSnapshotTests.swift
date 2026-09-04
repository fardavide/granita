import ClientWorktreesDomain
import ClientWorktreesUi
import CoreDiffDomain
import SwiftUI
import Testing

/// The rename sheet, in each of the situations its footer has a different answer for.
///
/// Rendered directly rather than presented: a hosted view presents a sheet into a window of its own
/// and the raster does not include it, so a baseline of the presenting screen would be a picture of
/// the list with nothing on top of it.
@Suite("Worktree rename sheet", .serialized)
@MainActor
struct WorktreeRenameSheetSnapshotTests {

    @Test(arguments: RenameCase.all, SnapshotLayout.all)
    func `given a rename subject when rendering then it matches its baseline`(
        subject: RenameCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            WorktreeRenameSheet(subject: subject.subject, onSave: { _ in }, onCancel: {}),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct RenameCase: Sendable, CustomTestStringConvertible {

    let name: String
    let subject: WorktreeRenameSubject

    var testDescription: String { name }

    static let all: [RenameCase] = [
        // No alias yet and a session to offer. The field is empty, so the footer says what the row
        // will fall back to — and the placeholder is that same string, so the empty field looks like
        // the result it will produce.
        RenameCase(
            name: "a-suggestion-exists",
            subject: WorktreeRenameSubject(
                worktree: WorktreeID(rawValue: "w-tls"),
                alias: nil,
                suggestedAlias: "Add TLS certificate pinning to the pairing handshake",
                derivedName: "Add TLS certificate pinning to the pairing handshake",
                derivedNameSource: .sessionSuggestion
            )
        ),

        // An alias the reader set, over a session that is still there. The footer changes to the
        // undo sentence because the field is not empty — which is the whole of what "clearing needs
        // no destructive button" rests on.
        RenameCase(
            name: "undoing-an-alias",
            subject: WorktreeRenameSubject(
                worktree: WorktreeID(rawValue: "w-tls"),
                alias: "TLS pinning",
                suggestedAlias: "Add TLS certificate pinning to the pairing handshake",
                derivedName: "Add TLS certificate pinning to the pairing handshake",
                derivedNameSource: .sessionSuggestion
            )
        ),

        // Nothing to suggest and no branch either. The section is absent and the footer says why, in
        // the reader's terms, which is what turns an empty sheet into an explanation.
        RenameCase(
            name: "nothing-to-suggest",
            subject: WorktreeRenameSubject(
                worktree: WorktreeID(rawValue: "w-bridge"),
                alias: nil,
                suggestedAlias: nil,
                derivedName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
                derivedNameSource: .directory
            )
        ),

        // No session, but there is a branch — a different explanation from the one above, and the
        // ordinary case for a worktree an agent has not written a summary in.
        RenameCase(
            name: "named-by-its-branch",
            subject: WorktreeRenameSubject(
                worktree: WorktreeID(rawValue: "w-session"),
                alias: nil,
                suggestedAlias: nil,
                derivedName: "feat/session-index",
                derivedNameSource: .branch
            )
        )
    ]
}
