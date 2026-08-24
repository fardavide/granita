import Testing

import ServerApiDomain
import ServerMacUi

/// The status item, in each of the four states it can be in.
///
/// This is the whole of Granita's presence on the Mac under `LSUIElement`, and the states it draws
/// are otherwise reachable only by breaking something — a refused Bonjour registration or a server
/// that fell over. Here they are values.
///
/// **Four states, three symbols.** Design §1 gives failure and stop one symbol between them, because
/// the menu bar answers one question — whether the phone can read this Mac — and both are the same
/// answer to it. Both cases stay here rather than one standing in for the other: that they draw the
/// same picture is the assertion, not a duplication.
///
/// The count design §1 draws beside the image is not built. Producing it was measured at 122.7
/// seconds over ten real repositories, which is why the label is the symbol alone.
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
