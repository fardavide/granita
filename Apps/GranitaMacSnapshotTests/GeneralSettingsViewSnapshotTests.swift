import Foundation
import Testing

import ServerApiDomain
import ServerMacDomain
import ServerMacUi
import ServerStoreDomain

/// Every state the General tab can be in, in both appearances.
///
/// The Mac had no snapshot kind at all until this file, which meant every Settings surface was code
/// that nothing rendered — and the frames it is built from were drawn at 1:1 precisely so they could
/// become these baselines. Without them, "we built the design" is an assertion nobody can check.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor,
/// and hosting a SwiftUI view touches AppKit view properties from whichever thread it lands on.
@Suite("General settings tab")
@MainActor
struct GeneralSettingsViewSnapshotTests {

    @Test(arguments: Case.all, MacAppearance.all)
    func `given a General state when rendering then it matches its baseline`(
        subject: Case,
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            GeneralSettingsView(
                state: subject.state,
                servingSince: subject.servingSince,
                loginItem: subject.loginItem,
                opensAtLogin: .constant(subject.loginItem == .on),
                onCopyAddress: { _ in },
                onRestart: {},
                onOpenLocalNetworkSettings: {},
                onOpenLoginItems: {},
                onQuit: {}
            ),
            appearance: appearance,
            named: subject.name
        )
    }

    // MARK: -

    /// The states worth a picture, which are the ones a reader cannot produce on demand.
    struct Case: Sendable, CustomTestStringConvertible {

        let name: String
        let state: ServerRunState
        let servingSince: Date?
        let loginItem: LoginItemState

        var testDescription: String { name }

        static let all: [Case] = [
            // The ordinary one, and the only one where the address row has anything in it.
            Case(
                name: "serving",
                state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144)),
                servingSince: .nineTwelve,
                loginItem: .on
            ),
            Case(
                name: "serving-not-at-login",
                state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144)),
                servingSince: .nineTwelve,
                loginItem: .off
            ),
            Case(
                name: "starting",
                state: .starting,
                servingSince: nil,
                loginItem: .off
            ),
            // The failure this app is most likely to hit on a machine that has never run it, and
            // the reason the tab has a button at all: without one, an NWError code is the whole
            // explanation a person gets for an app that does nothing.
            Case(
                name: "not-serving",
                state: .failed(reason: "NWError: -65555 PolicyDenied · nw_listener"),
                servingSince: nil,
                loginItem: .on
            ),
            // The ordinary first-run outcome of the toggle, and the one most easily mistaken for
            // success — `register()` returns without throwing and nothing starts at the next login.
            Case(
                name: "login-awaiting-approval",
                state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144)),
                servingSince: .nineTwelve,
                loginItem: .awaitingApproval
            ),
            Case(
                name: "login-refused",
                state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144)),
                servingSince: .nineTwelve,
                loginItem: .refused(reason: "Operation not permitted")
            ),
            // SPEC §9's lock, and the reason it is a state of its own rather than a `failed`
            // carrying a different sentence: this is the one picture in the set where the advice is
            // not Local Network access, and where the button ends the app rather than retrying it.
            Case(
                name: "blocked-by-another-process",
                state: .blockedByAnotherProcess(
                    StoreLockHolder(processIdentifier: 4213, processName: "granita-server")
                ),
                servingSince: nil,
                loginItem: .on
            ),
            // The same refusal with nobody named. Whether the lock is taken is the kernel's answer
            // and who has it is read from a file beside it, so this is the state where the second
            // is lost and the first still stands.
            Case(
                name: "blocked-by-an-unreadable-process",
                state: .blockedByAnotherProcess(nil),
                servingSince: nil,
                loginItem: .on
            )
        ]
    }
}

// MARK: -

private extension Date {

    /// The time the frames are drawn at, fixed so a baseline does not change every minute.
    static let nineTwelve = Date(timeIntervalSince1970: 1_755_853_920)
}
