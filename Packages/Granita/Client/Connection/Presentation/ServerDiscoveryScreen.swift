import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionUi

/// Binds the discovery view model to the view.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
public struct ServerDiscoveryScreen: View {

    @State private var viewModel: ServerDiscoveryViewModel

    public init(viewModel: ServerDiscoveryViewModel) {
        // Pinned in @State rather than held as a plain `let`: the composition root rebuilds this
        // screen on every parent re-evaluation, and a plain property would swap the displayed model
        // while the running .task kept driving the discarded one.
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ServerDiscoveryView(
            state: viewModel.state,
            onSearchAgain: viewModel.searchAgain,
            onOpenSettings: openSettings
        )
        // Keyed on the attempt so that searching again is a *new browser* rather than a new reading
        // of the dead one: SwiftUI cancels the running task, which tears the browse down, and starts
        // this one over. A dead browser is dead for good, and Search Again is tapped precisely when
        // the reader has one.
        .task(id: viewModel.attempt) { await viewModel.start() }
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
