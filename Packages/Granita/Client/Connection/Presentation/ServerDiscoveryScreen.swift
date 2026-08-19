import ClientConnectionDomain
import ClientConnectionUi
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Binds the discovery view model to the view.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
public struct ServerDiscoveryScreen: View {

    @State private var viewModel: ServerDiscoveryViewModel
    private let onSelect: (DiscoveredServer) -> Void

    public init(
        viewModel: ServerDiscoveryViewModel,
        onSelect: @escaping (DiscoveredServer) -> Void
    ) {
        // Pinned in @State rather than held as a plain `let`: the composition root rebuilds this
        // screen on every parent re-evaluation, and a plain property would swap the displayed model
        // while the running .task kept driving the discarded one.
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        ServerDiscoveryView(
            state: viewModel.state,
            onSelect: onSelect,
            onOpenSettings: openSettings
        )
        .task { await viewModel.start() }
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
