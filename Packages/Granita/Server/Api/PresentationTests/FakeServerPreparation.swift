actor FakeServerPreparation {
    private var waiting: Waiting = .ready
    private var started: [CheckedContinuation<Void, Never>] = []
    private(set) var runCount = 0
    private(set) var didFinish = false

    func run() async {
        runCount += 1
        for waiter in started { waiter.resume() }
        started = []
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume() }
                else { waiting = .pending(continuation) }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
        didFinish = true
    }

    func waitUntilStarted() async {
        guard runCount == 0 else { return }
        await withCheckedContinuation { started.append($0) }
    }

    private func cancel() {
        let previous = waiting
        waiting = .ready
        if case .pending(let continuation) = previous { continuation.resume() }
    }

    private enum Waiting {
        case ready
        case pending(CheckedContinuation<Void, Never>)
    }
}
