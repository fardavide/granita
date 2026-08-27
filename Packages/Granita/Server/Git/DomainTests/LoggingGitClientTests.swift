import Foundation
import Testing

import CoreDiagnosticsDomain
import ServerGitDomain

/// What a reader learns from the log about the git this Mac ran.
///
/// Design §7's footnote promises the verbose switch records *every git invocation*, and this is the
/// half that produces them. The half that decides whether they survive the switch is
/// `VerbosityFilteringDiagnostics`; this one always says everything and lets that decide.
@Suite("Logging git client")
struct LoggingGitClientTests {

    @Test
    func `given git answers when a command is run then what was asked is recorded`() async throws {
        // given
        let scenario = Scenario(failure: nil)

        // when
        _ = try await scenario.sut.run(.currentBranch, in: RepositoryLocation(path: "/repo/aura"))

        // then — where it ran is part of it: one Mac serves many worktrees, and a line naming a
        // command without naming which checkout it ran in cannot be matched to anything.
        #expect(scenario.log.details.first == "currentBranch in /repo/aura")
    }

    @Test
    func `given git answers when a command is run then the answer arriving is recorded too`() async throws {
        // given
        let scenario = Scenario(failure: nil)

        // when
        _ = try await scenario.sut.run(.worktrees, in: RepositoryLocation(path: "/repo/aura"))

        // then — the pair is what makes a hang readable. A command with no answer beside it is how a
        // reader sees that git never came back, which the ten-second budget otherwise hides.
        #expect(scenario.log.details == ["worktrees in /repo/aura", "worktrees answered"])
    }

    @Test
    func `given git answers when a command is run then what it said is not recorded`() async throws {
        // given — the standard output here is the contents of a private repository, and the whole
        // product exists to keep that on one machine. A log has a different lifetime and different
        // readers than the thing it was taken from.
        let secret = "the contents of a private repository"
        let scenario = Scenario(output: Data(secret.utf8), failure: nil)

        // when
        _ = try await scenario.sut.run(.worktrees, in: RepositoryLocation(path: "/repo/aura"))

        // then
        #expect(scenario.log.details.contains { $0.contains(secret) } == false)
        #expect(scenario.log.notes.contains { $0.contains(secret) } == false)
    }

    @Test
    func `given git fails when a command is run then the failure is noted rather than detailed`() async {
        // given — a failed invocation is why somebody is reading this at all, so it must not be
        // behind a switch they had to think of turning on first.
        let scenario = Scenario(failure: .gitUnavailable(reason: "No such file or directory"))

        // when
        _ = try? await scenario.sut.run(.version, in: RepositoryLocation(path: "/repo/aura"))

        // then
        #expect(scenario.log.notes.count == 1)
        #expect(scenario.log.notes.first?.contains("No such file or directory") == true)
    }

    /// **Git's own sentence has to survive the unified log, which truncates at about a kilobyte.**
    ///
    /// The line used to lead with the command, and a command carrying a batch of paths is longer
    /// than that on its own — so a failing `hash-object` over eleven files spent the whole budget on
    /// `RepositoryRelativePath(bytes: 36 bytes)` and cut off before git said why. That is not a
    /// hypothetical: it is why a symlink pointing at a directory had to be reproduced by hand
    /// instead of read off the log.
    ///
    /// Every case, because each one carries a different half of the answer and a `switch` that grew
    /// a case would otherwise lose it silently.
    @Test(arguments: [
        (
            GitError.commandFailed(command: .version, exitCode: 128, standardError: "fatal: Unable to hash link"),
            "fatal: Unable to hash link"
        ),
        (
            GitError.terminatedBySignal(command: .version, signal: 9, standardError: "killed"),
            "killed"
        ),
        (GitError.timedOut(command: .version), "timed out"),
        (GitError.gitUnavailable(reason: "No such file or directory"), "No such file or directory"),
        (
            GitError.workingDirectoryUnreadable(
                location: RepositoryLocation(path: "/gone"),
                reason: "the worktree is not there"
            ),
            "the worktree is not there"
        )
    ])
    func `given git fails in any way when it is logged then git's own words are in the line`(
        failure: GitError,
        words: String
    ) async {
        // given
        let scenario = Scenario(failure: failure)

        // when
        _ = try? await scenario.sut.run(.version, in: RepositoryLocation(path: "/repo/aura"))

        // then — and near the front of it, which is what surviving truncation means.
        let note = scenario.log.notes.first ?? ""
        #expect(note.contains(words))
        #expect(note.hasPrefix("git failed: "))
    }

    @Test
    func `given git fails when a command is run then the failure still reaches the caller`() async {
        // given — a decorator that swallowed what it logged would turn every git failure into a
        // worktree that silently has nothing in it.
        let scenario = Scenario(failure: .gitUnavailable(reason: "No such file or directory"))

        // when
        var thrown: GitError?
        do {
            _ = try await scenario.sut.run(.version, in: RepositoryLocation(path: "/repo/aura"))
        } catch {
            thrown = error
        }

        // then
        #expect(thrown == .gitUnavailable(reason: "No such file or directory"))
    }

    @Test
    func `given a command when it is run then it reaches the client unchanged`() async throws {
        // given
        let scenario = Scenario(failure: nil)

        // when
        _ = try await scenario.sut.run(.headCommit, in: RepositoryLocation(path: "/repo/aura"))

        // then
        #expect(await scenario.client.received == [.headCommit])
    }

    // MARK: -

    private struct Scenario {

        let sut: LoggingGitClient
        let client: FakeGitClient
        let log: FakeDiagnostics

        init(output: Data = Data(), failure: GitError?) {
            client = FakeGitClient(
                output: GitOutput(standardOutput: output, isTruncated: false),
                failure: failure
            )
            log = FakeDiagnostics()
            sut = LoggingGitClient(client: client, diagnostics: log)
        }
    }
}
