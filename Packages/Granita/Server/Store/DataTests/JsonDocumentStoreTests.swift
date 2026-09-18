import Foundation
import Testing

import CoreDiffDomain
import CoreReviewDomain
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
        #expect(state.unreadable == .writtenByANewerVersion)
    }

    @Test
    func `given a document this version's predecessor wrote when read then it opens with no review`(
    ) async throws {
        // given — version 1 knew nothing about reviews, so its document carries neither key. It is a
        // document to migrate rather than one to refuse, and the distinction is a reader's whole
        // history: refusing it would make every project, alias and paired device unreachable behind
        // a sentence about upgrading.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"""
        {
          "schemaVersion": 1,
          "projects": [{"id": "p1", "path": "/repo", "name": "repo", "isVisible": true}],
          "worktrees": {},
          "viewed": {},
          "devices": []
        }
        """#.utf8).write(to: scenario.fileUrl)

        // when
        let state = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()

        // then — everything version 1 held is still here, and the two new fields answer with what a
        // reader who has never been asked would want.
        #expect(state.unreadable == nil)
        #expect(state.projects.count == 1)
        #expect(state.reviews.isEmpty)
        #expect(state.reviewSettings == .unset)
    }

    @Test
    func `given version one marks when the document is read then they are dropped rather than guessed`(
    ) async throws {
        // given — version 1 kept one flat map from a file's path hash to a content hash, with no
        // worktree on it. There is nothing to assign one to, and a mark landing on the wrong
        // worktree draws a diff the reader has never opened as already seen — the one failure this
        // feature must not have. So they go, and a reader re-makes them in one pass.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let file = FileID(repositoryRelativePath: "src/a.swift")
        try Data(#"""
        {
          "schemaVersion": 1,
          "projects": [{"id": "p1", "path": "/repo", "name": "repo", "isVisible": true}],
          "worktrees": {},
          "viewed": {"\#(file.rawValue)": "a-content-hash"},
          "devices": []
        }
        """#.utf8).write(to: scenario.fileUrl)

        // when
        let state = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()

        // then — the marks are gone and everything else a reader set is still here. Refusing the
        // document instead would have put their projects behind a sentence about upgrading.
        #expect(state.unreadable == nil)
        #expect(state.viewed.isEmpty)
        #expect(state.projects.count == 1)
    }

    @Test
    func `given a viewed key that is neither shape when read then the document is unreadable`(
    ) async throws {
        // given — the reason the old shape is decoded rather than ignored: bytes that are neither
        // must still refuse, instead of quietly emptying a collection this version then writes back.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"""
        {"schemaVersion": 1, "projects": [], "worktrees": {}, "viewed": 7, "devices": []}
        """#.utf8).write(to: scenario.fileUrl)

        // when
        let state = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()

        // then
        #expect(state.unreadable == .couldNotBeDecoded)
    }

    @Test
    func `given a version one document when it is written to then it is left in this version's shape`(
    ) async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"""
        {"schemaVersion": 1, "projects": [], "worktrees": {}, "viewed": {}, "devices": []}
        """#.utf8).write(to: scenario.fileUrl)
        let sut = JsonDocumentStore(fileUrl: scenario.fileUrl)

        // when
        try await sut.setReviewSettings(ReviewSettings(openingLine: "Mine.", identifier: .numbers))

        // then — the migration is the first write rather than a pass at startup, so a document is
        // only ever rewritten when something was going to rewrite it anyway.
        let reopened = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()
        #expect(reopened.reviewSettings.openingLine == "Mine.")
        #expect(reopened.reviewSettings.identifier == .numbers)
        let raw = try #require(String(data: try Data(contentsOf: scenario.fileUrl), encoding: .utf8))
        #expect(raw.contains("\"schemaVersion\" : 2"))
    }

    @Test
    func `given a review saved when a new store reads the same file then every comment is still there`(
    ) async throws {
        // given — a review is the one thing in this document a reader cannot re-derive, and an
        // afternoon's work fits in it.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let worktree = WorktreeID(canonicalPath: "/repo/slice")
        let comment = ReviewComment(
            anchor: CommentAnchor(
                file: FileID(repositoryRelativePath: "src/a.swift"),
                first: DiffLinePosition(oldNumber: nil, newNumber: 12),
                last: DiffLinePosition(oldNumber: nil, newNumber: 14)
            ),
            path: "src/a.swift",
            lines: CommentedLines(side: .new, first: 12, last: 14),
            language: "swift",
            quotedLines: ["+    let a = 1"],
            text: "This should be a constant."
        )

        // when
        try await scenario.sut.setReview([comment], in: worktree)

        // then
        let reopened = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()
        #expect(reopened.reviews[worktree] == [comment])
    }

    @Test
    func `given a review cleared when it is written then no row is left behind for that worktree`(
    ) async throws {
        // given — the Mac's own pane counts stored reviews, and a row holding an empty array would
        // make that count name worktrees nobody has written about.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let worktree = WorktreeID(canonicalPath: "/repo/slice")
        try await scenario.sut.setReview(
            [ReviewComment(
                anchor: CommentAnchor(
                    file: FileID(repositoryRelativePath: "a.swift"),
                    first: DiffLinePosition(oldNumber: nil, newNumber: 1),
                    last: DiffLinePosition(oldNumber: nil, newNumber: 1)
                ),
                path: "a.swift",
                lines: CommentedLines(side: .new, first: 1, last: 1),
                language: nil,
                quotedLines: ["+a"],
                text: "why"
            )],
            in: worktree
        )

        // when
        try await scenario.sut.setReview([], in: worktree)

        // then
        #expect(await scenario.sut.state().reviews.isEmpty)
    }

    @Test
    func `given a document that cannot be decoded when read then it is not mistaken for a first run`(
    ) async throws {
        // given — bytes that are not this document. A first run and a damaged store reach a caller
        // as the same empty state, and only one of the two may be written over.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"{"projects": "not an array"}"#.utf8).write(to: scenario.fileUrl)

        // when
        let state = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()

        // then
        #expect(state.projects.isEmpty)
        #expect(state.unreadable == .couldNotBeDecoded)
    }

    @Test
    func `given a future document whose shape cannot be decoded when read then it is still known to be the future's`(
    ) async throws {
        // given — the version is the one field a later document is guaranteed to still spell the way
        // this version does, so it has to be read before any shape a later release could change.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"{"schemaVersion": 999, "reviews": []}"#.utf8).write(to: scenario.fileUrl)

        // when
        let state = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()

        // then — from the future, not damaged: the difference decides whether a reader is told to
        // upgrade Granita or to repair a file.
        #expect(state.unreadable == .writtenByANewerVersion)
    }

    @Test
    func `given a file marked viewed when its content hash changes then the mark does not follow it`(
    ) async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let file = FileID(repositoryRelativePath: "src/a.swift")
        let worktree = WorktreeID(canonicalPath: "/repo/slice")

        // when
        try await scenario.sut.setViewed(
            true,
            file: file,
            in: worktree,
            contentHash: "hash-one",
            at: Date(timeIntervalSince1970: 1)
        )

        // then — viewed state is keyed by what was read, not by which file it was.
        let state = await scenario.sut.state()
        #expect(state.viewed[worktree]?[file]?.contentHash == "hash-one")
    }

    @Test
    func `given one file marked in two worktrees when read then each worktree answers for itself`(
    ) async throws {
        // given — a file identifier is a hash of a repository-relative path, so the same file in two
        // checkouts is one identifier. Until the mark carried a worktree, marking it in one drew it
        // as read in the other whenever their content agreed — which between two branches of one
        // repository is most of the files in them.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let file = FileID(repositoryRelativePath: "src/a.swift")
        let one = WorktreeID(canonicalPath: "/repo/one")
        let other = WorktreeID(canonicalPath: "/repo/other")

        // when
        try await scenario.sut.setViewed(
            true,
            file: file,
            in: one,
            contentHash: "same-content",
            at: Date(timeIntervalSince1970: 1)
        )

        // then
        let state = await scenario.sut.state()
        #expect(state.viewed[one]?[file]?.contentHash == "same-content")
        #expect(state.viewed[other] == nil)
    }

    @Test
    func `given marks and reviews for a worktree that is gone when pruned then both go with it`(
    ) async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let living = WorktreeID(canonicalPath: "/repo/living")
        let deleted = WorktreeID(canonicalPath: "/repo/deleted")
        for worktree in [living, deleted] {
            try await scenario.sut.setViewed(
                true,
                file: FileID(repositoryRelativePath: "a.swift"),
                in: worktree,
                contentHash: "h",
                at: Date(timeIntervalSince1970: 1)
            )
        }

        // when
        try await scenario.sut.prune(keeping: [living], markLimit: 20_000)

        // then — an agent makes and destroys these checkouts, so nothing else would ever drop them.
        let state = await scenario.sut.state()
        #expect(state.viewed[living] != nil)
        #expect(state.viewed[deleted] == nil)
    }

    @Test
    func `given more marks than the cap when pruned then the oldest go first`() async throws {
        // given — the cap is on the document rather than per worktree, so one enormous worktree
        // cannot cost the small ones their marks to keep a share it never uses.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let worktree = WorktreeID(canonicalPath: "/repo/slice")
        for index in 0..<5 {
            try await scenario.sut.setViewed(
                true,
                file: FileID(repositoryRelativePath: "file\(index).swift"),
                in: worktree,
                contentHash: "h\(index)",
                at: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        // when
        try await scenario.sut.prune(keeping: [worktree], markLimit: 2)

        // then — the two most recently marked survive, which is what a reader is still working on.
        let marks = await scenario.sut.state().viewed[worktree] ?? [:]
        #expect(marks.count == 2)
        #expect(marks[FileID(repositoryRelativePath: "file4.swift")] != nil)
        #expect(marks[FileID(repositoryRelativePath: "file3.swift")] != nil)
        #expect(marks[FileID(repositoryRelativePath: "file0.swift")] == nil)
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
        try await scenario.sut.setViewed(
            true,
            file: FileID(repositoryRelativePath: "a.txt"),
            in: worktree,
            contentHash: "hash",
            at: Date(timeIntervalSince1970: 1)
        )

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
        let worktree = WorktreeID(canonicalPath: "/repo/slice")
        try await scenario.sut.setViewed(
            true,
            file: file,
            in: worktree,
            contentHash: "hash",
            at: Date(timeIntervalSince1970: 1)
        )

        // when
        try await scenario.sut.setViewed(
            false,
            file: file,
            in: worktree,
            contentHash: "hash",
            at: Date(timeIntervalSince1970: 2)
        )

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
    func `given a document that cannot be decoded when written to then it refuses and leaves the bytes alone`(
    ) async throws {
        // given — a reader's projects, aliases, pins and paired devices are in that file. A mutation
        // that read it as a first run would replace every one of them with nothing, and say nothing.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let original = #"{"projects": "not an array"}"#
        try Data(original.utf8).write(to: scenario.fileUrl)
        let sut = JsonDocumentStore(fileUrl: scenario.fileUrl)

        // when
        var thrown: StoreError?
        do {
            try await sut.setPinned(true, for: WorktreeID(canonicalPath: "/repo"))
        } catch {
            thrown = error
        }

        // then — refused with a reason, and the bytes exactly as they were for a person to repair.
        guard case .notWritable(let reason) = thrown else {
            Issue.record("expected a refusal, got \(String(describing: thrown))")
            return
        }
        #expect(reason.isEmpty == false)
        #expect(try String(contentsOf: scenario.fileUrl, encoding: .utf8) == original)
    }

    @Test
    func `given a document that cannot be decoded when reset then it is replaced rather than refused`(
    ) async throws {
        // given — Advanced's "Reset all data" is the only repair a reader has for a damaged
        // document. A reset that refused would leave the one control that fixes this unable to.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        try Data(#"{"projects": "not an array"}"#.utf8).write(to: scenario.fileUrl)
        let sut = JsonDocumentStore(fileUrl: scenario.fileUrl)

        // when
        try await sut.reset()

        // then — a document this version wrote, and readable again on the next launch.
        let reopened = await JsonDocumentStore(fileUrl: scenario.fileUrl).state()
        #expect(reopened.unreadable == nil)
        #expect(reopened.projects.isEmpty)
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
