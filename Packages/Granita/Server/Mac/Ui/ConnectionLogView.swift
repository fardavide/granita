import CoreBrandingDomain
import ServerApiDomain
import SwiftUI

/// The last fifty attempts to reach this Mac, newest first.
///
/// SPEC §9 calls this panel not optional, and the reason is in every row: it is the only place
/// that says *why* a phone is not getting in, to someone who cannot attach a debugger to it.
public struct ConnectionLogView: View {

    private let attempts: [ConnectionAttempt]

    public init(attempts: [ConnectionAttempt]) {
        self.attempts = attempts
    }

    public var body: some View {
        if attempts.isEmpty {
            ContentUnavailableView {
                Label("Nothing has tried to connect", systemImage: "point.3.connected.trianglepath.dotted")
            } description: {
                Text("Every device that reaches this Mac appears here, whether or not it gets in.")
            }
        } else {
            List(attempts) { attempt in
                LabeledContent {
                    // Relative and live: a log read five minutes after it was opened should not
                    // still say "just now".
                    Text(attempt.at, style: .relative)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } label: {
                    Label {
                        Text(sentence(for: attempt.outcome))
                        Text(attempt.source)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: symbolName(for: attempt.outcome))
                    }
                }
            }
        }
    }

    /// Each of these means something different to do, which is the whole point of recording the
    /// reason rather than the fact.
    private func sentence(for outcome: ConnectionOutcome) -> String {
        switch outcome {
        case .accepted(let device): "Served \(device)"
        case .paired(let device): "Paired \(device)"
        case .refused(.noToken): "Refused — it offered no pairing token"
        case .refused(.unknownToken): "Refused — that token was not issued by this Mac"
        case .refused(.rateLimited): "Refused — too many failed attempts, waiting a minute"
        case .refused(.pairingCodeUnknown): "Refused — that pairing code is not one this Mac issued"
        case .refused(.pairingCodeExpired): "Refused — that pairing code had expired"
        case .refused(.pairingNotRecordable(let reason)): "Refused — the pairing could not be saved: \(reason)"
        case .refused(.unsupportedApiVersion(let sent)):
            "Refused — it speaks version \(sent), this Mac serves \(Branding.apiVersion)"
        }
    }

    private func symbolName(for outcome: ConnectionOutcome) -> String {
        switch outcome {
        case .accepted: "checkmark.circle"
        case .paired: "checkmark.seal"
        case .refused: "xmark.circle"
        }
    }
}
