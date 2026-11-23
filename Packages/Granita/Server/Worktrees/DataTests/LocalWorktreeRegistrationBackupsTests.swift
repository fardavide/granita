import Foundation
import Testing

import ServerGitDomain
import ServerWorktreesData
import ServerWorktreesDomain

struct LocalWorktreeRegistrationBackupsTests {

    @Test
    func `given another stale registration when backing up the approved one then the unapproved metadata stays`() throws {
        // given
        let scenario = try Scenario(registrations: ["approved", "unapproved"])
        defer { scenario.cleanUp() }
        let approved = try WorktreeRegistrationName("approved")
        let originalApprovedLink = try Data(contentsOf: scenario.gitdir(in: "approved"))
        let originalUnapprovedLink = try Data(contentsOf: scenario.gitdir(in: "unapproved"))

        // when
        try scenario.sut.backUp([approved], in: scenario.commonDirectory)

        // then
        let backups = try FileManager.default.contentsOfDirectory(at: scenario.backups, includingPropertiesForKeys: nil)
        try #require(backups.count == 1)
        let batch = try #require(backups.first)
        let saved = batch.appending(path: "approved/gitdir")
        #expect(try Data(contentsOf: saved) == originalApprovedLink)
        #expect(!FileManager.default.fileExists(atPath: scenario.gitdir(in: "approved").path))
        #expect(try Data(contentsOf: scenario.gitdir(in: "unapproved")) == originalUnapprovedLink)
    }

    private struct Scenario {
        let sut = LocalWorktreeRegistrationBackups()
        let directory: URL
        let commonDirectory: RepositoryLocation
        let backups: URL

        init(registrations: [String]) throws {
            directory = URL(filePath: "/private/tmp", directoryHint: .isDirectory)
                .appending(path: "granita-repair-\(UUID().uuidString)", directoryHint: .isDirectory)
            commonDirectory = RepositoryLocation(path: directory.path)
            backups = directory.appending(path: "granita-worktree-backups", directoryHint: .isDirectory)
            do {
                for name in registrations {
                    let path = gitdir(in: name)
                    try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Data("\(directory.path)/missing-\(name)/.git\n".utf8).write(to: path)
                }
            } catch {
                cleanUp()
                throw error
            }
        }

        func gitdir(in registration: String) -> URL {
            directory.appending(path: "worktrees/\(registration)/gitdir", directoryHint: .notDirectory)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
