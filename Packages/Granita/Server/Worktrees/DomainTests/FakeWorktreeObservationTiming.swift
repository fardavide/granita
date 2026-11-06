import Foundation

import ServerWorktreesDomain

actor FakeWorktreeObservationTiming: WorktreeObservationTiming {
    private var elapsed: Duration = .zero
    private var waiting: [UUID: Waiter] = [:]
    private let sleeps = AsyncStream.makeStream(of: Duration.self)

    func now() -> Duration { elapsed }

    func sleep(for duration: Duration) async throws(CancellationError) {
        let id = UUID()
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    guard Task.isCancelled == false else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    waiting[id] = Waiter(deadline: elapsed + duration, continuation: continuation)
                    sleeps.continuation.yield(duration)
                }
            } onCancel: {
                Task { await self.cancel(id) }
            }
        } catch {
            throw CancellationError()
        }
    }

    func nextSleep() async -> Duration? {
        var iterator = sleeps.stream.makeAsyncIterator()
        return await iterator.next()
    }

    func advance(by duration: Duration) {
        elapsed += duration
        let ready = waiting.filter { $0.value.deadline <= elapsed }
        for (id, waiter) in ready {
            waiting.removeValue(forKey: id)
            waiter.continuation.resume()
        }
    }

    private func cancel(_ id: UUID) {
        waiting.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
    }

    private struct Waiter {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }
}
