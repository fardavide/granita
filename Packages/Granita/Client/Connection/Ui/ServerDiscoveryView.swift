import SwiftUI

import ClientConnectionDomain
import CoreComponentsUi

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

    @State private var isChoosingMacDownload = false
    @ScaledMetric(relativeTo: .title) private var macDownloadSymbolSize: CGFloat = 80

    private let state: DiscoveryState
    private let offersMacDownload: Bool
    private let logCopyState: DiagnosticCopyState
    private let onSearchAgain: () -> Void
    private let onOpenSettings: () -> Void
    private let onCopyLogs: () -> Void

    public init(
        state: DiscoveryState,
        offersMacDownload: Bool,
        logCopyState: DiagnosticCopyState,
        onSearchAgain: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.state = state
        self.offersMacDownload = offersMacDownload
        self.logCopyState = logCopyState
        self.onSearchAgain = onSearchAgain
        self.onOpenSettings = onOpenSettings
        self.onCopyLogs = onCopyLogs
    }

    public var body: some View {
        Group {
            switch state {
            case .idle, .searching:
                #if os(iOS)
                if offersMacDownload {
                    firstConnection(isSearching: true)
                } else {
                    searching
                }
                #else
                searching
                #endif
            case .found(let servers) where servers.isEmpty:
                #if os(iOS)
                if offersMacDownload {
                    firstConnection(isSearching: false)
                } else {
                    nothingFound
                }
                #else
                nothingFound
                #endif
            case .found(let servers):
                list(of: servers)
            case .localNetworkDenied:
                permissionRefused
            case .failed:
                failed
            }
        }
        .navigationTitle("Granita")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // This fixed HTTPS literal has no runtime input. The discovery UI test opens it.
                    Link("Privacy Policy", destination: URL(string: "https://granita.fardavide.dev/privacy/")!)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .animation(reduceMotion ? nil : .default, value: offersMacDownload)
        .animation(reduceMotion ? nil : .default, value: logCopyState)
    }

    #if os(iOS)
    private func firstConnection(isSearching: Bool) -> some View {
        EmptyState {
            Label {
                Text(isSearching ? "Looking for your Mac" : "No Mac found")
                    .font(.title3.bold())
            } icon: {
                Image(systemName: isSearching ? "antenna.radiowaves.left.and.right" : "laptopcomputer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: macDownloadSymbolSize, height: macDownloadSymbolSize)
                    .symbolEffect(.variableColor.iterative, isActive: isSearching)
            }
        } description: {
            Text(isSearching
                 ? "Allow Local Network access so Granita can find your Mac. You’ll also need Granita installed and running on it."
                 : "Granita needs the Mac app to show your projects here. Install and open it on your Mac, with both devices on the same network.")
                .font(.subheadline)
        } actions: {
            VStack(spacing: 12) {
                Button("Get Granita for Mac") {
                    isChoosingMacDownload = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .alert("Get Granita for Mac", isPresented: $isChoosingMacDownload) {
                    // This fixed HTTPS literal has no runtime input. The simulator test opens it.
                    Link("Download from GitHub", destination: URL(string: "https://github.com/fardavide/granita/releases/latest")!)
                    Button("Mac App Store — Not available yet") {}
                        .disabled(true)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Choose where to get the Mac app.")
                }

                if !isSearching {
                    Button("Search Again", action: onSearchAgain)
                        .buttonStyle(.borderless)
                        .controlSize(.large)
                    ErrorReportAction(state: reportState, onCopyLogs: onCopyLogs)
                }
            }
        }
    }
    #endif

    /// No spinner: a progress view promises a finish, and Bonjour has none. The symbol's motion is
    /// the progress indicator, and arriving at a *static* symbol is what says searching stopped —
    /// which is the only thing distinguishing this screen from the one below it at a glance.
    private var searching: some View {
        EmptyState {
            Label("Looking for your Mac", systemImage: "antenna.radiowaves.left.and.right")
                .symbolEffect(.variableColor.iterative)
        } description: {
            // Permission leads, because on a cold first launch the system's local-network alert
            // appears over this screen and this is the sentence that has to earn the tap on Allow.
            Text("Granita needs permission to look on this network, and has to be running on a Mac that is on it.")
        }
    }

    private var nothingFound: some View {
        ErrorState(logCopyState: reportState, onCopyLogs: onCopyLogs) {
            Label("No Mac found", systemImage: "laptopcomputer.slash")
        } description: {
            Text("Check that Granita is running on your Mac, and that both are on the same network.")
        } actions: { copyLogs in
            // A reader who plugged the Mac in after the browse went quiet otherwise has one
            // recourse, which is to kill the app.
            Button("Search Again", action: onSearchAgain)
            copyLogs
        }
    }

    private var permissionRefused: some View {
        ErrorState(logCopyState: reportState, onCopyLogs: onCopyLogs) {
            Label("Local network access is off", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Allow Local Network access in Settings so Granita can find your Mac.")
        } actions: { copyLogs in
            Button("Open Settings", action: onOpenSettings)
            copyLogs
        }
    }

    private var failed: some View {
        ErrorState(logCopyState: reportState, onCopyLogs: onCopyLogs) {
            Label("Could not search", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Try searching again. If it still fails, check Local Network access in Settings.")
        } actions: { copyLogs in
            Button("Try Again", action: onSearchAgain)
            copyLogs
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
