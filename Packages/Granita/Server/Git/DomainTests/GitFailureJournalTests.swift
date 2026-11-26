import Foundation
import Testing

import ServerGitDomain

@Suite("Git failure journal")
struct GitFailureJournalTests {

    @Test
    func `given a failed file diff when reading the report then it includes the operation and exit code without private details`() async {
        // given
        let privatePath = "Sources/ConfidentialPlan.swift"
        let standardError = "fatal: private-diff-stderr-sentinel"
        let journal = GitFailureJournal(capacity: 4, now: { Date(timeIntervalSince1970: 0) })
        await journal.record(.commandFailed(
            command: .fileDiff(path: RepositoryRelativePath(privatePath), against: .head, contextLines: 3),
            exitCode: 173,
            standardError: standardError
        ))

        // when
        let report = await journal.report()

        // then
        #expect(report.contains("fileDiff"))
        #expect(report.contains("173"))
        #expect(report.contains("ConfidentialPlan.swift") == false)
        #expect(report.contains("private-diff-stderr-sentinel") == false)
    }
}
