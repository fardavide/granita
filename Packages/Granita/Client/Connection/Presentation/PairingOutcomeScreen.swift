import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionDomain
import ClientConnectionUi

/// What a spent credential came to, bound to the two retries that are not the same act.
///
/// **Going back is refused while either of them is in flight.** A code that works once must not be
/// abandonable halfway, and neither must the key it bought — the viewfinder hides its back button
/// for the first of those and this screen is where the second one happens.
struct PairingOutcomeScreen: View {

    private let model: ClientConnectionModel
    private let server: DiscoveredServer
    private let phone: ThisPhone
    private let onPaired: (PairedMac) -> Void

    init(
        model: ClientConnectionModel,
        server: DiscoveredServer,
        phone: ThisPhone,
        onPaired: @escaping (PairedMac) -> Void
    ) {
        self.model = model
        self.server = server
        self.phone = phone
        self.onPaired = onPaired
    }

    var body: some View {
        PairingOutcomeView(
            macName: server.name,
            state: model.pairing,
            canOpenTestFlight: canOpenTestFlight,
            // **The Mac goes with the tap**, which is the whole of what this screen knows that the
            // model cannot: one model serves the app, and what it is still holding may belong to a
            // machine the reader walked away from two screens ago.
            onTryAgain: { Task { await model.spendAgain(on: server, as: phone.device) } },
            onSaveTokenAgain: { Task { await model.saveTokenAgain() } },
            onOpenTestFlight: openTestFlight,
            onOpenSettings: openSettings
        )
        #if !os(macOS)
        .navigationBarBackButtonHidden(model.pairing == .spending || model.pairing == .savingToken)
        #endif
        // **Success has no screen, and this screen is what a spend is pushed in front of.** The
        // six-word path pushes it before the code leaves, and both retries happen on it, so it is
        // frontmost for every ending that is not the scanner's. See `PairedMacHandover`.
        .handsOverAPairedMac(from: model.pairing, to: onPaired)
    }

    /// Whether there is an app to leave for.
    ///
    /// Asked of the system rather than answered here, because it is a question only a device can
    /// answer — and it turns an unanswerable one into this project's own rule: a control ships if it
    /// works or is absent, and a reader with no TestFlight is missing nothing, since the sentence
    /// above the button already says what to do.
    private var canOpenTestFlight: Bool {
        #if canImport(UIKit)
        guard let testFlight else { return false }
        return UIApplication.shared.canOpenURL(testFlight)
        #else
        return false
        #endif
    }

    private func openTestFlight() {
        #if canImport(UIKit)
        guard let testFlight else { return }
        UIApplication.shared.open(testFlight)
        #endif
    }
}

// MARK: -

/// TestFlight's own scheme, with nothing after it: this build knows which app it is and does not
/// know its App Store identifier, so what it can honestly ask for is the app that holds the newer
/// build rather than a page inside it. Reaching it at all needs the scheme declared in the
/// property list, which is what makes `canOpenURL` above answer anything but `false`.
private let testFlight = URL(string: "itms-beta://")
