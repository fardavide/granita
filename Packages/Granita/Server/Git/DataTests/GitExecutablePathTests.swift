import Testing

import ServerGitData

/// Both composition roots have to find the same binary, and being wrong here is the one failure
/// that makes every other part of the product useless.
@Suite("Git executable path")
struct GitExecutablePathTests {

    @Test
    func `given a candidate that is not there when the binary is looked for then the next one wins`() {
        // given - when
        let found = GitExecutablePath.firstAvailable(among: ["/usr/bin/definitely-not-git", "/usr/bin/git"])

        // then
        #expect(found == "/usr/bin/git")
    }

    @Test
    func `given nowhere left to look when the binary is looked for then that is said rather than guessed`() {
        // given — a Mac with no command line tools is a real machine, and the Mac app has to be
        // able to say so rather than fail on the first diff with a path that never existed.
        let found = GitExecutablePath.firstAvailable(among: ["/usr/bin/definitely-not-git"])

        // then
        #expect(found == nil)
    }
}
