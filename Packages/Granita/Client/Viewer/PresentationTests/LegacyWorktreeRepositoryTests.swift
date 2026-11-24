import Foundation
import Synchronization
import Testing

import ClientConnectionDomain
import CoreDiffDomain

@Suite("Legacy worktree repository")
struct LegacyWorktreeRepositoryTests {

    @Test(arguments: [false, true])
    func `given an adapter only has a legacy list when worktrees are read then the rows are uncached`(
        refreshing: Bool
    ) async throws {
        // given
        let scenario = Scenario()
        let progress = Mutex<[WorktreeReadStage]>([])

        // when
        let read = try await scenario.repository.readWorktrees(
            inProject: ProjectID(rawValue: "draft-project"), refreshing: refreshing,
            reporting: { stage in progress.withLock { $0.append(stage) } }
        )

        // then
        #expect(read == .uncached([]))
        #expect(progress.withLock { $0 } == [.reading(.unknown)])
    }

    @Test(arguments: RecoveryRequest.allCases)
    func `given an adapter cannot recover worktrees when recovery is requested then the unsupported route is reported`(
        request: RecoveryRequest
    ) async {
        // given
        let scenario = Scenario()
        let worktree = WorktreeID(rawValue: "retired-draft")

        // when - then
        await #expect(throws: ApiFailure.routeNotServed) {
            switch request {
            case .retry: _ = try await scenario.repository.retryWorktreeScan(.worktree(worktree))
            case .preview: _ = try await scenario.repository.previewWorktreeRepair(worktree)
            case .approve: _ = try await scenario.repository.approveWorktreeRepair(.init(id: UUID()))
            }
        }
    }

    enum RecoveryRequest: CaseIterable, Sendable {
        case retry, preview, approve
    }

    private struct Scenario {
        let repository: any GranitaRepository = FakeGranitaRepository(changeSet: .failure(.worktreeGone))
    }
}
