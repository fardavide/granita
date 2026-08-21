import ServerApiDomain
import SwiftUI

/// The status item itself — the whole of Granita's presence on the Mac.
///
/// **TRAP.** A `MenuBarExtra` label renders `Text` and `Image` reliably and little else, so the
/// state is a choice of symbol rather than a badge modifier, and the dirty-worktree count will
/// arrive here as a `Text` beside the image for the same reason.
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
        case .failed: "exclamationmark.triangle.fill"
        case .stopped: "pause.circle"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .starting: "Granita, starting"
        case .running: "Granita, serving"
        case .failed: "Granita, not serving"
        case .stopped: "Granita, stopped"
        }
    }
}
