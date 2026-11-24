import Darwin
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

    @Test
    func `given no approved registrations when backing up then no common directory is needed`() throws {
        // given
        let scenario = try Scenario(registrations: ["approved"])
        defer { scenario.cleanUp() }
        let missing = RepositoryLocation(path: scenario.directory.appending(path: "missing-common").path)

        // when
        try scenario.sut.backUp([], in: missing)

        // then
        #expect(!FileManager.default.fileExists(atPath: missing.path))
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
    }

    @Test
    func `given approval names one registration twice when backing up then its metadata stays registered`() throws {
        // given
        let scenario = try Scenario(registrations: ["approved"])
        defer { scenario.cleanUp() }
        let approved = try WorktreeRegistrationName("approved")

        // when - then
        #expect(throws: WorktreePruneError.unavailable) {
            try scenario.sut.backUp([approved, approved], in: scenario.commonDirectory)
        }
        #expect(FileManager.default.fileExists(atPath: scenario.gitdir(in: "approved").path))
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
    }

    @Test(arguments: InvalidCommonDirectory.allCases)
    func `given the common directory cannot be opened safely when backing up then no metadata moves`(
        invalid: InvalidCommonDirectory
    ) throws {
        // given
        let scenario = try Scenario(registrations: ["approved"])
        defer { scenario.cleanUp() }
        let approved = try WorktreeRegistrationName("approved")
        let location = try invalid.location(in: scenario.directory)

        // when - then
        #expect(throws: WorktreePruneError.unavailable) {
            try scenario.sut.backUp([approved], in: location)
        }
        #expect(FileManager.default.fileExists(atPath: scenario.gitdir(in: "approved").path))
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
    }

    @Test(arguments: RegistrationChange.allCases)
    func `given the next registration no longer matches the preview when backing up then neither registration moves`(
        change: RegistrationChange
    ) throws {
        // given
        let scenario = try Scenario(registrations: ["approved", "other"])
        defer { scenario.cleanUp() }
        let approved = try WorktreeRegistrationName("approved")
        let other = try scenario.apply(change, to: "other")
        let originalApprovedLink = try Data(contentsOf: scenario.gitdir(in: "approved"))

        // when - then
        #expect(throws: change.refusal) {
            try scenario.sut.backUp([approved, other], in: scenario.commonDirectory)
        }
        #expect(try Data(contentsOf: scenario.gitdir(in: "approved")) == originalApprovedLink)
        #expect(FileManager.default.fileExists(atPath: scenario.registrationDirectory("other").path))
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
    }

    @Test
    func `given a prior backup and a relative gitdir link when removing another registration then both backups survive`() throws {
        // given
        let scenario = try Scenario(registrations: ["first", "second"])
        defer { scenario.cleanUp() }
        let first = try WorktreeRegistrationName("first")
        let second = try WorktreeRegistrationName("second")
        try scenario.sut.backUp([first], in: scenario.commonDirectory)
        let relativeLink = Data("../../absent-second/.git\r\n".utf8)
        try relativeLink.write(to: scenario.gitdir(in: "second"))

        // when
        try scenario.sut.backUp([second], in: scenario.commonDirectory)

        // then
        let batches = try FileManager.default.contentsOfDirectory(at: scenario.backups, includingPropertiesForKeys: nil)
        try #require(batches.count == 2)
        let savedSecond = try #require(batches.first {
            FileManager.default.fileExists(atPath: $0.appending(path: "second/gitdir").path)
        })
        #expect(try Data(contentsOf: savedSecond.appending(path: "second/gitdir")) == relativeLink)
        #expect(!FileManager.default.fileExists(atPath: scenario.gitdir(in: "second").path))
        #expect(batches.contains { FileManager.default.fileExists(atPath: $0.appending(path: "first/gitdir").path) })
    }

    @Test
    func `given the common directory cannot create a backup when backing up then the original stays registered`() throws {
        // given
        let scenario = try Scenario(registrations: ["approved"])
        defer { scenario.cleanUp() }
        let approved = try WorktreeRegistrationName("approved")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: scenario.directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scenario.directory.path) }

        // when - then
        #expect(throws: WorktreePruneError.unavailable) {
            try scenario.sut.backUp([approved], in: scenario.commonDirectory)
        }
        #expect(FileManager.default.fileExists(atPath: scenario.gitdir(in: "approved").path))
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
    }

    @Test
    func `given the second registration cannot move when backing up then the first registration is restored`() throws {
        // given
        let scenario = try Scenario(registrations: ["first", "second"])
        defer { scenario.cleanUp() }
        let first = try WorktreeRegistrationName("first")
        let second = try WorktreeRegistrationName("second")
        let originalFirstLink = try Data(contentsOf: scenario.gitdir(in: "first"))
        let secondPath = scenario.registrationDirectory("second").path
        try #require(chflags(secondPath, UInt32(UF_IMMUTABLE)) == 0)
        defer { _ = chflags(secondPath, 0) }

        // when - then
        #expect(throws: WorktreePruneError.unavailable) {
            try scenario.sut.backUp([first, second], in: scenario.commonDirectory)
        }
        #expect(try Data(contentsOf: scenario.gitdir(in: "first")) == originalFirstLink)
        #expect(FileManager.default.fileExists(atPath: scenario.gitdir(in: "second").path))
        let batches = try FileManager.default.contentsOfDirectory(at: scenario.backups, includingPropertiesForKeys: nil)
        try #require(batches.count == 1)
        let batch = try #require(batches.first)
        #expect(try FileManager.default.contentsOfDirectory(atPath: batch.path).isEmpty)
    }

    enum InvalidCommonDirectory: CaseIterable, Sendable {
        case relative
        case root
        case currentComponent
        case parentComponent
        case missingComponent
        case symbolicLink

        func location(in directory: URL) throws -> RepositoryLocation {
            let path = switch self {
            case .relative: directory.lastPathComponent
            case .root: "/"
            case .currentComponent: directory.path + "/."
            case .parentComponent: directory.path + "/worktrees/.."
            case .missingComponent: directory.path + "/missing"
            case .symbolicLink: directory.path + "/symlink"
            }
            if case .symbolicLink = self {
                try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: directory.path)
            }
            return RepositoryLocation(path: path)
        }
    }

    enum RegistrationChange: CaseIterable, Sendable {
        case aDifferentCase
        case locked
        case reconnected
        case symbolicMetadata
        case missingLink
        case symbolicLink
        case nonRegularLink
        case emptyLink
        case oversizedLink
        case invalidEncoding
        case invalidTarget
        case controlCharacter

        var refusal: WorktreePruneError {
            switch self {
            case .aDifferentCase, .locked, .reconnected: .previewChanged
            case .symbolicMetadata, .missingLink, .symbolicLink, .nonRegularLink, .emptyLink,
                 .oversizedLink, .invalidEncoding, .invalidTarget, .controlCharacter: .unavailable
            }
        }
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

        func registrationDirectory(_ registration: String) -> URL {
            directory.appending(path: "worktrees/\(registration)", directoryHint: .isDirectory)
        }

        func gitdir(in registration: String) -> URL {
            registrationDirectory(registration).appending(path: "gitdir", directoryHint: .notDirectory)
        }

        func apply(_ change: RegistrationChange, to registration: String) throws -> WorktreeRegistrationName {
            let fileSystem = FileManager.default
            let record = registrationDirectory(registration)
            let link = gitdir(in: registration)
            switch change {
            case .aDifferentCase:
                return try WorktreeRegistrationName(registration.uppercased())
            case .locked:
                try Data("agent lock\n".utf8).write(to: record.appending(path: "locked"))
            case .reconnected:
                let target = directory.appending(path: "missing-\(registration)/.git")
                try fileSystem.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("gitdir: \(record.path)\n".utf8).write(to: target)
            case .symbolicMetadata:
                try fileSystem.removeItem(at: record)
                try fileSystem.createSymbolicLink(at: record, withDestinationURL: registrationDirectory("approved"))
            case .missingLink:
                try fileSystem.removeItem(at: link)
            case .symbolicLink:
                try fileSystem.removeItem(at: link)
                try fileSystem.createSymbolicLink(at: link, withDestinationURL: gitdir(in: "approved"))
            case .nonRegularLink:
                try fileSystem.removeItem(at: link)
                try fileSystem.createDirectory(at: link, withIntermediateDirectories: false)
            case .emptyLink:
                try Data().write(to: link)
            case .oversizedLink:
                try Data(repeating: UInt8(ascii: "x"), count: Int(PATH_MAX) + 3).write(to: link)
            case .invalidEncoding:
                try Data([0xFF]).write(to: link)
            case .invalidTarget:
                try Data("checkout-dir\n".utf8).write(to: link)
            case .controlCharacter:
                try Data("missing\tcheckout/.git\n".utf8).write(to: link)
            }
            return try WorktreeRegistrationName(registration)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
