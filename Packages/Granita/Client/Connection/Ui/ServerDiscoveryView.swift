import SwiftUI

import ClientConnectionDomain

/// The screen the app opens on before it is paired: what Granita can see on this network.
///
/// Stateless. It renders the state it is handed and reports what the reader asked for, so it can be
/// put in front of any of the six discovery states — including the two that are hard to reach on
/// demand — without a network, a Mac, or permission being granted.
///
/// Selecting a Mac is a value-based navigation link rather than a callback: the link supplies the
/// disclosure indicator, pins it to the trailing edge at every type size, and draws no chevron at
/// all once this list becomes a split-view sidebar. The destination arrives with pairing.
public struct ServerDiscoveryView: View {

    @Environment(\.accessibilityReduceMotion) public var reduceMotion

    private let state: DiscoveryState
    private let logCopyState: DiagnosticCopyState
    private let onSearchAgain: () -> Void
    private let onOpenSettings: () -> Void
    private let onCopyLogs: () -> Void

    public init(
        state: DiscoveryState,
        logCopyState: DiagnosticCopyState,
        onSearchAgain: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.state = state
        self.logCopyState = logCopyState
        self.onSearchAgain = onSearchAgain
        self.onOpenSettings = onOpenSettings
        self.onCopyLogs = onCopyLogs
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
            case .failed:
                failed
            }
        }
        .navigationTitle("Granita")
        .animation(reduceMotion ? nil : .default, value: logCopyState)
    }

    /// No spinner: a progress view promises a finish, and Bonjour has none. The symbol's motion is
    /// the progress indicator, and arriving at a *static* symbol is what says searching stopped —
    /// which is the only thing distinguishing this screen from the one below it at a glance.
    private var searching: some View {
        ContentUnavailableView {
            Label("Looking for your Mac", systemImage: "antenna.radiowaves.left.and.right")
                .symbolEffect(.variableColor.iterative)
        } description: {
            // Permission leads, because on a cold first launch the system's local-network alert
            // appears over this screen and this is the sentence that has to earn the tap on Allow.
            Text("Granita needs permission to look on this network, and has to be running on a Mac that is on it.")
        }
    }

    private var nothingFound: some View {
        ContentUnavailableView {
            Label("No Mac found", systemImage: "laptopcomputer.slash")
        } description: {
            Text("Check that Granita is running on your Mac, and that both are on the same network.")
        } actions: {
            // A reader who plugged the Mac in after the browse went quiet otherwise has one
            // recourse, which is to kill the app.
            Button("Search Again", action: onSearchAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    private var permissionRefused: some View {
        ContentUnavailableView {
            Label("Local network access is off", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Allow Local Network access in Settings so Granita can find your Mac.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    private var failed: some View {
        ContentUnavailableView {
            Label("Could not search", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Try searching again. If it still fails, check Local Network access in Settings.")
        } actions: {
            Button("Try Again", action: onSearchAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            copyLogs
        }
    }

    private var copyLogs: some View {
        VStack(spacing: 8) {
            Button(action: onCopyLogs) {
                switch logCopyState {
                case .ready: Text("Copy Logs")
                case .copying: Text("Copying Logs…")
                case .copied: Text("Copy Logs Again")
                case .failed: Text("Try Copying Again")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(logCopyState == .copying)

            switch logCopyState {
            case .ready, .copying:
                EmptyView()
            case .copied:
                Text("Logs copied. Paste them into your message.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .failed:
                Text("Couldn’t copy logs. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func list(of servers: [DiscoveredServer]) -> some View {
        List(servers) { server in
            NavigationLink(value: server) {
                Label(server.name, systemImage: "laptopcomputer")
                    // One line, so every row is the same height and the list scans as a column. Two
                    // lines would let a long name wrap instead of truncating, which is a 68pt row in
                    // a picker the reader uses twice in the app's life.
                    .lineLimit(1)
                    // Middle, not tail. Bonjour device names differ at the end — "…MacBook Pro
                    // (work)" against "…MacBook Pro" — so tail truncation deletes the only part of
                    // the string that tells two Macs apart.
                    .truncationMode(.middle)
            }
        }
    }
}
