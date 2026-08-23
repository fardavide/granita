import Foundation
import SwiftUI
import Testing

import ServerMacDomain
import ServerMacUi

/// The sheet a folder scan opens, design §4 — where results wait instead of entering the list.
///
/// The state that cannot be photographed is the one with candidates ticked: what is chosen is the
/// sheet's own `@State` and a baseline renders a view that nothing has clicked. So `Add 2
/// Repositories`, the count in the verb, and the footer swapping the explanation for `2 chosen of
/// 30` are reviewed in the code. What these hold is the shape around them, and the two states the
/// frames do not draw at all.
@Suite("Add repositories sheet")
@MainActor
struct AddRepositoriesSheetSnapshotTests {

    private static let root = URL(filePath: NSHomeDirectory()).appending(path: "Developer")

    struct Subject: Sendable, CustomTestStringConvertible {

        let name: String
        let scan: FolderScan

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
                ])
            ),
            // Not drawn by the frames, and it has to exist: a home directory is not a development
            // folder, and finding that out with a frozen sheet is the wrong way.
            Subject(name: "looking", scan: .scanning(root: root)),
            // Also not drawn. A reader who scans the wrong folder, or one whose repositories are all
            // added already, would otherwise get a sheet with a disabled button and nothing saying
            // why — so the confirm is absent rather than permanently grey.
            Subject(name: "nothing-to-offer", scan: .found(root: root, candidates: []))
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
        assertSettingsSnapshot(
            AddRepositoriesSheet(scan: subject.scan, onAdd: { _ in }, onCancel: {})
                .frame(maxWidth: .infinity, maxHeight: .infinity),
            appearance: appearance,
            named: subject.name
        )
    }
}
