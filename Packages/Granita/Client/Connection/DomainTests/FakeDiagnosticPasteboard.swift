import ClientConnectionDomain

actor FakeDiagnosticPasteboard: DiagnosticPasteboard {

    private var copyInvocations: [String] = []

    func copy(_ text: String) async throws(DiagnosticCopyFailure) {
        copyInvocations.append(text)
    }

    func lastCopy() -> String? {
        copyInvocations.last
    }
}
