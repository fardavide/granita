import Foundation
import Testing

import ServerGitDomain
import ServerMacDomain
@testable import ServerMacData

/// What Advanced says about git, and what it says when git cannot answer.
///
/// The row exists because `GitExecutablePath` picks the first of three candidates that is
/// executable, and a path that is executable and broken is indistinguishable from a good one until
/// something runs it. So the interesting assertions here are the failures: each one has to arrive
/// carrying git's own words, because those words are the only thing that tells a reader which of
/// them they are looking at.
@Suite("Process git installations")
struct ProcessGitInstallationsTests {

    @Test
    func `given a git that answers when it is asked then the row gets a version and a path`() async {
        // given
        let sut = ProcessGitInstallations(
            git: FakeGitClient(answer: .success("git version 2.52.0\n")),
            executablePath: "/opt/homebrew/bin/git"
        )

        // when
        let installation = await sut.current()

        // then
        #expect(installation == .available(version: "2.52.0", path: "/opt/homebrew/bin/git"))
    }

    @Test
    func `given git refuses when it is asked then the row carries git's own standard error`() async {
        // given — the failure a reader can act on, and the reason this row runs git rather than
        // reporting the path that won: the command line tools point at a developer directory that
        // is not there any more.
        let sut = ProcessGitInstallations(
            git: FakeGitClient(answer: .failure(.commandFailed(
                command: .version,
                exitCode: 1,
                standardError: "xcrun: error: invalid active developer path"
            ))),
            executablePath: "/usr/bin/git"
        )

        // when
        let installation = await sut.current()

        // then
        #expect(installation == .unavailable(reason: "xcrun: error: invalid active developer path"))
    }

    @Test
    func `given nothing runnable at the path when git is asked then the system's reason is kept`() async {
        // given — nothing got far enough to write a line of standard error, so the operating
        // system's words are all there are.
        let sut = ProcessGitInstallations(
            git: FakeGitClient(answer: .failure(.gitUnavailable(reason: "No such file or directory"))),
            executablePath: "/opt/homebrew/bin/git"
        )

        // when
        let installation = await sut.current()

        // then
        #expect(installation == .unavailable(reason: "No such file or directory"))
    }

    @Test
    func `given git never answers when it is asked then the row says so rather than staying blank`() async {
        // given — a timeout carries nothing of git's, and a row left on "—" for ever would read as
        // a question that was never asked.
        let sut = ProcessGitInstallations(
            git: FakeGitClient(answer: .failure(.timedOut(command: .version))),
            executablePath: "/usr/bin/git"
        )

        // when
        let installation = await sut.current()

        // then
        #expect(installation == .unavailable(reason: "git did not answer in time."))
    }

    @Test
    func `given git dies on a signal without a word when it is asked then the signal is named`() async {
        // given
        let sut = ProcessGitInstallations(
            git: FakeGitClient(answer: .failure(.terminatedBySignal(
                command: .version,
                signal: 9,
                standardError: ""
            ))),
            executablePath: "/usr/bin/git"
        )

        // when
        let installation = await sut.current()

        // then — an empty reason would draw the failure row with nothing under it, which says less
        // than the row above it already did.
        #expect(installation == .unavailable(reason: "git was killed by signal 9."))
    }

    @Test
    func `given a directory that cannot be read when git is asked then that reason survives`() async {
        // given
        let sut = ProcessGitInstallations(
            git: FakeGitClient(answer: .failure(.workingDirectoryUnreadable(
                location: RepositoryLocation(path: "/nowhere"),
                reason: "Permission denied"
            ))),
            executablePath: "/usr/bin/git"
        )

        // when
        let installation = await sut.current()

        // then
        #expect(installation == .unavailable(reason: "Permission denied"))
    }

    @Test
    func `given the version is asked for then it is asked of the binary rather than of a checkout`() async {
        // given — `git --version` is the one question here that is not about a repository, so the
        // location is only a working directory for the child process. It has to be one that exists.
        let git = FakeGitClient(answer: .success("git version 2.52.0\n"))
        let sut = ProcessGitInstallations(git: git, executablePath: "/usr/bin/git")

        // when
        _ = await sut.current()

        // then
        #expect(await git.asked() == .version)
        #expect(FileManager.default.fileExists(atPath: await git.location()?.path ?? ""))
    }
}

// MARK: -

/// git, without a git.
private actor FakeGitClient: GitClient {

    private let answer: Result<String, GitError>
    private var command: GitCommand?
    private var ranIn: RepositoryLocation?

    init(answer: Result<String, GitError>) {
        self.answer = answer
    }

    func run(_ command: GitCommand, in location: RepositoryLocation) throws(GitError) -> GitOutput {
        self.command = command
        ranIn = location
        switch answer {
        case .success(let output):
            return GitOutput(standardOutput: Data(output.utf8), isTruncated: false)
        case .failure(let error):
            throw error
        }
    }

    func asked() -> GitCommand? { command }
    func location() -> RepositoryLocation? { ranIn }
}
