import ServerGitDomain
import ServerWorktreesDomain

actor FakeWorktreeObservationSource: WorktreeObservationSource {
    private let wrapped: any WorktreeObservationSource
    private var installed = false
    private var installationWaiters: [CheckedContinuation<Void, Never>] = []

    init(wrapped: any WorktreeObservationSource) {
        self.wrapped = wrapped
    }

    func events(watching locations: [RepositoryLocation]) async throws(WorktreeObservationError) -> AsyncStream<WorktreeObservationEvent> {
        let events = try await wrapped.events(watching: locations)
        installed = true
        for waiter in installationWaiters { waiter.resume() }
        installationWaiters = []
        return events
    }

    func waitUntilInstalled() async {
        if installed { return }
        await withCheckedContinuation { installationWaiters.append($0) }
    }

    func stop() async {
        await wrapped.stop()
    }
}
