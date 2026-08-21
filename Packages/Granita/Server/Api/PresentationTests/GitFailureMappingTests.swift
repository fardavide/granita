import Testing

import ServerGitDomain
@testable import ServerApiPresentation

/// Which screen a reader is shown when git refuses. Each of these is a different situation and a
/// different thing to do about it, so collapsing them into one code would be the same as having
/// none.
@Suite("Git failure mapping")
struct GitFailureMappingTests {

    @Test
    func `given git refused when it is reported then its own words reach the phone`() {
        // given
        let error = GitError.commandFailed(
            command: .worktreeStatus,
            exitCode: 128,
            standardError: "fatal: not a git repository"
        )

        // when
        let mapped = GranitaRouter.gitFailure(error)

        // then — standard error is the only thing that makes this diagnosable three rooms away.
        #expect(mapped.error.code == .gitFailure)
        #expect(mapped.error.message.contains("not a git repository"))
        #expect(mapped.error.message.contains("128"))
    }

    @Test
    func `given the worktree's directory is gone when it is reported then it is not called a git fault`() {
        // given — an agent removing a worktree while the phone is reading it is ordinary, and the
        // client drops the worktree rather than showing anyone an error.
        let error = GitError.workingDirectoryUnreadable(
            location: RepositoryLocation(path: "/repo/slice"),
            reason: "no such file or directory"
        )

        // when - then
        #expect(GranitaRouter.gitFailure(error).error.code == .worktreeGone)
    }

    @Test
    func `given git could not be run at all when it is reported then the reason survives`() {
        // given — nothing got far enough to write a line of standard error, so the operating
        // system's reason is all there is.
        let error = GitError.gitUnavailable(reason: "executable not found")

        // when
        let mapped = GranitaRouter.gitFailure(error)

        // then
        #expect(mapped.error.code == .gitFailure)
        #expect(mapped.error.message.contains("executable not found"))
    }

    @Test
    func `given git died on a signal when it is reported then the signal is named`() {
        // given — git does not do this on its own, so the number is the whole diagnosis.
        let error = GitError.terminatedBySignal(
            command: .worktreeStatus,
            signal: 9,
            standardError: ""
        )

        // when
        let mapped = GranitaRouter.gitFailure(error)

        // then
        #expect(mapped.error.code == .gitFailure)
        #expect(mapped.error.message.contains("9"))
    }

    @Test
    func `given git ran out of time when it is reported then it says that rather than nothing`() {
        // given
        let error = GitError.timedOut(command: .trackedChanges(against: .head))

        // when
        let mapped = GranitaRouter.gitFailure(error)

        // then
        #expect(mapped.error.code == .gitFailure)
        #expect(mapped.error.message.isEmpty == false)
    }

    @Test
    func `given a failure that is not git's when it is reported then it is still reported`() {
        // given — the catch has to hold anything, or a surprise becomes an empty 500.
        struct Surprise: Error {}

        // when
        let mapped = GranitaRouter.gitFailure(Surprise())

        // then
        #expect(mapped.error.code == .gitFailure)
        #expect(mapped.error.message.isEmpty == false)
    }
}
