import Foundation

/// Asking the person at the Mac to point at a folder.
///
/// A protocol rather than an `NSOpenPanel` call in a view, and the distinction that earns it is that
/// **this one decides**: it comes back with a folder or with nothing, and every caller branches on
/// which. A gesture with an answer is logic, and logic in a view body is logic no test can reach —
/// which is exactly what the coverage gate said about the three call sites that used to be here.
public protocol FolderPicking: Sendable {

    /// The folder the reader chose, or `nil` because they changed their mind.
    ///
    /// A cancelled pick is deliberately not an error and not an event: nothing happened, and nothing
    /// on the tab that asked should move.
    func pickFolder(prompt: String, message: String) async -> URL?
}

/// The one-way things a Settings pane asks the system around it to do.
///
/// None of these answers, which is why they are separate from ``FolderPicking`` — and they are still
/// behind a seam rather than inline, because "did pressing Copy put the address on the pasteboard"
/// is a real question with a real answer, and a view that calls `NSPasteboard` directly is the
/// reason it had no way to be asked.
public protocol SystemGestures: Sendable {

    func copyToPasteboard(_ text: String) async

    /// Finder, with the folder selected rather than opened, which is what "Reveal" means everywhere
    /// else on this machine.
    func revealInFinder(_ url: URL) async

    func openSystemSettings(_ pane: SystemSettingsPane) async
}

/// The panes this app sends a reader to, named rather than spelled.
///
/// Two `x-apple.systempreferences:` URLs used to sit force-unwrapped in a view body. As an enum the
/// spelling lives in one place, in the layer allowed to know it, and the compiler is what stops a
/// third one being added by copying a string.
public enum SystemSettingsPane: Hashable, Sendable {

    /// Privacy & Security › Local Network. Without this, an `NWError` code is the whole explanation
    /// a person gets for an app that does nothing.
    case localNetwork

    case loginItems
}
