import SwiftUI

import ClientConnectionDomain
import ClientMacDomain
import CoreComponentsUi

/// The shipped source choices and recovery actions, shared with the menu's snapshot subjects.
public struct MacSourceMenuContentView: View {
    private let source: ReaderSource
    private let menu: MacSourceMenu
    private let remembered: Set<BonjourInstanceName>
    private let logCopyState: DiagnosticCopyState
    private let onChoose: (ReaderSource) -> Void
    private let onSearchAgain: () -> Void
    private let onOpenSettings: () -> Void
    private let onCopyLogs: () -> Void

    public init(
        source: ReaderSource,
        menu: MacSourceMenu,
        remembered: Set<BonjourInstanceName>,
        logCopyState: DiagnosticCopyState,
        onChoose: @escaping (ReaderSource) -> Void,
        onSearchAgain: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.source = source
        self.menu = menu
        self.remembered = remembered
        self.logCopyState = logCopyState
        self.onChoose = onChoose
        self.onSearchAgain = onSearchAgain
        self.onOpenSettings = onOpenSettings
        self.onCopyLogs = onCopyLogs
    }

    public var body: some View {
        Toggle(isOn: Binding(get: { source == .thisMac }, set: { _ in onChoose(.thisMac) })) {
            VStack(alignment: .leading) {
                Label("This Mac", systemImage: "laptopcomputer")
                Text("Read on this Mac, without the network").font(.caption)
            }
        }
        Divider()
        Text("Other Macs").foregroundStyle(.secondary)
        ForEach(menu.servers) { server in
            Toggle(isOn: Binding(
                get: { source == .remote(server) },
                set: { _ in onChoose(.remote(server)) }
            )) {
                Label(remembered.contains(server.id) ? server.name : "\(server.name)…", systemImage: "laptopcomputer")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        switch menu.status {
        case .idle, .searching:
            Text("Looking for other Macs on this network…").foregroundStyle(.secondary)
        case .found(let servers) where servers.isEmpty:
            Text("No other Mac found on this network").foregroundStyle(.secondary)
            Button("Search Again", action: onSearchAgain)
        case .found:
            EmptyView()
        case .localNetworkDenied:
            Text("Local network access is off for Granita").foregroundStyle(.secondary)
            Button("Open Local Network Settings…", action: onOpenSettings)
        case .failed:
            Text("Could not search for other Macs").foregroundStyle(.secondary)
            Button("Try Again", action: onSearchAgain)
            ErrorReportAction(state: reportState, onCopyLogs: onCopyLogs)
        }
    }

    private var reportState: ErrorReportAction.State {
        switch logCopyState {
        case .ready: .ready
        case .copying: .copying
        case .copied: .copied
        case .failed: .failed
        }
    }
}
