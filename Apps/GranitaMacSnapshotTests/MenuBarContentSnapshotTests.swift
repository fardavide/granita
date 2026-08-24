import Testing

import ServerApiDomain
import ServerMacUi
import ServerStoreDomain

/// The menu behind the status item — design §1, and under `LSUIElement` the whole app when Settings
/// is shut.
///
/// **Four rows are new here and none of them can be pressed by a test in this repository**, which is
/// exactly the shape of the dead control this project shipped for eight releases. What these
/// baselines can say is which rows exist in each state and what each one says; what they cannot say
/// is whether anything is behind them. That is the Accessibility grant's job and Davide's.
///
/// See `assertMenuSnapshot` for why this is a stack rather than a menu. The short version is that a
/// `MenuBarExtra`'s menu is drawn by AppKit outside this process, so there is nothing to photograph.
@Suite("Menu bar menu")
@MainActor
struct MenuBarContentSnapshotTests {

    @Test(arguments: Case.all, MacAppearance.all)
    func `given a server state when the menu is opened then it matches its baseline`(
        subject: Case,
        appearance: MacAppearance
    ) {
        // given - when - then
        assertMenuSnapshot(
            MenuBarContent(
                state: subject.state,
                onCopyAddress: {},
                onPairDevice: {},
                onOpenLocalNetworkSettings: {},
                onOpenSettings: {},
                onQuit: {}
            ),
            appearance: appearance,
            named: subject.name
        )
    }

    // MARK: -

    struct Case: Sendable, CustomTestStringConvertible {

        let name: String
        let state: ServerRunState

        var testDescription: String { name }

        /// Failed and stopped are both here even though the status item collapses them into one
        /// symbol, because the menu does not: only one of the two offers a way out, and which one
        /// is the part of §1 worth photographing.
        static let all: [Case] = [
            Case(name: "starting", state: .starting),
            Case(
                name: "serving",
                state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144))
            ),
            Case(name: "failed", state: .failed(reason: "NWError: -65555 PolicyDenied")),
            Case(name: "stopped", state: .stopped),
            // The one state whose reason the menu names rather than leaving to Settings: it is a
            // short noun and it is the whole of what a reader has to act on, so there is no small
            // print to leave out and no likely cause to hedge.
            Case(
                name: "blocked-by-another-process",
                state: .blockedByAnotherProcess(
                    StoreLockHolder(processIdentifier: 4213, processName: "granita-server")
                )
            )
        ]
    }
}
