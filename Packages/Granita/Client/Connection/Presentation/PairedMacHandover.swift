import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionDomain

extension View {

    /// Hands a pairing that worked to whatever replaces the pairing screens, and marks the moment.
    ///
    /// **It goes on the screen that is on top, and never on the one underneath.** That is the whole
    /// of what this file is for. `onChange` is scoped to a view's appearance rather than to its
    /// lifetime: a pushed-over screen keeps having its body evaluated — so the tracking looks alive,
    /// and in a debugger it is — while every `onChange` on it has been dead since `onDisappear`.
    ///
    /// 0.1.0 put the watch on the Mac's own screen because that screen sits under all three of the
    /// others and therefore sees every path. Being underneath is exactly what stopped it working: by
    /// the time a pairing can succeed, the viewfinder or the six-word screen is over it. The Mac
    /// issued a token, the phone stored it, the model reached the ending — and the reader was left on
    /// a spinner, on both paths, with no screen behind it and nothing to press. See
    /// `.claude/docs/decisions.md`.
    ///
    /// So: the two screens that can be frontmost when a credential is spent apply this, and no
    /// screen beneath them watches for anything.
    func handsOverAPairedMac(
        from pairing: PairingState,
        to onPaired: @escaping (PairedMac) -> Void
    ) -> some View {
        modifier(PairedMacHandover(pairing: pairing, onPaired: onPaired))
    }
}

// MARK: -

private struct PairedMacHandover: ViewModifier {

    let pairing: PairingState
    let onPaired: (PairedMac) -> Void

    func body(content: Content) -> some View {
        content
            // `initial` because a screen can arrive with the ending already on it: the viewfinder
            // replaces itself the instant a spend finishes, so what the next screen gets is a state
            // that has stopped changing. Without it the handover would work on the six-word path and
            // silently not on the scanned one, which is the shape of defect this file exists to end.
            .onChange(of: pairing, initial: true) { _, pairing in
                guard let mac = pairing.pairedMac else { return }
                announceThePairing()
                onPaired(mac)
            }
    }

    /// The whole of the celebration, and the only haptic in the app.
    ///
    /// Silence reads as nothing having happened, and everything else that marks this moment is the
    /// destination resembling the origin: a viewfinder becomes a populated list.
    private func announceThePairing() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
