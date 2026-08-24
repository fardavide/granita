import ServerApiDomain
import SwiftUI

/// The status item itself — the whole of Granita's presence on the Mac.
///
/// **TRAP.** A `MenuBarExtra` label renders `Text` and `Image` reliably and little else, so the
/// state is a choice of symbol rather than a badge modifier. SPEC §9's count beside the icon would
/// arrive as a `Text` here for the same reason, and design §1 defers it rather than dropping it:
/// producing the number was measured at **122.7 seconds** over ten real repositories, so a menu that
/// computed it on open is a menu that does not open.
///
/// **Four states, three symbols, and that is design §1's call rather than an economy.** The menu bar
/// answers one question — whether the phone can read this Mac — and failure and stop are the same
/// answer to it. Which of the two it was is one click below, on General, where there is room for the
/// diagnostic beside it. Rejected there: `pause.circle` for stopped, because it offers a play button
/// this app does not have; and a coloured dot, because a status item image is template-tinted by the
/// system and cannot be relied on to stay red.
public struct MenuBarLabel: View {

    private let state: ServerRunState

    public init(state: ServerRunState) {
        self.state = state
    }

    public var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel(accessibilityLabel)
    }

    private var symbolName: String {
        switch state {
        case .starting: "hourglass"
        case .running: "arrow.trianglehead.branch"
        // Unfilled, like every other warning this app draws. A filled triangle in a menu bar reads
        // as an alert that has already gone off, next to a clock and a Wi-Fi symbol that never do.
        // A blocked lock joins them rather than earning a fourth symbol: three symbols are one
        // answer to the one question a menu bar asks, and "not serving" is the true answer to it
        // here too. Which of the three reasons it is belongs one click below.
        case .failed, .stopped, .blockedByAnotherProcess: "exclamationmark.triangle"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .starting: "Granita, starting"
        case .running: "Granita, serving"
        case .failed, .stopped, .blockedByAnotherProcess: "Granita, not serving"
        }
    }
}
