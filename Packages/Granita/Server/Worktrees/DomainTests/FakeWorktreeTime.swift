import Foundation
import Synchronization

final class FakeWorktreeTime: Sendable {

    private let date: Mutex<Date>

    init(at date: Date) {
        self.date = Mutex(date)
    }

    var now: Date { date.withLock { $0 } }

    func advance(by interval: TimeInterval) {
        date.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}
