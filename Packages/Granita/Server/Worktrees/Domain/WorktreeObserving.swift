public protocol WorktreeObserving: Sendable {
    func run() async
    func stop() async
    func reconcile() async
}

extension WorktreeObservation: WorktreeObserving {}
