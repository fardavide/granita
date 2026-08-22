import Testing

import ServerMacUi

/// The connection log's empty state, which the design review calls the best copy in the app: it
/// tells you the panel is working while it is showing you nothing.
///
/// **Only the empty state, and that is a finding rather than a gap.** A populated row renders its
/// time as `Text(_:style: .relative)`, which is measured against the moment of rendering — so a
/// baseline taken today reads "3 minutes ago" and the same code reads "2 days ago" next week. The
/// list cannot be pinned by a picture until that row takes the time it should display rather than
/// deriving it, which is a change to the row and belongs with §6, where the row is being relaid out
/// anyway.
@Suite("Connection log")
@MainActor
struct ConnectionLogViewSnapshotTests {

    @Test(arguments: MacAppearance.all)
    func `given nothing has connected when the log renders then it matches its baseline`(
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            ConnectionLogView(attempts: []),
            appearance: appearance,
            named: "empty"
        )
    }
}
