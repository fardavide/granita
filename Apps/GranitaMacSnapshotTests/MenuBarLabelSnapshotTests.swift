import Testing

import ServerApiDomain
import ServerMacUi

/// The status item, in each of the four states it can be in.
///
/// This is the whole of Granita's presence on the Mac under `LSUIElement`, and the states it draws
/// are otherwise reachable only by breaking something — a refused Bonjour registration or a server
/// that fell over. Here they are values.
///
/// **These baselines pin what ships today, and §1 will move them deliberately.** The design review
/// calls for three symbols rather than four, with failure and stop sharing one, and for a count
/// beside the image; the count has since been measured and dropped. That change lands with the rest
/// of §1, and a re-record is how it will announce itself.
@Suite("Menu bar status item")
@MainActor
struct MenuBarLabelSnapshotTests {

    @Test(arguments: Case.all, MacAppearance.all)
    func `given a server state when the status item renders then it matches its baseline`(
        subject: Case,
        appearance: MacAppearance
    ) {
        // given - when - then
        assertStatusItemSnapshot(
            MenuBarLabel(state: subject.state),
            appearance: appearance,
            named: subject.name
        )
    }

    // MARK: -

    struct Case: Sendable, CustomTestStringConvertible {

        let name: String
        let state: ServerRunState

        var testDescription: String { name }

        static let all: [Case] = [
            Case(name: "starting", state: .starting),
            Case(
                name: "serving",
                state: .running(ServerEndpoint(host: "macbook-pro.local", port: 59_144))
            ),
            Case(name: "failed", state: .failed(reason: "NWError: -65555 PolicyDenied")),
            Case(name: "stopped", state: .stopped)
        ]
    }
}
