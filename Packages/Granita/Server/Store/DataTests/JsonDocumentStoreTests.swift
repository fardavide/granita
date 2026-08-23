import Foundation
import Testing

import CoreDiffDomain
import ServerStoreDomain
@testable import ServerStoreData

/// One JSON document, behind one actor, replaced atomically. Nothing here is a database, and the
/// reason it can afford not to be is that everything it holds is small, is written rarely, and is
/// recoverable by hand from a text editor if it ever goes wrong.
@Suite("Json document store")
struct JsonDocumentStoreTests {

    @Test
    func `given nothing on disk when read then the store starts empty rather than failing`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }

        // when
        let state = await scenario.sut.state()

        // then — first run is the ordinary case, not an error to report to anyone.
        #expect(state.projects.isEmpty)
        #expect(state.devices.isEmpty)
    }

    @Test
    func `given a project added when a new store reads the same file then it is still there`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let project = StoredProject(
            id: ProjectID(canonicalPath: "/Users/davide/Dev/Granita"),
            path: "/Users/davide/Dev/Granita",
            name: "Granita",
            isVisible: true
        )

        // when
        try await scenario.sut.add(project: project)

        // then
        let reopened = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()
        #expect(reopened.projects == [project])
    }

    @Test
    func `given a write when it lands then the document was replaced rather than edited in place`(
    ) async throws {
        // given — a half-written document is unrecoverable, and the window for one is exactly as
        // long as it takes to serialise everything a reader has ever marked viewed.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try await scenario.sut.add(project: StoredProject(
            id: ProjectID(canonicalPath: "/a"), path: "/a", name: "a", isVisible: true
        ))

        // when
        let contents = try Data(contentsOf: scenario.fileUrl)

        // then — a complete document, and no temporary file left beside it.
        #expect(try JSONSerialization.jsonObject(with: contents) is [String: Any])
        let siblings = try FileManager.default.contentsOfDirectory(
            atPath: scenario.fileUrl.deletingLastPathComponent().path
        )
        #expect(siblings == [scenario.fileUrl.lastPathComponent])
    }

    @Test
    func `given a document from a future version when read then it is not silently reinterpreted`(
    ) async throws {
        // given — the schema version exists so that a document written by a newer Granita is
        // recognised rather than read with today's rules and written back with fields dropped.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"{"schemaVersion": 999, "projects": [], "worktrees": {}, "viewed": {}, "devices": []}"#.utf8)
            .write(to: scenario.fileUrl)

        // when
        let state = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()

        // then — an empty state rather than a partial one, and the file is left alone until
        // something writes deliberately.
        #expect(state.projects.isEmpty)
        #expect(state.isFromUnreadableDocument)
    }

    @Test
    func `given a file marked viewed when its content hash changes then the mark does not follow it`(
    ) async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let file = FileID(repositoryRelativePath: "src/a.swift")

        // when
        try await scenario.sut.setViewed(true, file: file, contentHash: "hash-one")

        // then — viewed state is keyed by what was read, not by which file it was.
        let state = await scenario.sut.state()
        #expect(state.viewed[file] == "hash-one")
    }

    @Test
    func `given an alias and a pin when set then both survive independently`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let worktree = WorktreeID(canonicalPath: "/repo/slice")

        // when
        try await scenario.sut.setAlias("the parser", for: worktree)
        try await scenario.sut.setPinned(true, for: worktree)
        try await scenario.sut.setAlias(nil, for: worktree)

        // then — clearing the alias is a thing a reader can ask for, and it must not clear the pin.
        let state = await scenario.sut.state()
        #expect(state.worktrees[worktree]?.alias == nil)
        #expect(state.worktrees[worktree]?.isPinned == true)
    }

    @Test
    func `given a project when its visibility is turned off then only that project changes`() async throws {
        // given — enabling is explicit and revocable, and it is what every opaque identifier is
        // resolved against.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let one = ProjectID(canonicalPath: "/one")
        try await scenario.sut.add(project: StoredProject(id: one, path: "/one", name: "one", isVisible: true))
        try await scenario.sut.add(project: StoredProject(
            id: ProjectID(canonicalPath: "/two"), path: "/two", name: "two", isVisible: true
        ))

        // when
        try await scenario.sut.setProjectVisible(false, id: one)

        // then
        let state = await scenario.sut.state()
        #expect(state.projects.first { $0.id == one }?.isVisible == false)
        #expect(state.projects.first { $0.name == "two" }?.isVisible == true)
    }

    @Test
    func `given a project when it is removed then it is gone and the others remain`() async throws {
        // given — the minus half of design §4's plus/minus bar. Removing is not switching off: a
        // project switched off is one this Mac still remembers being asked about, and a removed one
        // is a path this Mac has no business holding any more.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let one = ProjectID(canonicalPath: "/one")
        try await scenario.sut.add(project: StoredProject(id: one, path: "/one", name: "one", isVisible: true))
        try await scenario.sut.add(project: StoredProject(
            id: ProjectID(canonicalPath: "/two"), path: "/two", name: "two", isVisible: true
        ))

        // when
        try await scenario.sut.removeProject(id: one)

        // then
        let state = await scenario.sut.state()
        #expect(state.projects.map(\.name) == ["two"])
    }

    @Test
    func `given a project that was removed when the document is read again then it stayed removed`(
    ) async throws {
        // given — the one outcome nobody would think to check for: a removal that cleared this
        // process's memory and left the file alone puts a repository back on the network at the next
        // launch.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let one = ProjectID(canonicalPath: "/one")
        try await scenario.sut.add(project: StoredProject(id: one, path: "/one", name: "one", isVisible: true))
        try await scenario.sut.removeProject(id: one)

        // when
        let reopened = JsonDocumentStore(fileUrl: scenario.fileUrl)

        // then
        #expect(await reopened.state().projects.isEmpty)
    }

    @Test
    func `given a paired device when it is revoked then its token is gone and the others remain`(
    ) async throws {
        // given — tokens are per device and individually revocable, which is the whole reason they
        // are per device.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let phone = StoredDevice(
            id: "phone", name: "iPhone", platform: "iOS",
            tokenHash: "aaa", pairedAt: Date(timeIntervalSince1970: 1)
        )
        let pad = StoredDevice(
            id: "pad", name: "iPad", platform: "iPadOS",
            tokenHash: "bbb", pairedAt: Date(timeIntervalSince1970: 2)
        )
        try await scenario.sut.add(device: phone)
        try await scenario.sut.add(device: pad)

        // when
        try await scenario.sut.removeDevice(id: "phone")

        // then
        #expect(await scenario.sut.state().devices.map(\.id) == ["pad"])
    }

    @Test
    func `given a device pairing again when it is added then it replaces its own record`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let first = StoredDevice(
            id: "phone", name: "iPhone", platform: "iOS",
            tokenHash: "aaa", pairedAt: Date(timeIntervalSince1970: 1)
        )

        // when — re-pairing issues a new token, and the old one must stop working rather than
        // accumulate beside it.
        try await scenario.sut.add(device: first)
        try await scenario.sut.add(device: StoredDevice(
            id: "phone", name: "iPhone", platform: "iOS",
            tokenHash: "ccc", pairedAt: Date(timeIntervalSince1970: 9)
        ))

        // then
        let devices = await scenario.sut.state().devices
        #expect(devices.count == 1)
        #expect(devices[0].tokenHash == "ccc")
    }

    @Test
    func `given a store with everything in it when it is reset then all four of its records go`() async throws {
        // given — Advanced's one-way door. It has to be all four, because a reset that left one
        // behind would leave the reader believing the rest went too.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let worktree = WorktreeID(canonicalPath: "/tmp/repo")
        try await scenario.sut.add(project: StoredProject(
            id: ProjectID(canonicalPath: "/tmp/repo"), path: "/tmp/repo", name: "repo", isVisible: true
        ))
        try await scenario.sut.add(device: StoredDevice(
            id: "phone", name: "iPhone", platform: "iOS",
            tokenHash: "aaa", pairedAt: Date(timeIntervalSince1970: 1)
        ))
        try await scenario.sut.setAlias("Feature", for: worktree)
        try await scenario.sut.setViewed(true, file: FileID(repositoryRelativePath: "a.txt"), contentHash: "hash")

        // when
        try await scenario.sut.reset()

        // then
        #expect(await scenario.sut.state() == .empty)
    }

    @Test
    func `given a store that has been reset when it is read again then the document on disk is empty too`(
    ) async throws {
        // given — the state this actor holds in memory and the document beside it have to agree,
        // or the next launch restores everything the reset claimed to destroy.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try await scenario.sut.add(project: StoredProject(
            id: ProjectID(canonicalPath: "/tmp/repo"), path: "/tmp/repo", name: "repo", isVisible: true
        ))

        // when
        try await scenario.sut.reset()

        // then
        let reopened = JsonDocumentStore(fileUrl: scenario.fileUrl)
        #expect(await reopened.state().projects.isEmpty)
    }

    @Test
    func `given a file unmarked when it is written then no row is left behind for it`() async throws {
        // given — a row per file anyone ever looked at and changed their mind about is a document
        // that only grows.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let file = FileID(repositoryRelativePath: "a.txt")
        try await scenario.sut.setViewed(true, file: file, contentHash: "hash")

        // when
        try await scenario.sut.setViewed(false, file: file, contentHash: "hash")

        // then
        #expect(await scenario.sut.state().viewed.isEmpty)
    }

    @Test
    func `given a document from a future version when written to then it refuses rather than overwrite`(
    ) async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"{"schemaVersion": 999, "projects": [], "worktrees": {}, "viewed": {}, "devices": []}"#.utf8)
            .write(to: scenario.fileUrl)
        let sut = JsonDocumentStore(fileUrl: scenario.fileUrl)

        // when
        var thrown: StoreError?
        do {
            try await sut.setPinned(true, for: WorktreeID(canonicalPath: "/repo"))
        } catch {
            thrown = error
        }

        // then — the fields a newer Granita added are the ones a reader spent time producing, and
        // writing today's shape back would drop every one of them.
        #expect(thrown == .documentIsFromANewerVersion)
        #expect(try Data(contentsOf: scenario.fileUrl).count > 0)
    }

    @Test
    func `given a path that cannot be written when saving then the reason survives`() async throws {
        // given — the only person who can act on this is standing at the Mac.
        let sut = JsonDocumentStore(fileUrl: URL(filePath: "/dev/null/granita/impossible.json"))

        // when
        var thrown: StoreError?
        do {
            try await sut.add(project: StoredProject(
                id: ProjectID(canonicalPath: "/a"), path: "/a", name: "a", isVisible: true
            ))
        } catch {
            thrown = error
        }

        // then
        guard case .notWritable(let reason) = thrown else {
            Issue.record("expected an unwritable document, got \(String(describing: thrown))")
            return
        }
        #expect(reason.isEmpty == false)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: JsonDocumentStore
        let fileUrl: URL

        init() {
            let directory = URL.temporaryDirectory
                .appending(path: "granita-store-\(UUID().uuidString)", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            fileUrl = directory.appending(path: "granita.json", directoryHint: .notDirectory)
            sut = JsonDocumentStore(fileUrl: fileUrl)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: fileUrl.deletingLastPathComponent())
        }
    }
}
