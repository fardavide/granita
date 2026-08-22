import CoreBrandingDomain
import ServerApiDomain
import SwiftUI

/// The last fifty attempts to reach this Mac, newest first.
///
/// SPEC §9 calls this panel not optional, and the reason is in every row: it is the only place
/// that says *why* a phone is not getting in, to someone who cannot attach a debugger to it. Design
/// §6 moves it out of Advanced and gives it a tab, because it is the only panel here with a reason
/// to be reopened and the only one read under pressure — and because what it used to share a tab
/// with is `Reset All Data`.
///
/// **The elapsed time is handed in rather than derived.** It was `Text(_:style: .relative)`, which
/// measures against the moment of rendering: correct on screen, and impossible to photograph, so the
/// list had no baseline beyond its empty state. Taking `now` as a value makes a populated row a pure
/// function of what it is given, and the screen that composes it supplies a clock that ticks.
public struct ConnectionLogView: View {

    private let attempts: [ConnectionAttempt]
    private let now: Date

    public init(attempts: [ConnectionAttempt], now: Date) {
        self.attempts = attempts
        self.now = now
    }

    public var body: some View {
        if attempts.isEmpty {
            // Kept verbatim, and the design review is explicit about why: it tells you the panel is
            // working while it is showing you nothing.
            ContentUnavailableView {
                Label("Nothing has tried to connect", systemImage: "point.3.connected.trianglepath.dotted")
            } description: {
                Text("Every device that reaches this Mac appears here, whether or not it gets in.")
            }
        } else {
            VStack(spacing: 0) {
                List(attempts) { row(for: $0) }
                // The list scrolls and the footer does not, so at fifty rows the two meet with a
                // row half-cut above the sentence describing it. The rule is what says which is
                // which.
                Divider()
                footer
            }
        }
    }

    @ViewBuilder private func row(for attempt: ConnectionAttempt) -> some View {
        LabeledContent {
            Text(verbatim: elapsed(since: attempt.at))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: sentence(for: attempt.outcome))
                    // The address in monospace and the count beside it, in one line of small print
                    // under the sentence. One `Text` with the address interpolated into it rather
                    // than two laid out side by side, so the pair stays on one line, truncates as
                    // one, and the address still keeps its own face.
                    Text(
                        """
                        \(Text(verbatim: attempt.source).monospaced()) · \
                        \(attempt.occurrences, format: .number) \(noun(for: attempt))
                        """
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbolName(for: attempt.outcome))
                    .foregroundStyle(tint(for: attempt.outcome))
            }
        }
    }

    /// What this panel covers, and how much of it is left.
    ///
    /// The since-time is the oldest row's, not the moment the server started. Once fifty attempts
    /// have been recorded the two stop being the same, and of the pair only the oldest row is a
    /// truthful answer to "how far back does what I am looking at go".
    @ViewBuilder private var footer: some View {
        HStack {
            if let oldest = attempts.last?.at {
                Text(
                    """
                    Since \(oldest, format: .dateTime.hour().minute()) · \
                    the last \(ConnectionAttempt.logCapacity) attempts, this run only
                    """
                )
            }
            Spacer()
            Text(verbatim: "\(attempts.count) of \(ConnectionAttempt.logCapacity)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        // The `List` paints its own backdrop and this strip is outside it, so without one the
        // footer falls through to an unfilled hosting view — which is white, and reads as a band of
        // daylight across the bottom of the pane in dark mode.
        .background(.windowBackground)
    }

    /// Each of these means something different to do, which is the whole point of recording the
    /// reason rather than the fact.
    ///
    /// **No "Refused".** The `xmark.circle` beside it already says so, forty-five times down a
    /// list, and the space it costs is what pays for the address and the count underneath. The word
    /// stays on a *pairing*, because `checkmark.seal` and `checkmark.circle` are not told apart at a
    /// glance and the whole value of that row is that it says the pairing itself worked.
    private func sentence(for outcome: ConnectionOutcome) -> String {
        switch outcome {
        case .accepted(let device): device
        case .paired(let device): "Paired \(device)"
        case .refused(.noToken): "No pairing token"
        case .refused(.unknownToken): "Token not issued by this Mac"
        case .refused(.rateLimited): "Too many failed attempts"
        case .refused(.pairingCodeUnknown): "Pairing code not one this Mac issued"
        case .refused(.pairingCodeExpired): "Pairing code had expired"
        case .refused(.pairingNotRecordable(let reason)): "The pairing could not be saved: \(reason)"
        case .refused(.unsupportedApiVersion(let sent)):
            "Speaks version \(sent), this Mac serves \(Branding.apiVersion)"
        }
    }

    /// A served row counts requests and a refused one counts attempts, because that is what each of
    /// them is: one is a phone reading, the other a phone knocking.
    ///
    /// The number itself is not formatted here. It goes through `Text`'s own interpolation so that
    /// its grouping separator comes from the environment's locale rather than the process's — a
    /// four-digit count is the ordinary case on this row, and `Int.formatted()` would put a comma in
    /// it on the runner and a full stop on an Italian laptop, from identical code.
    private func noun(for attempt: ConnectionAttempt) -> String {
        switch attempt.outcome {
        case .accepted: attempt.occurrences == 1 ? "request" : "requests"
        case .paired, .refused: attempt.occurrences == 1 ? "attempt" : "attempts"
        }
    }

    private func symbolName(for outcome: ConnectionOutcome) -> String {
        switch outcome {
        case .accepted: "checkmark.circle"
        case .paired: "checkmark.seal"
        case .refused: "xmark.circle"
        }
    }

    /// Colour on the symbol only, never on the row.
    ///
    /// During setup nearly every row here is a refusal, and a wall of red stops being a signal —
    /// which is why the design rejected colour as *the* difference. One tinted glyph in a column of
    /// grey ones is still scannable when every glyph is tinted, because the sentence beside it is
    /// doing the work.
    private func tint(for outcome: ConnectionOutcome) -> Color {
        switch outcome {
        case .accepted, .paired: .secondary
        case .refused: .orange
        }
    }

    /// Coarse on purpose, and the coarseness is the point: this is read while something is failing,
    /// where the question is whether a phone tried a moment ago or a quarter of an hour ago.
    private func elapsed(since moment: Date) -> String {
        let seconds = Int(now.timeIntervalSince(moment))
        return switch seconds {
        case ..<60: "just now"
        case ..<3_600: "\(seconds / 60) min"
        default: "\(seconds / 3_600) hr"
        }
    }
}
