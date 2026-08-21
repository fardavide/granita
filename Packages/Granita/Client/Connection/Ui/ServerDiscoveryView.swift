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

    /// Wide enough for the longest row this screen has, narrow enough that the iPad reads as the
    /// phone at rest in a bigger room rather than as a phone stretched across it.
    ///
    /// Applied by whoever owns the navigation container, not here, and that is the whole point: iOS
    /// draws a large title in the navigation bar rather than in the content, so a frame around this
    /// view centres the rows and leaves the title at the window's leading edge — which is the
    /// misalignment the measure exists to remove. The composition root and the snapshot suite both
    /// clamp the stack, so the baselines assert what ships.
    public static let contentWidth: CGFloat = 420

    private let state: DiscoveryState
    private let onSearchAgain: () -> Void
    private let onOpenSettings: () -> Void

    public init(
        state: DiscoveryState,
        onSearchAgain: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.state = state
        self.onSearchAgain = onSearchAgain
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
            case .failed(let diagnostic):
                failed(diagnostic)
            }
        }
        .navigationTitle("Granita")
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
        }
    }

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

    /// Three slots, three jobs. The description is ours and always says the same two things; the
    /// action retries; the system's own sentence goes to the bottom in small print, where it is
    /// copyable into a bug report and unmistakably not instructions.
    private func failed(_ diagnostic: String) -> some View {
        ContentUnavailableView {
            Label("Could not search", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Something stopped Granita from looking on this network. Trying again usually works; if it does not, check Local Network access in Settings.")
        } actions: {
            Button("Try Again", action: onSearchAgain)
                .buttonStyle(.borderedProminent)
            Text(diagnostic)
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.top)
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
