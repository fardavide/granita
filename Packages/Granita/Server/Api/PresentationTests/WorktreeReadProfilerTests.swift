import Foundation
import Testing

import CoreDiffDomain
import ServerApiDomain
import ServerApiPresentation
import ServerGitDomain

@Suite("Worktree read profiler")
struct WorktreeReadProfilerTests {

    @Test(.timeLimit(.minutes(1)))
    func `given a registry read records git while suspended when profiling it then the whole read and its recorded commands contribute to the result`() async throws {
        // given
        let scenario = Scenario()
        let project = ProjectID(rawValue: "profiled-registry-project")
        let worktrees = [
            Worktree(
                id: WorktreeID(rawValue: "profiled-registry-primary"),
                projectId: project,
                projectName: "Profiled registry",
                branch: "main",
                isPrimary: true,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: false,
                alias: nil,
                suggestedAlias: nil,
                displayName: "main",
                directoryName: "profiled-registry",
                isPinned: false,
                stats: ChangeStats(filesChanged: 7, insertions: 51, deletions: 17),
                lastModified: Date(timeIntervalSince1970: 1_800_000_011),
                revision: "profiled-registry-primary-revision"
            ),
            Worktree(
                id: WorktreeID(rawValue: "profiled-registry-feature"),
                projectId: project,
                projectName: "Profiled registry",
                branch: "feat/profile",
                isPrimary: false,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: false,
                alias: nil,
                suggestedAlias: nil,
                displayName: "feat/profile",
                directoryName: "profiled-feature",
                isPinned: true,
                stats: ChangeStats(filesChanged: 13, insertions: 97, deletions: 31),
                lastModified: Date(timeIntervalSince1970: 1_800_000_012),
                revision: "profiled-registry-feature-revision"
            )
        ]

        // when
        let profile = try await scenario.sut.read(enabledProjectCount: 3, using: { () async throws(ApiError) -> [Worktree] in
            await scenario.sut.record(GitCommandMeasurement(command: .worktrees, duration: .milliseconds(347), outcome: .succeeded))
            await scenario.sut.record(GitCommandMeasurement(command: .worktreeStatus, duration: .milliseconds(1_230), outcome: .succeeded))
            return worktrees
        })

        // then
        #expect(profile.projectCount == 3)
        #expect(profile.worktreeCount == 2)
        #expect(profile.changedFileCount == 20)
        #expect(profile.serverDuration == .seconds(4))
        #expect(profile.gitDuration == .milliseconds(1_577))
    }

    private struct Scenario {
        let sut: WorktreeReadProfiler

        init() {
            sut = WorktreeReadProfiler(elapsedSince: { _ in .seconds(4) })
        }
    }
}
