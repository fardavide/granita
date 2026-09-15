import Foundation
import Testing

import ServerGitDomain
import ServerWorktreesDomain
@testable import ServerWorktreesData

/// The one reader in this product that opens a file by joining a path onto a directory, which is the
/// one place the rules that make that safe have to hold.
@Suite("Local worktree files")
struct LocalWorktreeFilesTests {

    @Test
    func `given a file in a checkout when its bytes are read then they come back whole`() async throws {
        // given — bytes that are not text, because a picture is what this reader exists for and a
        // round trip through a string would be the defect it could hide.
        let scenario = try Scenario(files: ["art/logo.png": Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])])
        defer { scenario.tearDown() }

        // when
        let read = try await scenario.sut.bytes(
            of: RepositoryRelativePath("art/logo.png"),
            in: scenario.location,
            upTo: 1_024
        )

        // then
        #expect(read == Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF]))
    }

    @Test
    func `given a file inside a directory when its bytes are read then the relative path is honoured`(
    ) async throws {
        // given — nested, so a reader that took only the last component would answer for the wrong
        // file or for none.
        let scenario = try Scenario(files: [
            "logo.png": Data([0x01]),
            "Apps/Snapshots/logo.png": Data([0x02, 0x03])
        ])
        defer { scenario.tearDown() }

        // when
        let read = try await scenario.sut.bytes(
            of: RepositoryRelativePath("Apps/Snapshots/logo.png"),
            in: scenario.location,
            upTo: 1_024
        )

        // then
        #expect(read == Data([0x02, 0x03]))
    }

    @Test
    func `given a file that is not there when its bytes are read then it says so rather than trapping`(
    ) async throws {
        // given — an agent deleting a file while the phone reads it is ordinary here.
        let scenario = try Scenario(files: [:])
        defer { scenario.tearDown() }

        // when - then
        await #expect(throws: WorktreeFileError.self) {
            try await scenario.sut.bytes(
                of: RepositoryRelativePath("art/gone.png"),
                in: scenario.location,
                upTo: 1_024
            )
        }
    }

    @Test
    func `given a file over the ceiling when its bytes are read then it is refused rather than trimmed`(
    ) async throws {
        // given — a prefix of a picture is not a smaller picture.
        let scenario = try Scenario(files: ["art/huge.png": Data(repeating: 0x7F, count: 512)])
        defer { scenario.tearDown() }

        // when - then
        await #expect(throws: WorktreeFileError.tooLarge) {
            try await scenario.sut.bytes(
                of: RepositoryRelativePath("art/huge.png"),
                in: scenario.location,
                upTo: 64
            )
        }
    }

    @Test
    func `given a file exactly at the ceiling when its bytes are read then it is served`() async throws {
        // given — the boundary is inclusive, so a budget stated as a maximum is not one byte under.
        let scenario = try Scenario(files: ["art/exact.png": Data(repeating: 0x7F, count: 64)])
        defer { scenario.tearDown() }

        // when
        let read = try await scenario.sut.bytes(
            of: RepositoryRelativePath("art/exact.png"),
            in: scenario.location,
            upTo: 64
        )

        // then
        #expect(read.count == 64)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut = LocalWorktreeFiles()
        let location: RepositoryLocation

        private let root: URL

        init(files: [String: Data]) throws {
            root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
                .appending(path: "granita-worktree-files-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for (path, bytes) in files {
                let url = root.appending(path: path, directoryHint: .notDirectory)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try bytes.write(to: url)
            }
            location = RepositoryLocation(path: root.path(percentEncoded: false))
        }

        func tearDown() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
