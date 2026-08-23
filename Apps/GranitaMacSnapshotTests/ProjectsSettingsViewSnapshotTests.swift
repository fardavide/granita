import Foundation
import Testing

import CoreDiffDomain
import ServerMacDomain
import ServerMacUi

/// Projects, design §4 — the security boundary, and the only tab whose controls change what a phone
/// can read.
///
/// **The accent tint is in none of these**, and two calls on this pane turn on it: `Add Repository…`
/// is `.borderedProminent` in the empty state and a switched-on `Toggle` shows a tinted track. A Mac
/// baseline renders an inactive window, where both draw grey, so those two are reviewed in the code.
/// See `decisions.md`.
@Suite("Projects settings")
@MainActor
struct ProjectsSettingsViewSnapshotTests {

    struct Subject: Sendable, CustomTestStringConvertible {

        let name: String
        let projects: [ManagedProject]
        let failure: ProjectsFailure?

        var testDescription: String { name }

        static let all: [Subject] = [
            // The first run, and the state the whole product does nothing in. Both verbs are offered
            // once each.
            Subject(name: "nothing-added", projects: [], failure: nil),
            // The three rows the frames draw: one switched on with its figure complete, one added
            // and off, and one whose folder moved.
            Subject(
                name: "settled",
                projects: [
                    project(name: "granita", path: "/Developer/granita", isVisible: true,
                            contents: .worktrees(count: 4), changes: .counted(2)),
                    project(name: "oltre", path: "/Developer/oltre", isVisible: false,
                            contents: .worktrees(count: 2), changes: .counting),
                    project(name: "aura", path: "/Developer/aura", isVisible: true,
                            contents: .folderNotFound, changes: .counting)
                ],
                failure: nil
            ),
            // The moment after the tab opens, which on ten real repositories lasts a while. The
            // second line is drawn rather than absent, so nothing below it moves when it arrives.
            Subject(
                name: "still-counting",
                projects: [
                    project(name: "granita", path: "/Developer/granita", isVisible: true,
                            contents: .worktrees(count: 4), changes: .counting),
                    project(name: "bandlab-android", path: "/Developer/bandlab-android", isVisible: true,
                            contents: .worktrees(count: 16), changes: .counted(0))
                ],
                failure: nil
            ),
            // A folder still there and no longer a checkout, which `Locate…` cannot fix and which is
            // therefore worded differently from a folder that moved.
            Subject(
                name: "not-a-repository",
                projects: [
                    project(name: "notes", path: "/Developer/notes", isVisible: false,
                            contents: .notARepository, changes: .counting)
                ],
                failure: nil
            ),
            // Nothing was written. Our sentence, the system's underneath — the same idiom General's
            // refused login item uses, and the reason a switch never springs back in silence.
            Subject(
                name: "refused",
                projects: [
                    project(name: "granita", path: "/Developer/granita", isVisible: false,
                            contents: .worktrees(count: 4), changes: .counting)
                ],
                failure: ProjectsFailure(
                    sentence: "That change could not be saved.",
                    reason: "No space left on device"
                )
            )
        ]

        private static func project(
            name: String,
            path: String,
            isVisible: Bool,
            contents: ProjectContents,
            changes: WorktreesWithChanges
        ) -> ManagedProject {
            ManagedProject(
                id: ProjectID(canonicalPath: path),
                name: name,
                path: NSHomeDirectory() + path,
                isVisible: isVisible,
                contents: contents,
                worktreesWithChanges: changes
            )
        }
    }

    @Test(arguments: Subject.all, MacAppearance.all)
    func `given a Projects state when rendering then it matches its baseline`(
        subject: Subject,
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            ProjectsSettingsView(
                projects: subject.projects,
                failure: subject.failure,
                onSetVisible: { _, _ in },
                onAddRepository: {},
                onScanFolder: {},
                onRemove: { _ in },
                onLocate: { _ in }
            ),
            appearance: appearance,
            named: subject.name
        )
    }
}
