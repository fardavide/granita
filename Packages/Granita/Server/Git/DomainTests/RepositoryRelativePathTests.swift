import Foundation
import Testing

import ServerGitDomain

/// A path is bytes, and every place a person reads one it has to be the path.
@Suite("Repository relative path")
struct RepositoryRelativePathTests {

    @Test
    func `given a path when it is written into a sentence then it reads as the path`() {
        // given — the synthesised description is `RepositoryRelativePath(bytes: 36 bytes)`, which
        // names the one thing nobody needs. Eleven of those in a log line pushed git's own error
        // past the unified log's truncation, so a failing `hash-object` had to be reproduced by
        // hand rather than read.
        let path = RepositoryRelativePath(".ai/skills/personal-build-test")

        // when - then
        #expect("\(path)" == ".ai/skills/personal-build-test")
    }

    @Test
    func `given bytes that are not valid text when the path is written then it still reads as something`() {
        // given — paths on disk are bytes and git will hand over one that is not UTF-8 eventually.
        // A description that trapped, or that fell back to the byte count, would fail exactly when
        // somebody is trying to find out which path went wrong.
        let path = RepositoryRelativePath(bytes: Data([0x61, 0xff, 0x62]))

        // when - then
        #expect("\(path)" == path.text)
        #expect("\(path)".contains("bytes:") == false)
    }
}
