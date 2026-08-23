import Foundation
import SwiftUI
import Testing

import ServerMacDomain
import ServerMacUi

/// The sheet a folder scan opens, design §4 — where results wait instead of entering the list.
///
/// **Every state here is photographed, including the ticked one**, and that took moving what is
/// chosen out of the sheet and into the screen that composes it. Held as the sheet's own `@State` it
/// could be changed by nothing but a finger, so the call §4 argues hardest for — the count in the
/// verb, the footer swapping its explanation — had a picture only in the state where the button says
/// `Add` and is grey. A `Ui` view takes what it renders and reports what happened; this is that rule
/// paying for itself.
@Suite("Add repositories sheet")
@MainActor
struct AddRepositoriesSheetSnapshotTests {

    /// A directory URL, with the trailing separator `NSOpenPanel` really hands back — which is the
    /// spelling that put `~/Dev/Projects/Swiftly/` on screen before one formatter took it off again.
    private static let root = URL(filePath: NSHomeDirectory())
        .appending(path: "Developer", directoryHint: .isDirectory)

    struct Subject: Sendable, CustomTestStringConvertible {

        let name: String
        let scan: FolderScan
        /// Which candidates are ticked, by path.
        let chosen: Set<String>

        var testDescription: String { name }

        static let all: [Subject] = [
            // Thirty found and none chosen, which is the reading the whole call exists to produce:
            // thirty things were *found*, and the tab did not grow by thirty rows.
            Subject(
                name: "found-none-chosen",
                scan: .found(root: root, candidates: [
                    candidate("aura", "aura"),
                    candidate("granita", "granita"),
                    candidate("oltre", "oltre"),
                    candidate("scratch", "experiments/scratch"),
                    candidate("swiftly", "swiftly"),
                    candidate("tomorrow", "tomorrow")
                ]),
                chosen: []
            ),
            // Not drawn by the frames, and it has to exist: a home directory is not a development
            // folder, and finding that out with a frozen sheet is the wrong way.
            Subject(name: "looking", scan: .scanning(root: root), chosen: []),
            // Also not drawn. A reader who scans the wrong folder, or one whose repositories are all
            // added already, would otherwise get a sheet with a disabled button and nothing saying
            // why — so the confirm is absent rather than permanently grey.
            Subject(name: "nothing-to-offer", scan: .found(root: root, candidates: []), chosen: []),
            // **The state the frames draw and a baseline could not previously reach**: two ticked,
            // the footer swapping its explanation for `2 chosen of 30`, and the count in the verb.
            // What is ticked used to be the sheet's own `@State`, which nothing but a finger could
            // change — so the one call §4 argues hardest for was photographed only in the state
            // where it says `Add` and is grey.
            Subject(
                name: "two-chosen",
                scan: .found(root: root, candidates: [
                    candidate("aura", "aura"),
                    candidate("granita", "granita"),
                    candidate("oltre", "oltre"),
                    candidate("scratch", "experiments/scratch"),
                    candidate("swiftly", "swiftly"),
                    candidate("tomorrow", "tomorrow")
                ]),
                // Ticked by path, not by name — and one of the two sits at a nested relative path,
                // which is the case the column on the right exists to tell apart.
                chosen: [
                    NSHomeDirectory() + "/Developer/granita",
                    NSHomeDirectory() + "/Developer/experiments/scratch"
                ]
            )
        ]

        private static func candidate(_ name: String, _ relativePath: String) -> RepositoryCandidate {
            RepositoryCandidate(
                path: NSHomeDirectory() + "/Developer/" + relativePath,
                name: name,
                relativePath: relativePath
            )
        }
    }

    @Test(arguments: Subject.all, MacAppearance.all)
    func `given a scan state when the sheet renders then it matches its baseline`(
        subject: Subject,
        appearance: MacAppearance
    ) {
        // given - when - then — hosted at the window's size, because a sheet is seen over the pane
        // it belongs to and its own 520pt width against the window's 620 is a measurement worth
        // holding.
        var chosen = subject.chosen
        assertSettingsSnapshot(
            AddRepositoriesSheet(
                scan: subject.scan,
                chosen: Binding(get: { chosen }, set: { chosen = $0 }),
                onAdd: { _ in },
                onCancel: {}
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity),
            appearance: appearance,
            named: subject.name
        )
    }
}
