import SwiftUI

/// The menu behind the status item. Stateless: it renders what it is handed and reports what was
/// chosen, so the composition root above it owns the server and this owns none of it.
public struct MenuBarContent: View {

    private let onQuit: () -> Void

    public init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
    }

    public var body: some View {
        Button("Quit Granita", action: onQuit)
            .keyboardShortcut("q")
    }
}
