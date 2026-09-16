import Foundation

/// A clock a test moves by hand, so an age is asserted rather than waited for.
///
/// Named for what it does rather than `Clock`, which is a standard-library protocol this target also
/// has in scope.
///
/// Explicitly `nonisolated` because this target is main-actor by default and the model's clock is a
/// `@Sendable` closure, which cannot reach across to the main actor to read it — the same reason the
/// fixed instant it starts from is declared that way.
nonisolated final class MovableClock: @unchecked Sendable {

    // Mutated only from the test's own thread between reads, and read through the `now` closure the
    // model holds. There is no concurrency here for a lock to protect — the model under test is the
    // only other participant and it never writes.
    private(set) var reading: Date

    init(from start: Date) {
        reading = start
    }

    func advance(by seconds: TimeInterval) {
        reading = reading.addingTimeInterval(seconds)
    }
}
