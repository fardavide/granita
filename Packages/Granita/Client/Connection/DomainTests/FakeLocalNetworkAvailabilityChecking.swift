import ClientConnectionDomain

struct FakeLocalNetworkAvailabilityChecking: LocalNetworkAvailabilityChecking {
    private let answering: LocalNetworkAvailability

    init(answering: LocalNetworkAvailability) { self.answering = answering }

    func availability() async -> LocalNetworkAvailability { answering }
}
