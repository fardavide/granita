import Foundation
import Testing

import ClientConnectionData
import ClientConnectionDomain
import ServerGitDomain
import ServerReaderData

@Suite("Mac reader diagnostic report")
struct MacReaderDiagnosticReportTests {

    @Test
    func `given connection and Git failures when the Mac reader copies logs then the pasteboard holds both safe summaries`() async throws {
        // given
        let scenario = Scenario(at: Date(timeIntervalSince1970: 1_800_000_000))
        let stderr = "fatal: private Git diagnostic"
        await scenario.connections.record(.pinnedKeyMismatched(host: "review-mac.local", port: 8737))
        await scenario.gitFailures.record(.commandFailed(
            command: .fileDiff(path: RepositoryRelativePath("Sources/ConfidentialPlan.swift"), against: .head, contextLines: 3),
            exitCode: 128,
            standardError: stderr
        ))

        // when
        try await scenario.sut.copy(context: .diff(.gitFailure(message: stderr)))

        // then
        let copied = try #require(await scenario.pasteboard.lastCopy)
        #expect(copied.contains("Current app session · mac-side connection events only"))
        #expect(copied.contains("TLS https://review-mac.local:8737 — refused — pinned key mismatch"))
        #expect(copied.contains("Mac-side Git failures"))
        #expect(copied.contains("fileDiff exited 128"))
        #expect(copied.hasSuffix("Current screen: diff\nFailure: gitFailure"))
        #expect(!copied.contains("ConfidentialPlan.swift"))
        #expect(!copied.contains("private Git diagnostic"))
    }

    // MARK: - Scenario

    private struct Scenario {
        let connections: ConnectionLogs
        let gitFailures: GitFailureJournal
        let pasteboard: FakeDiagnosticPasteboard
        let sut: CopyDiagnosticLogs

        init(at date: Date) {
            connections = ConnectionLogs(
                context: ConnectionLogContext(
                    appVersion: "0.27.0", build: "208", systemVersion: "macOS 27.0", deviceModel: "Mac", reader: .mac
                ),
                capacity: 4,
                now: { date }
            )
            gitFailures = GitFailureJournal(capacity: 4, now: { date })
            pasteboard = FakeDiagnosticPasteboard()
            sut = CopyDiagnosticLogs(
                report: MacReaderDiagnosticReport(connections: connections, gitFailures: gitFailures),
                pasteboard: pasteboard
            )
        }
    }
}
