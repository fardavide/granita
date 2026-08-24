import Foundation
import SwiftUI

import ServerApiDomain
import ServerMacDomain
import ServerStoreDomain

/// General — this Mac's own address, whether anything is listening, and whether Granita comes back
/// after a restart.
///
/// Design §3. Two of the specification's rows are deliberately absent and neither is an oversight.
/// There is **no port field**: the Mac binds a Bonjour service, so the system chooses and publishes
/// the port and it differs every launch — a control that cannot be operated is worse than a fact
/// that can be read, and a field that *worked* would cost the advertisement the phone finds this Mac
/// by. There is **no plaintext warning** either: the escape hatch is a flag on the executable and is
/// unreachable from here, so the banner would be for a state that cannot occur.
public struct GeneralSettingsView: View {

    private let state: ServerRunState
    private let servingSince: Date?
    private let loginItem: LoginItemState
    // A `Binding` rather than a setter closure, and the reason is not taste. `Binding.init(get:set:)`
    // now wants an `@isolated(any) @Sendable` setter; handing it a closure this view stores either
    // warns about a non-Sendable conversion or, once the closure is annotated `@MainActor`, crashes
    // swift-frontend outright in IRGen while building the reabstraction thunk. Taking the binding
    // ready-made keeps the conversion in the one place that has a real main-actor value to bind to,
    // and it is what SwiftUI expects a `Toggle` to be handed anyway.
    private let opensAtLogin: Binding<Bool>
    private let onCopyAddress: (String) -> Void
    private let onRestart: () -> Void
    private let onOpenLocalNetworkSettings: () -> Void
    private let onOpenLoginItems: () -> Void
    private let onQuit: () -> Void

    public init(
        state: ServerRunState,
        servingSince: Date?,
        loginItem: LoginItemState,
        opensAtLogin: Binding<Bool>,
        onCopyAddress: @escaping (String) -> Void,
        onRestart: @escaping () -> Void,
        onOpenLocalNetworkSettings: @escaping () -> Void,
        onOpenLoginItems: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.state = state
        self.servingSince = servingSince
        self.loginItem = loginItem
        self.opensAtLogin = opensAtLogin
        self.onCopyAddress = onCopyAddress
        self.onRestart = onRestart
        self.onOpenLocalNetworkSettings = onOpenLocalNetworkSettings
        self.onOpenLoginItems = onOpenLoginItems
        self.onQuit = onQuit
    }

    public var body: some View {
        Form {
            Section {
                LabeledContent("Address") { address }
                LabeledContent("Status") { status }
            } header: {
                Text("Server")
            } footer: {
                Text(
                    """
                    macOS chooses the port when Granita advertises itself, so it changes every \
                    launch. Your phone finds this Mac by name, not by port.
                    """
                )
            }

            Section {
                Toggle("Open Granita at login", isOn: opensAtLogin)
                loginItemFailure
            } header: {
                Text("Startup")
            } footer: {
                Text("Granita has no window and no Dock icon. If it is not running, your phone finds nothing.")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var address: some View {
        switch state {
        case .running(let endpoint):
            // Host and port, and nothing in front of them. A scheme would have to be `https` now
            // that the Mac serves TLS under a self-signed identity, and pasting that into a browser
            // produces a certificate warning rather than an answer — which is the opposite of what
            // this row is for.
            let address = "\(endpoint.host):\(endpoint.port)"
            HStack(spacing: 6) {
                Text(verbatim: address)
                    .monospaced()
                    .textSelection(.enabled)
                Button { onCopyAddress(address) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy this Mac's address")
                .accessibilityLabel("Copy this Mac's address")
            }
        case .starting, .failed, .stopped, .blockedByAnotherProcess:
            Text(verbatim: "—")
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .starting:
            Text("Starting…")
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 10) {
                // The time is what tells "this has been fine all morning" from "this stood itself
                // up again while I was not looking", which is the only visible trace a rebind
                // leaves.
                if let servingSince {
                    Text("Serving since \(servingSince, format: .dateTime.hour().minute())")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Serving")
                        .foregroundStyle(.secondary)
                }
                Button("Restart", action: onRestart)
            }
        case .failed(let reason):
            notServing(reason: reason)
        case .stopped:
            notServing(reason: nil)
        case .blockedByAnotherProcess(let holder):
            blocked(by: holder)
        }
    }

    /// The lock refusal, which gets its own sentence rather than borrowing the one below.
    ///
    /// **Not `notServing`, and that is the whole reason this is a state of its own.** That sentence
    /// names Local Network access as the usual cause and offers a button straight to it — advice
    /// that is simply wrong here, since the pane it opens is already correct and a reader sent to
    /// check it comes back no better off. The thing to do is quit the other process, so that is
    /// what the row says and what the button does.
    @ViewBuilder private func blocked(by holder: StoreLockHolder?) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            Label("Not serving", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            // The holder in the sentence rather than in small print underneath: it is not a
            // diagnostic here, it is the instruction. A process identifier can be looked up and
            // quit; "another copy is running" is something a reader can do nothing with.
            Text(verbatim: """
                \(holder?.sentence ?? "Another process") is already using this Mac's settings, so \
                Granita left them alone. Quit it and open Granita again.
                """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            Button("Quit Granita", action: onQuit)
                .accessibilityIdentifier("granita.general.quit")
        }
    }

    /// Our sentence, our button, the system's string demoted to small print — the same rule the
    /// phone's discovery failure follows, for the same reason.
    ///
    /// The sentence names the likely cause rather than asserting it. A refused Bonjour registration
    /// is by far the most common way this state is reached, but `failed` carries whatever went
    /// wrong — a locked keychain reaches it too — and a screen that says "macOS is blocking the
    /// local network" over a keychain error sends the reader to a settings pane that is already
    /// correct.
    @ViewBuilder private func notServing(reason: String?) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            Label("Not serving", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(
                """
                Your phone cannot find this Mac. The usual cause is Local Network access being \
                turned off for Granita.
                """
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            HStack(spacing: 8) {
                Button("Open Local Network Settings", action: onOpenLocalNetworkSettings)
                    .buttonStyle(.borderedProminent)
                Button("Try Again", action: onRestart)
            }
            if let reason {
                Text(verbatim: reason)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: 330, alignment: .trailing)
    }

    @ViewBuilder private var loginItemFailure: some View {
        switch loginItem {
        case .on, .off:
            EmptyView()
        case .awaitingApproval:
            loginItemAdvice("macOS has not approved this yet, so it stayed off.", reason: nil)
        case .refused(let reason):
            loginItemAdvice("macOS would not add Granita to your login items, so it stayed off.", reason: reason)
        }
    }

    @ViewBuilder private func loginItemAdvice(_ sentence: String, reason: String?) -> some View {
        LabeledContent {
            Button("Open Login Items…", action: onOpenLoginItems)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: sentence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let reason {
                    Text(verbatim: reason)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
