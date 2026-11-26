import Foundation
import Testing

import CoreApiDomain
import CoreDiffDomain

@Suite("Worktree scan issue encoding")
struct WorktreeScanIssueTests {
    @Test
    func `given a timed out scan when sharing its issue then old readers can decode it`() throws {
        // given
        let project = ProjectID(rawValue: "granita")
        let issue = WorktreeScanIssue(
            target: .project(project),
            projectID: project,
            name: "Granita",
            projectName: "Granita",
            reason: .gitTimedOut,
            lastRead: .never
        )

        // when
        let encoded = try JSONEncoder().encode(issue)

        // then
        #expect(try JSONDecoder().decode(LegacyIssue.self, from: encoded).reason == .gitFailure)
        #expect(try JSONDecoder().decode(WorktreeScanIssue.self, from: encoded) == issue)
    }

    private struct LegacyIssue: Decodable {
        let reason: Reason

        enum Reason: String, Decodable {
            case gitFailure
            case staleRegistration
        }
    }
}
