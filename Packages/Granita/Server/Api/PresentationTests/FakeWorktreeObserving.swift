import Testing

import ServerWorktreesDomain

actor FakeWorktreeObserving: WorktreeObserving {
    private var state: State = .ready
    private var started: [CheckedContinuation<Void, Never>] = []
    private let reconciliations = AsyncStream.makeStream(of: Void.self)
    private(set) var runCount = 0
    private(set) var stopCount = 0
    private(set) var didFinish = false
    private(set) var reconciliationCount = 0

    func run() async {
        runCount += 1
        for waiter in started { waiter.resume() }
        started = []
        await withCheckedContinuation { continuation in
            switch state {
            case .ready: state = .running(continuation)
            case .running:
                Issue.record("Observation was started twice")
                continuation.resume()
            case .stopped: continuation.resume()
            }
        }
        didFinish = true
    }

    func stop() {
        stopCount += 1
        let previous = state
        state = .stopped
        if case .running(let continuation) = previous { continuation.resume() }
    }

    func reconcile() {
        reconciliationCount += 1
        reconciliations.continuation.yield(())
    }

    func waitUntilStarted() async {
        guard runCount == 0 else { return }
        await withCheckedContinuation { started.append($0) }
    }

    func nextReconciliation() async -> Bool {
        var iterator = reconciliations.stream.makeAsyncIterator()
        return await iterator.next() != nil
    }

    private enum State {
        case ready
        case running(CheckedContinuation<Void, Never>)
        case stopped
    }
}
