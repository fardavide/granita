import ClientConnectionData
import ClientConnectionDomain
import Testing
import UIKit

/// *Copy Logs* against a real `UIPasteboard`, which is the one thing a fake cannot answer: did the
/// report reach the place a paste would find it.
///
/// **Its own named board, never the general one.** This is the same call the AppKit sibling made and
/// for a second reason on this platform: the general pasteboard is a system service shared with
/// everything else on the simulator, and saving and restoring it around a write meant reading
/// `items` off a daemon that does not reliably answer. Written that way, this test blocked the whole
/// phone snapshot suite indefinitely at 0% CPU — every baseline in the bundle behind one clipboard
/// read. A named board is private to this process, needs no save and restore, and cannot wait on
/// anything outside it.
@Suite(.serialized)
@MainActor
struct DiagnosticClipboardIntegrationTests {

    @Test
    func `given a diagnostic report when copied through the iOS adapter then the pasteboard has the full safe report`(
    ) async throws {
        // given
        let report = "Granita 0.11.0\nNSURLErrorDomain (-1200)"
        let name = UIPasteboard.Name("dev.fardavide.granita.tests.diagnostics")
        let scenario = Scenario(report: report, name: name)
        defer { UIPasteboard.remove(withName: name) }

        // when
        try await scenario.sut.copy(
            context: .discovery(.failed(diagnostic: "private discovery diagnostic"))
        )

        // then — the report, plus the two lines the context adds, and nothing of the diagnostic the
        // screen was holding: that string is deliberately not in what leaves this device.
        let pasteboard = try #require(UIPasteboard(name: name, create: false))
        #expect(pasteboard.string == report + "\n\nCurrent screen: discovery\nFailure: failed")
    }

    // MARK: - Scenario

    @MainActor
    private struct Scenario {

        let sut: CopyDiagnosticLogs

        init(report: String, name: UIPasteboard.Name) {
            sut = CopyDiagnosticLogs(
                report: FakeDiagnosticReportProviding(report: report),
                pasteboard: SystemDiagnosticPasteboard(name: name)
            )
        }
    }
}
