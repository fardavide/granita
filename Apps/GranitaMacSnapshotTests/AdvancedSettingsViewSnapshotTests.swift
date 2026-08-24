import Foundation
import Testing

import ServerMacDomain
import ServerMacUi
import ServerStoreDomain

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

        /// Both positions of the switch are photographed, and neither costs a baseline of its own:
        /// they ride on states that already exist. A reader with verbose on is a reader looking for
        /// something, which is why it is the git-failure state that carries it.
        let isVerboseLogging: Bool

        /// The lock row, which is drawn only when it is true — so it needs a state of its own
        /// rather than riding on one of the others.
        let storeLockHolder: StoreLockHolder?
        let isBlockedByAnotherProcess: Bool

        var testDescription: String { name }

        static let all: [Subject] = [
            Subject(
                name: "settled",
                git: .available(version: "2.52.0", path: "/opt/homebrew/bin/git"),
                projectCount: 2,
                deviceCount: 2,
                isVerboseLogging: false,
                storeLockHolder: nil,
                isBlockedByAnotherProcess: false
            ),
            // A first run, and the state the tab spends most of its life in. `Reset All Data` is
            // still offered rather than disabled: the sentence beside it already says there is
            // nothing to destroy, and a control that greys out is a question a reader then has to
            // answer about why.
            Subject(
                name: "nothing-stored",
                git: .checking,
                projectCount: 0,
                deviceCount: 0,
                isVerboseLogging: false,
                storeLockHolder: nil,
                isBlockedByAnotherProcess: false
            ),
            // The failure a reader can act on, and the reason the row runs git rather than
            // reporting the path that won.
            Subject(
                name: "git-cannot-be-run",
                git: .unavailable(reason: "xcrun: error: invalid active developer path"),
                projectCount: 1,
                deviceCount: 1,
                isVerboseLogging: true,
                storeLockHolder: nil,
                isBlockedByAnotherProcess: false
            ),
            // Apple's git, which names its own build after the version — the suffix is longer than
            // the number and is dropped.
            Subject(
                name: "apple-git",
                git: .available(version: "2.39.5", path: "/usr/bin/git"),
                projectCount: 7,
                deviceCount: 1,
                isVerboseLogging: false,
                storeLockHolder: nil,
                isBlockedByAnotherProcess: false
            ),
            // SPEC §9's refusal, which is the only state on this tab where the rest of the app is
            // doing nothing at all. It needs a picture of its own because the row is drawn only
            // when it is true — riding on another state would photograph its absence.
            Subject(
                name: "blocked-by-another-process",
                git: .available(version: "2.52.0", path: "/opt/homebrew/bin/git"),
                projectCount: 2,
                deviceCount: 2,
                isVerboseLogging: false,
                storeLockHolder: StoreLockHolder(processIdentifier: 4213, processName: "granita-server"),
                isBlockedByAnotherProcess: true
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
                isVerboseLogging: subject.isVerboseLogging,
                isBlockedByAnotherProcess: subject.isBlockedByAnotherProcess,
                storeLockHolder: subject.storeLockHolder,
                onSetVerboseLogging: { _ in },
                onOpenLogInConsole: {},
                onRevealDataFolder: {},
                onResetAllData: {}
            ),
            appearance: appearance,
            named: subject.name
        )
    }
}
