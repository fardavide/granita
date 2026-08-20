import Foundation
import Testing

@testable import CoreDiffDomain

/// The identifiers are the API's security boundary, not decoration: the server streams private
/// source code, and every addressable parameter is one of these rather than a filesystem path.
@Suite("Identifiers")
struct IdentifierTests {

    @Test
    func `given a repository path when deriving a project identifier then it is stable and opaque`() {
        // given
        let path = "/Users/davide/Dev/Projects/Granita"

        // when
        let first = ProjectID(canonicalPath: path)
        let second = ProjectID(canonicalPath: path)

        // then — stable, so a phone can hold onto it, and revealing nothing about the path.
        #expect(first == second)
        #expect(first.rawValue.count == 32)
        #expect(!first.rawValue.contains("Granita"))
        #expect(first.rawValue.allSatisfy { $0.isHexDigit })
    }

    @Test
    func `given two different paths when deriving identifiers then they differ`() {
        // given - when
        let one = ProjectID(canonicalPath: "/a/Granita")
        let other = ProjectID(canonicalPath: "/b/Granita")

        // then — the last component is the same, so a truncating hash of the wrong thing collides.
        #expect(one != other)
    }

    @Test
    func `given a repo-relative path when deriving a file identifier then it is stable and opaque`() {
        // given - when
        let identifier = FileID(repositoryRelativePath: "Sources/App/main.swift")

        // then
        #expect(identifier == FileID(repositoryRelativePath: "Sources/App/main.swift"))
        #expect(identifier.rawValue.count == 32)
        #expect(identifier.rawValue.allSatisfy { $0.isHexDigit })
    }

    @Test
    func `given a path that is not valid UTF-8 when deriving an identifier then it still derives one`() {
        // given — paths on disk are bytes, and git will hand us ones that are not valid UTF-8.
        // Hashing must not be the thing that fails on them.
        let bytes = Data([0x66, 0x6F, 0x6F, 0xFF, 0xFE, 0x2E, 0x74, 0x78, 0x74])

        // when
        let identifier = FileID(repositoryRelativePathBytes: bytes)

        // then
        #expect(identifier.rawValue.count == 32)
        #expect(identifier == FileID(repositoryRelativePathBytes: bytes))
    }

    @Test
    func `given a worktree path when deriving identifiers then a worktree and a project do not collide`() {
        // given — the same path is both a project root and its primary worktree.
        let path = "/Users/davide/Dev/Projects/Granita"

        // when
        let project = ProjectID(canonicalPath: path)
        let worktree = WorktreeID(canonicalPath: path)

        // then — distinct types, but the raw values would collide if both were a bare path hash,
        // and a collision here would let one be used where the other was meant.
        #expect(project.rawValue != worktree.rawValue)
    }
}
