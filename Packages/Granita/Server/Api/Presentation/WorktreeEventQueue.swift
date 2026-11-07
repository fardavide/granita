import CoreApiDomain

struct WorktreeEventQueue: Sendable {
    enum Frame: Equatable, Sendable {
        case snapshot(WorktreeSnapshot)
        case heartbeat
    }

    let stream: AsyncStream<Frame>
    private let continuation: AsyncStream<Frame>.Continuation

    init(capacity: Int) {
        let channel = AsyncStream<Frame>.makeStream(bufferingPolicy: .bufferingNewest(capacity))
        stream = channel.stream
        continuation = channel.continuation
    }

    func send(_ frame: Frame) -> Bool {
        switch continuation.yield(frame) {
        case .enqueued:
            return true
        case .dropped:
            // Full snapshots reconcile after reconnect; do not retain an unbounded slow-client backlog.
            continuation.finish()
            return false
        case .terminated:
            return false
        @unknown default:
            continuation.finish()
            return false
        }
    }

    func finish() {
        continuation.finish()
    }
}
