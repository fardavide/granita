import Testing

import ServerMacDomain

/// What Advanced says about git, read out of `git --version`.
///
/// `GitExecutablePath` picks the first of three candidates that is executable, and the interesting
/// question is never which of the three won — it is whether the one that won works. A path that is
/// executable and broken is indistinguishable from a good one until something runs it, which is why
/// this row runs it.
@Suite("Git installation")
struct GitInstallationTests {

    @Test
    func `given git answers when its version is read then the number alone is kept`() {
        // given - when
        let installation = GitInstallation.reading("git version 2.52.0\n", at: "/opt/homebrew/bin/git")

        // then — the row reads the version first and the path second, so the version has to be the
        // number rather than the sentence git wrote around it.
        #expect(installation == .available(version: "2.52.0", path: "/opt/homebrew/bin/git"))
    }

    @Test
    func `given Apple's git answers when its version is read then its build suffix is dropped`() {
        // given — the git at /usr/bin is Apple's, and it names its own build after the version.
        // That suffix is longer than the number and is not what the row is asking.
        let output = "git version 2.39.5 (Apple Git-154)\n"

        // when
        let installation = GitInstallation.reading(output, at: "/usr/bin/git")

        // then
        #expect(installation == .available(version: "2.39.5", path: "/usr/bin/git"))
    }

    @Test
    func `given something that is not git answers when its version is read then it is unavailable`() {
        // given — a path that is executable and is not git. It exits 0 and prints something, which
        // is why an exit status is not enough to call this working.
        let installation = GitInstallation.reading("Python 3.14.7\n", at: "/usr/bin/git")

        // then
        #expect(installation == .unavailable(reason: "Python 3.14.7"))
    }

    @Test
    func `given git prints nothing at all when its version is read then it is unavailable`() {
        // given - when
        let installation = GitInstallation.reading("   \n", at: "/usr/bin/git")

        // then — an empty reason would draw the failure row with nothing under it, which says less
        // than the row above it already did.
        #expect(installation == .unavailable(reason: "git printed no version."))
    }
}
