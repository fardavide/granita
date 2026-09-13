import Foundation

public enum WorktreeReadTiming: Hashable, Sendable {
    case notStarted
    case running(started: Date)
    case finished(started: Date, ended: Date)

    public func elapsed(at now: Date) -> TimeInterval {
        switch self {
        case .notStarted: 0
        case .running(let started): max(0, now.timeIntervalSince(started))
        case .finished(let started, let ended): max(0, ended.timeIntervalSince(started))
        }
    }
}
