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

    @Test(arguments: [
        (GitCommand.version, "version"),
        (.isInsideWorkTree, "isInsideWorkTree"),
        (.repositoryRoot, "repositoryRoot"),
        (.gitDirectory, "gitDirectory"),
        (.commonGitDirectory, "commonGitDirectory"),
        (.currentBranch, "currentBranch"),
        (.headCommit, "headCommit"),
        (.worktrees, "worktrees"),
        (.untrackedPaths, "untrackedPaths"),
        (.worktreeStatus, "worktreeStatus"),
        (.trackedChanges(against: .head), "trackedChanges"),
        (.trackedStats(against: .head), "trackedStats"),
        (.untrackedRenameStats(
            deleted: [RepositoryRelativePath("private-old.swift")],
            untracked: [RepositoryRelativePath("private-new.swift")],
            against: .head
        ), "untrackedRenameStats"),
        (.fileDiff(path: RepositoryRelativePath("private-old.swift"), against: .head, contextLines: 3), "fileDiff"),
        (.renamedFileDiff(
            from: RepositoryRelativePath("private-old.swift"),
            to: RepositoryRelativePath("private-new.swift"),
            against: .head,
            contextLines: 3
        ), "renamedFileDiff"),
        (.untrackedFileDiff(path: RepositoryRelativePath("private-new.swift"), contextLines: 3), "untrackedFileDiff"),
        (.fileContent(path: RepositoryRelativePath("private-old.swift"), at: .head), "fileContent"),
        (.removeWorktree(at: RepositoryLocation(path: "/private-checkout")), "removeWorktree"),
        (.previewWorktreePrune, "previewWorktreePrune"),
        (.hashWorktreeFiles(paths: [RepositoryRelativePath("private-old.swift")]), "hashWorktreeFiles")
    ])
    func `given a Git command times out when reading the report then it names the operation without its arguments`(
        command: GitCommand,
        name: String
    ) async {
        // given
        let journal = GitFailureJournal(capacity: 4, now: { Date(timeIntervalSince1970: 0) })
        await journal.record(.timedOut(command: command))

        // when
        let report = await journal.report()

        // then
        #expect(report.contains("\(name) timed out"))
        #expect(report.contains("private-") == false)
    }

    @Test(arguments: [
        (GitError.gitUnavailable(reason: "private-diagnostic"), "Git could not run"),
        (.workingDirectoryUnreadable(
            location: RepositoryLocation(path: "/private-checkout"),
            reason: "private-diagnostic"
        ), "Working directory unreadable"),
        (.terminatedBySignal(
            command: .worktreeStatus, signal: 9, standardError: "private-diagnostic"
        ), "worktreeStatus stopped by signal 9")
    ])
    func `given a process failure when reading the report then it provides a safe diagnostic`(
        failure: GitError,
        summary: String
    ) async {
        // given
        let journal = GitFailureJournal(capacity: 4, now: { Date(timeIntervalSince1970: 0) })
        await journal.record(failure)

        // when
        let report = await journal.report()

        // then
        #expect(report.contains(summary))
        #expect(report.contains("private-") == false)
    }

    @Test
    func `given an empty journal when reading the report then it says there are no Git failures`() async {
        // given
        let journal = GitFailureJournal(capacity: 4, now: { Date(timeIntervalSince1970: 0) })

        // when - then
        #expect(await journal.report().contains("No Git failures recorded"))
    }

    @Test
    func `given the journal is full when recording another failure then it keeps the most recent failure`() async {
        // given
        let journal = GitFailureJournal(capacity: 1, now: { Date(timeIntervalSince1970: 0) })
        await journal.record(.timedOut(command: .worktreeStatus))

        // when
        await journal.record(.timedOut(command: .worktrees))

        // then
        let report = await journal.report()
        #expect(report.contains("worktrees timed out"))
        #expect(report.contains("worktreeStatus") == false)
    }
}
