import Foundation
import Testing

import CoreDiffDomain
import ServerApiPresentation
import ServerGitDomain

@Suite("Worktree read profile")
struct WorktreeReadProfileTests {

    @Test
    func `given an offline read with a failed status probe when rendering its profile then counts costs and the missing connection scope are explicit`() {
        // given - when
        let scenario = Scenario(
            enabledProjectCount: 3,
            duration: .seconds(4),
            gitMeasurements: [
                GitCommandMeasurement(command: .worktreeStatus, duration: .milliseconds(100), outcome: .succeeded),
                GitCommandMeasurement(command: .worktreeStatus, duration: .milliseconds(250), outcome: .failed)
            ]
        )

        // then
        #expect(scenario.sut.text == """
        Enabled projects: 3
        Worktrees: 0
        Changed files: 0
        Server processing: 4.0 seconds
        Git subprocesses: 0.35 seconds
        status: 2 calls, 1 failed, 0.35 seconds
        Offline profile: connection discovery and HTTPS verification are not included.
        """)
    }

    @Test
    func `given repeated status and content hash commands with distinct paths when profiling a read then groups combine calls failures and duration in stable order`() {
        // given
        let measurements = [
            GitCommandMeasurement(command: .hashWorktreeFiles(paths: [RepositoryRelativePath("Sources/Connection.swift")]), duration: .milliseconds(300), outcome: .succeeded),
            GitCommandMeasurement(command: .worktreeStatus, duration: .milliseconds(100), outcome: .succeeded),
            GitCommandMeasurement(command: .hashWorktreeFiles(paths: [RepositoryRelativePath("Sources/Reader.swift"), RepositoryRelativePath("Tests/ReaderTests.swift")]), duration: .milliseconds(400), outcome: .succeeded),
            GitCommandMeasurement(command: .worktreeStatus, duration: .milliseconds(250), outcome: .failed)
        ]

        // when
        let scenario = Scenario(gitMeasurements: measurements)

        // then
        #expect(scenario.sut.gitBreakdown == [
            GitCommandProfile(group: .status, invocationCount: 2, failedCount: 1, duration: .milliseconds(350)),
            GitCommandProfile(group: .contentHash, invocationCount: 2, failedCount: 0, duration: .milliseconds(700))
        ])
    }

    @Test
    func `given multiple enabled projects and two worktrees in one project when profiling a read then counts and server and git durations remain distinct`() {
        // given
        let project = ProjectID(rawValue: "loading-profile-project")
        let worktrees = [
            Worktree(
                id: WorktreeID(rawValue: "loading-profile-primary"),
                projectId: project,
                projectName: "Loading profile",
                branch: "main",
                isPrimary: true,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: false,
                alias: nil,
                suggestedAlias: nil,
                displayName: "main",
                directoryName: "loading-profile",
                isPinned: false,
                stats: ChangeStats(filesChanged: 7, insertions: 43, deletions: 11),
                lastModified: Date(timeIntervalSince1970: 1_800_000_001),
                revision: "primary-profile-revision"
            ),
            Worktree(
                id: WorktreeID(rawValue: "loading-profile-branch"),
                projectId: project,
                projectName: "Loading profile",
                branch: "feat/loading",
                isPrimary: false,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: false,
                alias: nil,
                suggestedAlias: nil,
                displayName: "feat/loading",
                directoryName: "loading-branch",
                isPinned: true,
                stats: ChangeStats(filesChanged: 13, insertions: 89, deletions: 29),
                lastModified: Date(timeIntervalSince1970: 1_800_000_002),
                revision: "branch-profile-revision"
            )
        ]

        // when
        let scenario = Scenario(
            worktrees: worktrees,
            enabledProjectCount: 3,
            duration: .seconds(4),
            gitMeasurements: [
                GitCommandMeasurement(command: .worktrees, duration: .milliseconds(347), outcome: .succeeded),
                GitCommandMeasurement(command: .worktreeStatus, duration: .milliseconds(1_230), outcome: .succeeded)
            ]
        )

        // then
        #expect(scenario.sut.projectCount == 3)
        #expect(scenario.sut.worktreeCount == 2)
        #expect(scenario.sut.changedFileCount == 20)
        #expect(scenario.sut.serverDuration == .seconds(4))
        #expect(scenario.sut.gitDuration == .milliseconds(1_577))
    }

    private struct Scenario {
        let sut: WorktreeReadProfile

        init(worktrees: [Worktree] = [], enabledProjectCount: Int = 0, duration: Duration = .zero, gitMeasurements: [GitCommandMeasurement]) {
            sut = WorktreeReadProfile(
                worktrees: worktrees,
                enabledProjectCount: enabledProjectCount,
                duration: duration,
                gitMeasurements: gitMeasurements
            )
        }
    }
}
