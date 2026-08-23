import Foundation
import SwiftUI

import CorePairingDomain
import ServerApiDomain
import ServerMacDomain

/// Devices — who has paired with this Mac, and how the next one does.
///
/// Design §5. The QR is the largest thing in the app and it is what sets the window's height; the
/// six words sit under it **as an equal**, at 13pt monospace, because they are a second credential
/// redeeming the same pairing rather than a caption for the picture.
///
/// **There is no plaintext warning**, which the frames draw and 0.0.7 made false: the link carries a
/// real `spki=` fingerprint and the Mac serves TLS under it.
///
/// **Allowing a device from the Mac is not here.** It has no frames and no protocol — nothing on
/// this Mac knows a phone exists until that phone presents a credential — so §5 ships in two pieces
/// and this is the drawn one.
///
/// Whether a code has run out is decided from `now` rather than from a clock read inside this body,
/// for the same reason the connection log's elapsed time is handed in: a state derived from the
/// moment of drawing is a state no baseline can photograph.
public struct DevicesSettingsView: View {

    private let devices: [PairedDevice]
    private let offer: PairingOffer
    private let now: Date
    private let failure: StoreWriteFailure?
    private let onNewCode: () -> Void
    private let onRevoke: (String) -> Void
    private let onOpenGeneral: () -> Void

    public init(
        devices: [PairedDevice],
        offer: PairingOffer,
        now: Date,
        failure: StoreWriteFailure?,
        onNewCode: @escaping () -> Void,
        onRevoke: @escaping (String) -> Void,
        onOpenGeneral: @escaping () -> Void
    ) {
        self.devices = devices
        self.offer = offer
        self.now = now
        self.failure = failure
        self.onNewCode = onNewCode
        self.onRevoke = onRevoke
        self.onOpenGeneral = onOpenGeneral
    }

    public var body: some View {
        Form {
            Section {
                if devices.isEmpty {
                    // No action, deliberately: the thing to do about it is the section underneath,
                    // and offering a button that scrolls the reader six points down the same pane
                    // would be a control that appears to do more than it does.
                    Text("No phone has paired with this Mac yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(devices) { row(for: $0) }
                }
                if let failure {
                    failureAdvice(failure)
                }
            } header: {
                Text("Paired devices")
            }

            Section {
                pairing
            } header: {
                Text("Add a device")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - One paired phone

    /// Leads with the fact that is real. Everything a row can say about *later* than pairing comes
    /// from a log that starts empty at every launch, so the date it was paired is the only thing
    /// here that survives a restart.
    @ViewBuilder private func row(for device: PairedDevice) -> some View {
        LabeledContent {
            HStack(spacing: 12) {
                sighting(device.sighting)
                Button {
                    onRevoke(device.id)
                } label: {
                    // Red on the label rather than on the button, which is the difference between a
                    // destructive control and one that has already gone off: tinting the control
                    // fills its bezel, and a row with a solid red block in it reads as an alarm
                    // rather than as something to press.
                    Text("Revoke").foregroundStyle(.red)
                }
                // Bordered, because it has to read as pressable in a row that is otherwise all text.
                .buttonStyle(.bordered)
                .controlSize(.small)
                    .help("Stop this device reading anything from this Mac")
                    .accessibilityIdentifier("granita.devices.revoke.\(device.id)")
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: device.name)
                    Text("\(device.platform) · paired \(device.pairedAt, format: .dateTime.day().month(.wide))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbolName(for: device.platform))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// *Seen 4 min ago* when this run has actually served the device, and otherwise how far back
    /// this run goes — never a stale date, which on a row like this reads as an accusation.
    @ViewBuilder private func sighting(_ sighting: DeviceSighting) -> some View {
        switch sighting {
        case .seen(let at):
            Text(verbatim: "Seen \(elapsed(since: at))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        case .notSeenSince(let start):
            Text("Not seen since \(start, format: .dateTime.hour().minute())")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }

    /// iPad and iPhone are told apart because a reader with both has two rows that are otherwise the
    /// same shape. Anything else gets the neutral glyph rather than a guess.
    private func symbolName(for platform: String) -> String {
        switch platform.lowercased() {
        case "ipados": "ipad"
        case "ios": "iphone"
        default: "desktopcomputer"
        }
    }

    // MARK: - Making the next one possible

    @ViewBuilder private var pairing: some View {
        switch offer {
        case .preparing:
            centred {
                ProgressView()
                    .controlSize(.small)
                Text("Making a pairing code…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .offered(let invitation):
            if invitation.expiresAt > now {
                live(invitation)
            } else {
                expired(invitation)
            }
        case .serverNotRunning:
            centred {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("Pairing needs the server")
                    .font(.headline)
                Text("A code has to say where to reach this Mac, and nothing is serving.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open General", action: onOpenGeneral)
            }
        case .unavailable(let reason):
            // Not a state the frames draw, and it had to exist: the code is signed by an identity
            // out of the login Keychain, which can be locked or half-removed. Our sentence, the
            // system's underneath — the failure idiom this product already uses everywhere else.
            centred {
                Label("No pairing code could be made", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(verbatim: reason)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                Button("Try Again", action: onNewCode)
            }
        }
    }

    @ViewBuilder private func live(_ invitation: PairingInvitation) -> some View {
        centred {
            PairingQrCode(payload: invitation.link.text)
            Text("Open Granita on your phone and scan this.")
                .font(.callout)
                .foregroundStyle(.secondary)
            // The words and the line explaining them are one thing, spaced tighter than the
            // stack around them, so the sentence reads as belonging to the words above it rather
            // than to the countdown below.
            VStack(spacing: 3) {
                spokenCode(invitation.spokenCode)
                Text("Type these instead, if the camera will not do it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            countdown(until: invitation.expiresAt)
        }
    }

    /// The QR dimmed rather than removed, because what a reader has to understand is that the thing
    /// they were pointing a camera at is the thing that ran out.
    @ViewBuilder private func expired(_ invitation: PairingInvitation) -> some View {
        centred {
            ZStack {
                PairingQrCode(payload: invitation.link.text)
                    .opacity(0.18)
                    .accessibilityHidden(true)
                Text("Code expired")
                    .font(.headline)
            }
            Text("A code lasts two minutes and works once.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("New Code", action: onNewCode)
                .buttonStyle(.borderedProminent)
        }
    }

    /// Six words at 13pt monospace, directly under the QR and as an equal.
    ///
    /// Drawn word by word with a separator between, so the line stays readable across a room — and
    /// the separator is one the server accepts back, because a reader who selects this line and
    /// pastes it into a phone must not be refused for the punctuation this tab chose.
    @ViewBuilder private func spokenCode(_ code: String) -> some View {
        let words = code.split(separator: "-").map(String.init)
        HStack(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { position, word in
                if position > 0 {
                    Text(verbatim: "·")
                        .foregroundStyle(.tertiary)
                }
                Text(verbatim: word)
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .textSelection(.enabled)
    }

    /// A bar and two lines of small print, which is what the design asked for and no more — a ring
    /// or a gauge would be inventing a control for something a `ProgressView` already is.
    @ViewBuilder private func countdown(until expiry: Date) -> some View {
        let remaining = max(0, expiry.timeIntervalSince(now))
        VStack(spacing: 4) {
            ProgressView(value: remaining, total: PairingInvitation.lifetime)
            HStack {
                // Through `Text`'s own interpolation rather than a formatted `String`: minutes and
                // seconds read the environment's locale here, and the process's there — which is a
                // baseline that renders differently on a runner than on the machine that wrote it.
                Text("Expires in \(Duration.seconds(Int(remaining)), format: .time(pattern: .minuteSecond))")
                Spacer()
                Text("Single use")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(width: 240)
    }

    // MARK: -

    @ViewBuilder private func failureAdvice(_ failure: StoreWriteFailure) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(failure.sentence, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
            if let reason = failure.reason {
                Text(verbatim: reason)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    /// Everything in the second section is stacked in the middle of the pane, which is the one thing
    /// every one of its four states has in common.
    ///
    /// No padding of its own, and the spacing is as tight as it reads well at. Design §2 sized the
    /// window from this pane — 236 to 244pt of QR, the words, the countdown and two device rows —
    /// and a stack that spends ten points between each of five children puts the countdown below the
    /// fold, which is the one part of it a reader is watching.
    private func centred(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity)
    }

    /// Coarse, and coarse on purpose: the question a reader has of this column is whether the phone
    /// was here a moment ago or this morning.
    private func elapsed(since moment: Date) -> String {
        let seconds = Int(now.timeIntervalSince(moment))
        return switch seconds {
        case ..<60: "just now"
        case ..<3_600: "\(seconds / 60) min ago"
        default: "\(seconds / 3_600) hr ago"
        }
    }
}
