import Foundation
import Testing

import ServerApiDomain
import ServerMacUi

/// The Connections tab, design §6.
///
/// **The populated states are photographable now, and were not before.** The row used to draw its
/// time with `Text(_:style: .relative)`, measured against the moment of rendering — so a baseline
/// taken today read "3 minutes ago" and the same code read "2 days ago" next week, and the empty
/// state was all this suite could hold. The row takes `now` as a value, so every one of these is a
/// pure function of a fixed clock and a fixed list.
@Suite("Connection log")
@MainActor
struct ConnectionLogViewSnapshotTests {

    /// The clock every row below is measured against. Sits between the appearances so that "just
    /// now", "min" and "hr" are all reachable from one list.
    private static let now = Date(timeIntervalSince1970: 1_755_864_000)

    @Test(arguments: MacAppearance.all)
    func `given nothing has connected when the log renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            ConnectionLogView(attempts: [], now: Self.now, onPair: {}),
            appearance: appearance,
            named: "empty"
        )
    }

    /// One row per outcome, which is what this panel is for: each case is a different thing to do
    /// about it, and the whole reason the log records the reason rather than the fact.
    @Test(arguments: MacAppearance.all)
    func `given every kind of outcome when the log renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given
        let attempts = [
            attempt(seconds: 20, source: "192.168.1.42", outcome: .refused(.noToken), occurrences: 412),
            attempt(seconds: 90, source: "192.168.1.57", outcome: .refused(.unknownToken), occurrences: 3),
            attempt(
                seconds: 240,
                source: "192.168.1.42",
                outcome: .accepted(device: "Davide's iPhone", id: "device-iphone"),
                occurrences: 18
            ),
            attempt(
                seconds: 500,
                source: "192.168.1.42",
                outcome: .paired(device: "Davide's iPhone", id: "device-iphone"),
                occurrences: 1
            ),
            // **A single served request, which is the noun's other spelling and had never been
            // drawn.** Every accepted row in this suite had been coalesced into a plural, so
            // *1 requests* was one release away from shipping — the same defect the phone's
            // *1 file* subject exists to stop, on the panel a reader opens under pressure.
            attempt(
                seconds: 620,
                source: "192.168.1.88",
                outcome: .accepted(device: "Davide's iPad", id: "device-ipad"),
                occurrences: 1
            ),
            attempt(
                seconds: 720,
                source: "192.168.1.19",
                outcome: .refused(.unsupportedApiVersion(sent: 2)),
                occurrences: 2
            ),
            attempt(seconds: 900, source: "192.168.1.57", outcome: .refused(.rateLimited), occurrences: 5),
            attempt(seconds: 1_100, source: "192.168.1.31", outcome: .refused(.pairingCodeExpired), occurrences: 1),
            attempt(seconds: 1_400, source: "192.168.1.31", outcome: .refused(.pairingCodeUnknown), occurrences: 2),
            attempt(
                seconds: 4_000,
                source: "192.168.1.31",
                outcome: .refused(.pairingNotRecordable(reason: "The volume is out of space.")),
                occurrences: 1
            )
        ]

        // when - then
        assertSettingsSnapshot(
            ConnectionLogView(attempts: attempts, now: Self.now, onPair: {}),
            appearance: appearance,
            named: "every-outcome"
        )
    }

    /// The state the panel is actually opened in: one phone hammering, and a second one whose
    /// single quiet failure is the thing worth reading. It is the case the coalescing exists for,
    /// and the count is what stops the loud row from looking like the quiet one.
    @Test(arguments: MacAppearance.all)
    func `given one phone retrying and another failing once when the log renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given
        let attempts = [
            attempt(seconds: 5, source: "192.168.1.57", outcome: .refused(.unknownToken), occurrences: 1_284),
            attempt(seconds: 3_000, source: "192.168.1.42", outcome: .refused(.noToken), occurrences: 1)
        ]

        // when - then
        assertSettingsSnapshot(
            ConnectionLogView(attempts: attempts, now: Self.now, onPair: {}),
            appearance: appearance,
            named: "one-loud-one-quiet"
        )
    }

    /// A full log, which is the only state in which the footer's two halves disagree — "since" stops
    /// being when the server started and becomes as far back as what is on screen goes.
    @Test(arguments: MacAppearance.all)
    func `given the log is full when it renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given
        let attempts = (0..<ConnectionAttempt.logCapacity).map { index in
            attempt(
                seconds: TimeInterval(index * 30),
                source: "192.168.1.\(40 + index % 6)",
                outcome: .refused(.noToken),
                occurrences: index + 1
            )
        }

        // when - then
        assertSettingsSnapshot(
            ConnectionLogView(attempts: attempts, now: Self.now, onPair: {}),
            appearance: appearance,
            named: "full"
        )
    }

    // MARK: -

    /// Identifiers are derived from the offset rather than fresh, so a re-recording of these
    /// baselines cannot differ from the last one by anything a `UUID()` decided.
    private func attempt(
        seconds: TimeInterval,
        source: String,
        outcome: ConnectionOutcome,
        occurrences: Int
    ) -> ConnectionAttempt {
        ConnectionAttempt(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", Int(seconds)))!,
            at: Self.now.addingTimeInterval(-seconds),
            source: source,
            outcome: outcome,
            occurrences: occurrences
        )
    }
}
