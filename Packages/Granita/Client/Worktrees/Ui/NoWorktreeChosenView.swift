import SwiftUI

/// What the iPad's detail column says while no worktree has been chosen.
///
/// An unavailable-content view, which is design §2's own instruction rather than a convenience:
/// "the empty detail column is an unavailable-content view, the same control as every other empty
/// state in the app". A column left blank reads as a screen that failed to load, and the one thing
/// the reader needs to know here is that the next tap belongs to the list beside it.
///
/// **The phone never draws this.** A split view in a compact width collapses to its sidebar, so
/// this is the iPad's half of §2 and nothing else.
public struct NoWorktreeChosenView: View {

    public init() {}

    public var body: some View {
        ContentUnavailableView {
            // The leading spelling rather than `sidebar.left`, so the glyph points at the list in a
            // right-to-left layout too — where the list is on the other side.
            Label("Choose a worktree", systemImage: "sidebar.leading")
        } description: {
            // No action, and no promise about what opens. A button here would either duplicate a row
            // or choose for the reader, and a sentence describing the diff would describe a screen
            // design §3 has not built yet.
            Text("Pick one from the list to open it.")
        }
    }
}
