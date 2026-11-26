import ClientConnectionDomain

actor FakeDiagnosticPasteboard: DiagnosticPasteboard {
    private(set) var lastCopy: String?

    func copy(_ text: String) async throws(DiagnosticCopyFailure) {
        lastCopy = text
    }
}
