import ClientConnectionData
import ClientConnectionDomain
import Testing
import UIKit

@Suite(.serialized)
@MainActor
struct DiagnosticClipboardIntegrationTests {

    @Test
    func `given a diagnostic report when copied through the iOS adapter then the system clipboard contains the full safe report`() async throws {
        let report = "Granita 0.11.0\nNSURLErrorDomain (-1200)"
        let scenario = Scenario(report: report)
        let previousItems = UIPasteboard.general.items
        defer { UIPasteboard.general.items = previousItems }

        try await scenario.sut.copy(context: .discovery(.failed(diagnostic: "private discovery diagnostic")))

        #expect(UIPasteboard.general.string == report + "\n\nCurrent screen: discovery\nFailure: failed")
    }

    // MARK: - Scenario

    @MainActor
    private struct Scenario {

        let sut: CopyDiagnosticLogs

        init(report: String) {
            sut = CopyDiagnosticLogs(
                report: FakeDiagnosticReportProviding(report: report),
                pasteboard: SystemDiagnosticPasteboard()
            )
        }
    }
}
