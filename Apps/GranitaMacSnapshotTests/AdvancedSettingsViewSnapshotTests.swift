import Foundation
import Testing

import ServerMacDomain
import ServerMacUi

/// Advanced, design §7 — the rows you set once and the one button you hope never to press.
///
/// **The accent tint is not in any of these**, and one call on this pane turns on it: `Reset All
/// Data…` is deliberately not `.borderedProminent`, because a destructive one-way door should not
/// advertise itself as the thing to press. A Mac baseline renders an inactive window, where
/// prominence draws identically to an ordinary button, so that call is reviewed in the code rather
/// than in a picture. See `decisions.md`.
@Suite("Advanced settings")
@MainActor
struct AdvancedSettingsViewSnapshotTests {

    private static let dataFolder = URL(filePath: NSHomeDirectory())
        .appending(path: "Library/Application Support/Granita", directoryHint: .isDirectory)

    struct Subject: Sendable, CustomTestStringConvertible {

        let name: String
        let git: GitInstallation
        let projectCount: Int
        let deviceCount: Int

        var testDescription: String { name }

        static let all: [Subject] = [
            Subject(
                name: "settled",
                git: .available(version: "2.52.0", path: "/opt/homebrew/bin/git"),
                projectCount: 2,
                deviceCount: 2
            ),
            // A first run, and the state the tab spends most of its life in. `Reset All Data` is
            // still offered rather than disabled: the sentence beside it already says there is
            // nothing to destroy, and a control that greys out is a question a reader then has to
            // answer about why.
            Subject(name: "nothing-stored", git: .checking, projectCount: 0, deviceCount: 0),
            // The failure a reader can act on, and the reason the row runs git rather than
            // reporting the path that won.
            Subject(
                name: "git-cannot-be-run",
                git: .unavailable(reason: "xcrun: error: invalid active developer path"),
                projectCount: 1,
                deviceCount: 1
            ),
            // Apple's git, which names its own build after the version — the suffix is longer than
            // the number and is dropped.
            Subject(
                name: "apple-git",
                git: .available(version: "2.39.5", path: "/usr/bin/git"),
                projectCount: 7,
                deviceCount: 1
            )
        ]
    }

    @Test(arguments: Subject.all, MacAppearance.all)
    func `given an Advanced state when rendering then it matches its baseline`(
        subject: Subject,
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            AdvancedSettingsView(
                git: subject.git,
                dataFolderUrl: Self.dataFolder,
                projectCount: subject.projectCount,
                deviceCount: subject.deviceCount,
                onRevealDataFolder: {},
                onResetAllData: {}
            ),
            appearance: appearance,
            named: subject.name
        )
    }
}
