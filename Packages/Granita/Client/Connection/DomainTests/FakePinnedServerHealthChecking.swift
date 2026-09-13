import ClientConnectionDomain
import CoreApiDomain
import CorePairingDomain

actor FakePinnedServerHealthChecking: PinnedServerHealthChecking {
    struct Invocation: Hashable, Sendable {
        let address: ServerAddress
        let fingerprint: SpkiFingerprint
    }

    private(set) var invocations: [Invocation] = []
    private let answering: HealthResponse
    private let beforeAnswering: @Sendable () async -> Void
    private let answers: [ServerAddress: Result<HealthResponse, ApiFailure>]
    private let sequentialAnswers: [Result<HealthResponse, ApiFailure>]
    private let waitingFor: [ServerAddress: ServerAddress]
    private let invocationEvents: AsyncStream<ServerAddress>
    private let invocationContinuation: AsyncStream<ServerAddress>.Continuation

    init(answering: HealthResponse, answers: [ServerAddress: Result<HealthResponse, ApiFailure>] = [:], sequentialAnswers: [Result<HealthResponse, ApiFailure>] = [], waitingFor: [ServerAddress: ServerAddress] = [:], beforeAnswering: @escaping @Sendable () async -> Void = {}) {
        self.answering = answering
        self.beforeAnswering = beforeAnswering
        self.answers = answers
        self.sequentialAnswers = sequentialAnswers
        self.waitingFor = waitingFor
        let events = AsyncStream<ServerAddress>.makeStream()
        invocationEvents = events.stream
        invocationContinuation = events.continuation
    }

    func health(at address: ServerAddress, pinnedTo fingerprint: SpkiFingerprint) async throws(ApiFailure) -> HealthResponse {
        let invocationIndex = invocations.count
        let answer = sequentialAnswers.indices.contains(invocationIndex)
            ? sequentialAnswers[invocationIndex]
            : answers[address] ?? .success(answering)
        invocations.append(Invocation(address: address, fingerprint: fingerprint))
        invocationContinuation.yield(address)
        if let prerequisite = waitingFor[address] {
            await waitUntilAsked(at: prerequisite)
        }
        await beforeAnswering()
        switch answer {
        case .success(let response): return response
        case .failure(let failure): throw failure
        }
    }

    private func waitUntilAsked(at address: ServerAddress) async {
        if invocations.contains(where: { $0.address == address }) { return }
        for await invocation in invocationEvents {
            if invocation == address { return }
        }
    }
}
