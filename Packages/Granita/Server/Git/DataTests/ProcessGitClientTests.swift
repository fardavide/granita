import Foundation
import Testing

import ServerGitDomain
@testable import ServerGitData

/// Driven against the repositories `make fixtures` builds under `.fixtures/`, with the real git
/// binary. There is nothing to fake here — the whole point of this type is what the binary does,
/// and every behaviour below was a defect in some earlier design of it.
///
/// Serialised for the same reason the API suite is: these spawn real git processes, one of them
/// deliberately kills one mid-flight, and running them alongside everything else saturates a CI
/// runner into timing every invocation out.
///
/// Serialised for the same reason the API suite is, with one of its own: one test here kills a git
/// process mid-flight, which is not something to do beside two dozen others that are mid-flight too.
@Suite("Process git client", .serialized)
struct ProcessGitClientTests {

    // MARK: - Reading an answer back

    @Test
    func `given a checkout when asking for its root then the answer is the path and nothing else`() async throws {
        // given
        let scenario = try Scenario(repository: .main)

        // when
        let output = try await scenario.sut.run(.repositoryRoot, in: scenario.location)

        // then — `rev-parse` accepts `--no-color` by printing it as an output line rather than by
        // failing, so a vector carrying the diff-family flags returns "--no-color" as the root of
        // the repository, exits 0, and looks entirely healthy.
        #expect(scenario.text(of: output) == scenario.location.path + "\n")
    }

    @Test
    func `given a repository with no commits when asking for the head commit then the answer is empty`(
    ) async throws {
        // given
        let scenario = try Scenario(repository: .unborn)

        // when
        let output = try await scenario.sut.run(.headCommit, in: scenario.location)

        // then — exit 1 here means "there is no commit yet", which is an answer rather than a
        // failure. Reading it as one would make every fresh project an error on the phone.
        #expect(scenario.text(of: output) == "")
        #expect(output.isTruncated == false)
    }

    @Test
    func `given an untracked file when diffing it then git exiting one is not a failure`() async throws {
        // given
        let scenario = try Scenario(repository: .main)

        // when
        let output = try await scenario.sut.run(
            .untrackedFileDiff(path: RepositoryRelativePath("src/untracked.txt"), contextLines: 3),
            in: scenario.location
        )

        // then — `git diff --no-index` exits 1 whenever the two sides differ, which for an
        // untracked file rendered against the null device is every single time.
        #expect(scenario.text(of: output).contains("+never staged"))
    }

    // MARK: - Handing the vector to the library that spawns the process

    @Test
    func `when the vector is handed to the subprocess library then every argument carries its terminator`(
    ) {
        // given — the longest vector this product builds, and the one whose corruption is silent:
        // everything after `--` is a pathspec, and a pathspec that matches nothing makes git print
        // nothing, say nothing on standard error and exit 0.
        let command = GitCommand.fileDiff(
            path: RepositoryRelativePath("src/deep/nested/directory/with/a/long/name/file.txt"),
            against: .head,
            contextLines: 3
        )

        // when
        let vector = ProcessGitClient.terminated(GitInvocation.arguments(for: command))

        // then — a Swift array carries its length beside it and nothing after it, and the library
        // hands each element straight to `strdup`, which reads on until it meets a zero byte. An
        // argument without one arrives at git with whatever the allocator left next to it stuck on
        // the end. Measured: a real worktree served two of its ten files as an empty diff.
        #expect(vector.allSatisfy { $0.last == 0 })
        // Exactly one, at the end. A second would end the argument early instead of late, which is
        // the same defect wearing the opposite sign.
        #expect(vector.allSatisfy { $0.dropLast().contains(0) == false })
        // And nothing else about the vector moved: this adds a terminator and is not a second place
        // where what git is asked gets decided.
        #expect(vector.map { Array($0.dropLast()) } == GitInvocation.arguments(for: command))
    }

    // MARK: - Hardening, proven against a repository configured to defeat it

    @Test
    func `given a repository that strips the diff path prefixes when diffing then they survive`() async throws {
        // given — `.fixtures/hostile` sets diff.noprefix, diff.mnemonicPrefix, core.quotePath,
        // color.ui and an external diff tool in its own config, where a child process reads them
        // whatever the environment says.
        let scenario = try Scenario(repository: .hostile)

        // when
        let output = try await scenario.sut.run(
            .fileDiff(path: RepositoryRelativePath("caffè.txt"), against: .head, contextLines: 3),
            in: scenario.location
        )

        // then — the parser removes a leading `a/` and `b/` from every path, so without the pinned
        // prefixes it takes the first two characters off instead, with nothing failing anywhere.
        let text = scenario.text(of: output)
        #expect(text.hasPrefix("diff --git a/caffè.txt b/caffè.txt\n"))
        // The path is spelled as it is on disk rather than octal-escaped, the output carries no
        // colour escapes, and it is git's diff rather than an external tool's.
        #expect(text.contains("\\303") == false)
        #expect(text.contains("\u{1B}[") == false)
        #expect(text.contains("+BETA"))
    }

    @Test
    func `given a repository that hides untracked files when asking for its status then they are there`(
    ) async throws {
        // given
        let scenario = try Scenario(repository: .hostile)

        // when
        let output = try await scenario.sut.run(.worktreeStatus, in: scenario.location)

        // then — `status.showUntrackedFiles=no` empties this section, and its bytes are what the
        // worktree's revision is hashed from, so the phone would never learn the file appeared.
        #expect(scenario.text(of: output).contains("? untracked.txt"))
    }

    // MARK: - Failing in a way that can be read from a phone

    @Test
    func `given a path the revision does not have when asking for its content then git's words survive`(
    ) async throws {
        // given
        let scenario = try Scenario(repository: .main)

        // when
        let error = await scenario.failure(from: .fileContent(
            path: RepositoryRelativePath("src/never-existed.txt"),
            at: .head
        ))

        // then
        guard case .commandFailed(_, let exitCode, let standardError) = error else {
            Issue.record("expected a refusal from git, got \(String(describing: error))")
            return
        }
        // Standard error is the only thing that makes a git failure diagnosable from a phone, so it
        // is carried rather than collapsed into a code.
        #expect(exitCode == 128)
        #expect(standardError.contains("src/never-existed.txt"))
    }

    @Test
    func `given a directory that is not there when running then the failure names the directory`() async throws {
        // given
        let scenario = try Scenario(location: RepositoryLocation(path: "/nowhere/granita-does-not-exist"))

        // when
        let error = await scenario.failure(from: .repositoryRoot)

        // then — a worktree an agent removed while the phone was reading it lands here, and it is
        // the worktree that is gone rather than anything being wrong with git.
        guard case .workingDirectoryUnreadable(let location, _) = error else {
            Issue.record("expected an unreadable working directory, got \(String(describing: error))")
            return
        }
        #expect(location.path == "/nowhere/granita-does-not-exist")
    }

    @Test
    func `given no git binary where it was expected when running then the failure says so`() async throws {
        // given
        let scenario = try Scenario(repository: .main, executablePath: "/usr/bin/granita-not-git")

        // when
        let error = await scenario.failure(from: .repositoryRoot)

        // then
        guard case .gitUnavailable = error else {
            Issue.record("expected git to be reported unavailable, got \(String(describing: error))")
            return
        }
    }

    // MARK: - The guards that stop a large repository taking the app down

    @Test
    func `given more output than the limit allows when running then what comes back says it is a prefix`(
    ) async throws {
        // given — small enough that git has more to say than will be read.
        let scenario = try Scenario(repository: .main, outputLimitBytes: 128)

        // when
        let output = try await scenario.sut.run(.trackedChanges(against: .head), in: scenario.location)

        // then — the cap is enforced by stopping the read and tearing git down. Letting the pipe
        // fill instead is a hang rather than a truncation: a macOS pipe buffers 64 KiB, and git
        // blocks writing into one nobody is emptying.
        #expect(output.isTruncated)
        #expect(output.standardOutput.count == 128)
    }

    @Test
    func `given git cannot finish in the time allowed when running then it is torn down and reported`(
    ) async throws {
        // given — no git invocation completes within a millisecond; spawning the process alone
        // costs more than that.
        let scenario = try Scenario(repository: .main, timeout: .milliseconds(1))

        // when
        let error = await scenario.failure(from: .worktreeStatus)

        // then
        guard case .timedOut = error else {
            Issue.record("expected a timeout, got \(String(describing: error))")
            return
        }
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: ProcessGitClient
        let location: RepositoryLocation

        init(
            location: RepositoryLocation,
            executablePath: String = "/usr/bin/git",
            outputLimitBytes: Int = ProcessGitClient.defaultOutputLimitBytes,
            timeout: Duration = ProcessGitClient.defaultTimeout
        ) {
            self.location = location
            sut = ProcessGitClient(
                executablePath: executablePath,
                outputLimitBytes: outputLimitBytes,
                timeout: timeout
            )
        }

        init(
            repository: FixtureRepository,
            executablePath: String = "/usr/bin/git",
            outputLimitBytes: Int = ProcessGitClient.defaultOutputLimitBytes,
            timeout: Duration = ProcessGitClient.defaultTimeout
        ) throws {
            self.init(
                location: try repository.location(),
                executablePath: executablePath,
                outputLimitBytes: outputLimitBytes,
                timeout: timeout
            )
        }

        func text(of output: GitOutput) -> String {
            String(decoding: output.standardOutput, as: UTF8.self)
        }

        /// Runs a command that is expected to fail and hands back what it failed with.
        func failure(from command: GitCommand) async -> GitError? {
            do {
                _ = try await sut.run(command, in: location)
                return nil
            } catch {
                return error
            }
        }
    }
}
