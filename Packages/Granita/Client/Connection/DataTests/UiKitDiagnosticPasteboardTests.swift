import Testing

import ClientConnectionData
import ClientConnectionDomain

@Suite("Diagnostic pasteboard")
struct UiKitDiagnosticPasteboardTests {
    @Test
    func `given a host without UIKit when copying diagnostics then it refuses rather than claiming success`() async {
        await #expect(throws: DiagnosticCopyFailure.unavailable) {
            try await UiKitDiagnosticPasteboard().copy("Granita diagnostics")
        }
    }
}
