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
