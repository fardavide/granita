import ClientConnectionDomain

actor FakeDiagnosticLogsCopying: DiagnosticLogsCopying {

    private(set) var invocations = 0

    private let answer: Result<Void, DiagnosticCopyFailure>
    private var contexts: [DiagnosticContext] = []

    init(answering answer: Result<Void, DiagnosticCopyFailure>) {
        self.answer = answer
    }

    func copy(context: DiagnosticContext) async throws(DiagnosticCopyFailure) {
        invocations += 1
        contexts.append(context)
        switch answer {
        case .success:
            return
        case .failure(let failure):
            throw failure
        }
    }

    func lastContext() -> DiagnosticContext? {
        contexts.last
    }
}
