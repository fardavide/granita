import ClientConnectionDomain

actor FakeDiagnosticLogsCopying: DiagnosticLogsCopying {
    private(set) var invocations = 0

    func copy(context: DiagnosticContext) async throws(DiagnosticCopyFailure) {
        invocations += 1
    }
}
