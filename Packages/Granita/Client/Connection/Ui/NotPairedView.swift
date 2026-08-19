import SwiftUI

/// The state the app is in before it has been paired with a Mac. It is the first thing a new
/// install shows, and it stays reachable from settings after every device is revoked.
///
/// A `Ui` view takes what it needs and reports what happened; it owns no state beyond the view's
/// own, so a `Presentation` type can place it without inheriting anything.
public struct NotPairedView: View {

    private let onStartPairing: () -> Void

    public init(onStartPairing: @escaping () -> Void) {
        self.onStartPairing = onStartPairing
    }

    public var body: some View {
        ContentUnavailableView {
            Label("No Mac paired", systemImage: "laptopcomputer.slash")
        } description: {
            Text("Scan the pairing code from Granita on your Mac to start reviewing.")
        } actions: {
            Button("Scan pairing code", action: onStartPairing)
        }
    }
}
