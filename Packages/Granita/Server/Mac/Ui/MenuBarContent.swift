import ServerApiDomain
import SwiftUI

/// The menu behind the status item. Stateless: it renders what it is handed and reports what was
/// chosen, so the composition root above it owns the server and this owns none of it.
public struct MenuBarContent: View {

    private let state: ServerRunState
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    public init(
        state: ServerRunState,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.state = state
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        // A plain Text in a menu is the platform's status line: present, legible and unclickable.
        Text(statusLine)

        Divider()

        Button("Settings…", action: onOpenSettings)
            .keyboardShortcut(",")

        Divider()

        Button("Quit Granita", action: onQuit)
            .keyboardShortcut("q")
    }

    /// SPEC §9's `host:port`, and what to say in the three cases where there is no such thing.
    private var statusLine: String {
        switch state {
        case .starting: "Starting…"
        case .running(let endpoint): "Serving on \(endpoint.host):\(endpoint.port)"
        case .failed(let reason): "Not serving — \(reason)"
        case .stopped: "Not serving"
        }
    }
}
