import ClientConnectionDomain
import SwiftUI

/// The screen the app opens on before it is paired: what Granita can see on this network.
///
/// Stateless. It renders the state it is handed and reports what was chosen, so it can be put in
/// front of any of the five discovery states — including the two that are hard to reach on demand —
/// without a network, a Mac, or permission being granted.
public struct ServerDiscoveryView: View {

    private let state: DiscoveryState
    private let onSelect: (DiscoveredServer) -> Void
    private let onOpenSettings: () -> Void

    public init(
        state: DiscoveryState,
        onSelect: @escaping (DiscoveredServer) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.state = state
        self.onSelect = onSelect
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        Group {
            switch state {
            case .idle, .searching:
                searching
            case .found(let servers) where servers.isEmpty:
                nothingFound
            case .found(let servers):
                list(of: servers)
            case .localNetworkDenied:
                permissionRefused
            case .failed(let reason):
                failed(reason)
            }
        }
        .navigationTitle("Granita")
    }

    private var searching: some View {
        ContentUnavailableView {
            Label("Looking for your Mac", systemImage: "antenna.radiowaves.left.and.right")
        } description: {
            Text("Granita has to be running on a Mac on this network.")
        }
    }

    private var nothingFound: some View {
        ContentUnavailableView {
            Label("No Mac found", systemImage: "laptopcomputer.slash")
        } description: {
            Text("Check that Granita is running on your Mac, and that both are on the same network.")
        }
    }

    /// The one state the reader can act on, so it is the one that gets a button.
    private var permissionRefused: some View {
        ContentUnavailableView {
            Label("Local network access is off", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Granita finds your Mac over the local network. Without permission it cannot see it at all.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
    }

    private func failed(_ reason: String) -> some View {
        ContentUnavailableView {
            Label("Could not search", systemImage: "exclamationmark.triangle")
        } description: {
            Text(reason)
        }
    }

    private func list(of servers: [DiscoveredServer]) -> some View {
        List(servers) { server in
            Button {
                onSelect(server)
            } label: {
                LabeledContent {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                } label: {
                    Label(server.name, systemImage: "laptopcomputer")
                }
            }
            .buttonStyle(.plain)
        }
    }
}
