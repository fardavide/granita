import Foundation
import Testing

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

@testable import ClientViewerPresentation

/// Which picture sides the phone asks the Mac for, what it does with the answers, and what the full
/// screen draws while a thumb is down.
@Suite("Client viewer images")
@MainActor
struct ClientViewerImagesTests {

    // MARK: - What gets asked for

    @Test
    func `given a changed picture when its diff arrives then both its sides are asked for`() async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then — committed first, which is the order the card draws them in.
        #expect(scenario.repository.imagesAskedFor.map(\.side) == [.old, .new])
        let image = try #require(scenario.sut.images[scenario.fileIds[0]])
        #expect(image.format == .png)
        #expect(image.sides == .both)
    }

    @Test
    func `given a picture that has just arrived when its diff arrives then only its working copy is asked for`(
    ) async throws {
        // given — an untracked screenshot, which git never reports as binary and which has no
        // committed side to compare against.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/new.png", status: .untracked)])
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then — asking for the committed side would be a request the Mac can only refuse.
        #expect(scenario.repository.imagesAskedFor.map(\.side) == [.new])
    }

    @Test
    func `given a file that is not a picture when its diff arrives then no picture is asked for`(
    ) async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Sources/App/main.swift", status: .modified)])
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        #expect(scenario.repository.imagesAskedFor.isEmpty)
        #expect(scenario.sut.images.isEmpty)
    }

    @Test
    func `given a picture already read when the scroll reaches it then nothing is asked for`() async throws {
        // given — a file the reader has marked viewed is drawn shut, and this is the expensive fetch.
        let scenario = Scenario(
            files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified, isViewed: true)]
        )
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        #expect(scenario.repository.imagesAskedFor.isEmpty)
    }

    @Test
    func `given a picture whose sides are in hand when the scroll reports again then it is not re-asked`(
    ) async throws {
        // given — a scroll reports a position per frame, so anything not remembered is asked for on
        // every one of them.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.reading(0)

        // then
        #expect(scenario.repository.imagesAskedFor.count == 2)
    }

    // MARK: - What the answers become

    @Test
    func `given a picture when both sides land then the card holds the bytes for each`() async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then — the fake tags each side, so a card drawing the same picture twice fails here.
        let image = try #require(scenario.sut.images[scenario.fileIds[0]])
        #expect(image.old == .arrived(Data([0x89, 0x50, 0x4E, 0x47, 0x01])))
        #expect(image.new == .arrived(Data([0x89, 0x50, 0x4E, 0x47, 0x02])))
    }

    @Test
    func `given the Mac refuses one side when it answers then that frame says so and the other does not`(
    ) async throws {
        // given — one side refused and one not is the state the per-frame control exists for.
        let scenario = Scenario(
            files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)],
            imagesAnsweringBeforeRefusing: 1
        )
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        let image = try #require(scenario.sut.images[scenario.fileIds[0]])
        #expect(image.old == .arrived(Data([0x89, 0x50, 0x4E, 0x47, 0x01])))
        #expect(image.new == .refused(.gitFailure(message: "git exited 128")))
    }

    @Test
    func `given a refused side when the reader tries again then it is asked for once more`() async throws {
        // given — a refused picture leaves no card blank, so the bar at the bottom of the screen
        // never appears for it and this is the only control there is.
        let scenario = Scenario(
            files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)],
            imagesAnsweringBeforeRefusing: 1
        )
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.retryImage(.new, of: scenario.fileIds[0])

        // then — asked a third time, whatever it answered.
        #expect(scenario.repository.imagesAskedFor.count == 3)
        #expect(scenario.repository.imagesAskedFor.last?.side == .new)
    }

    @Test
    func `given a side this file does not have when it is retried then nothing is asked for`() async throws {
        // given — the card never offers it, so reaching this is a caller out of step with the file.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/new.png", status: .added)])
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.retryImage(.old, of: scenario.fileIds[0])

        // then
        #expect(scenario.repository.imagesAskedFor.count == 1)
    }

    @Test
    func `given a file with no picture at all when a side is retried then nothing happens`() async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Sources/App/main.swift", status: .modified)])
        await scenario.sut.load()

        // when
        await scenario.sut.retryImage(.new, of: scenario.fileIds[0])

        // then
        #expect(scenario.repository.imagesAskedFor.isEmpty)
    }

    @Test
    func `given pictures in hand when a new change set lands then the bytes are let go of`() async throws {
        // given — a megabyte apiece under a file identifier the scroll no longer draws is memory
        // nothing can reach and nothing will free.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        #expect(scenario.sut.images[scenario.fileIds[0]]?.new != .awaiting)

        // when
        await scenario.sut.load()

        // then — the card is back to two empty frames on their way rather than holding the last
        // change set's pictures.
        let image = try #require(scenario.sut.images[scenario.fileIds[0]])
        #expect(image.old == .awaiting)
        #expect(image.new == .awaiting)
    }

    @Test
    func `given a change set naming a picture when it lands then its card has frames before any bytes do`(
    ) async throws {
        // given — filled in only when a diff landed, the card spends a frame as an empty file: git
        // answers `Binary files … differ`, so a picture's `FileDiff` is a real answer with no hunks
        // in it, and the row would collapse to nothing and then grow two frames.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])

        // when
        await scenario.sut.load()

        // then
        let image = try #require(scenario.sut.images[scenario.fileIds[0]])
        #expect(image.sides == .both)
        #expect(scenario.repository.imagesAskedFor.isEmpty)
    }

    // MARK: - The full screen

    @Test
    func `given a picture in hand when the reader taps it then it opens on the side they tapped`(
    ) async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        scenario.sut.openImage(.old, of: scenario.fileIds[0])

        // then
        #expect(scenario.sut.openedImage == OpenedImage(file: scenario.fileIds[0], side: .old))
        let shown = try #require(scenario.sut.openedImageSide)
        #expect(shown.side == .old)
        #expect(shown.bytes == Data([0x89, 0x50, 0x4E, 0x47, 0x01]))
    }

    @Test
    func `given a side still on its way when the reader taps it then nothing opens`() async throws {
        // given — a frame saying *reading from your Mac* has nothing to show at full screen, so it
        // is not a control.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()

        // when
        scenario.sut.openImage(.new, of: scenario.fileIds[0])

        // then
        #expect(scenario.sut.openedImage == nil)
    }

    @Test
    func `given an opened picture when the reader holds it then the other side is drawn`() async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        scenario.sut.openImage(.new, of: scenario.fileIds[0])

        // when
        scenario.sut.compareImage(true)

        // then
        let shown = try #require(scenario.sut.openedImageSide)
        #expect(shown.side == .old)
        #expect(shown.bytes == Data([0x89, 0x50, 0x4E, 0x47, 0x01]))
    }

    @Test
    func `given a one-sided picture when the reader holds it then it does not swap`() async throws {
        // given — there is nothing to swap to, which is why the hint is absent on this card.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/new.png", status: .added)])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        scenario.sut.openImage(.new, of: scenario.fileIds[0])

        // when
        scenario.sut.compareImage(true)

        // then
        let shown = try #require(scenario.sut.openedImageSide)
        #expect(shown.side == .new)
    }

    @Test
    func `given the reader is holding a picture when they let go then it comes back`() async throws {
        // given
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        scenario.sut.openImage(.new, of: scenario.fileIds[0])
        scenario.sut.compareImage(true)

        // when
        scenario.sut.compareImage(false)

        // then
        #expect(try #require(scenario.sut.openedImageSide).side == .new)
    }

    @Test
    func `given a picture opened while held when it is closed then the next one opens unheld`() async throws {
        // given — a cover dismissed mid-press never sees the gesture end.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        scenario.sut.openImage(.new, of: scenario.fileIds[0])
        scenario.sut.compareImage(true)

        // when
        scenario.sut.closeImage()

        // then
        #expect(scenario.sut.openedImage == nil)
        #expect(scenario.sut.isComparingImage == false)
        #expect(scenario.sut.openedImageSide == nil)
    }

    @Test
    func `given an open picture when the change set is read again then there is nothing left to draw`(
    ) async throws {
        // given — the bytes went with the old change set, and a cover left up over a frame that is
        // back to *on its way* is a screen the reader has to guess their way out of.
        let scenario = Scenario(files: [aPicture(at: "Apps/Snapshots/home.png", status: .modified)])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        scenario.sut.openImage(.new, of: scenario.fileIds[0])

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.openedImageSide == nil)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: ClientViewerModel
        let repository: FakeGranitaRepository
        let fileIds: [FileID]

        init(files: [FileChange], imagesAnsweringBeforeRefusing: Int = .max) {
            fileIds = files.map(\.id)
            repository = FakeGranitaRepository(
                changeSet: .success(WorktreeChanges(
                    revision: "9d41e0c7",
                    stats: ChangeStats(filesChanged: files.count, insertions: 0, deletions: 0),
                    files: files,
                    isTruncated: false
                )),
                imagesAnsweringBeforeRefusing: imagesAnsweringBeforeRefusing
            )
            sut = ClientViewerModel(
                worktree: WorktreeID(rawValue: "b7c1e0a4f2d84391"),
                worktreeName: "image diff",
                projectName: "granita",
                repository: repository,
                commentStore: FakeReviewCommentStore(),
                pasteboard: FakeReviewPasteboard(),
                highlighter: FakeSyntaxHighlighter(),
                copyingLogs: FakeDiagnosticLogsCopying(answering: .success(())),
                announcing: FakeDiffReadAnnouncing(),
                longWait: .seconds(10)
            )
        }
    }
}

private func aPicture(at path: String, status: FileStatus, isViewed: Bool = false) -> FileChange {
    FileChange(
        id: FileID(repositoryRelativePath: path),
        path: path,
        oldPath: nil,
        status: status,
        // What git would say. The card decides from the path instead, which is the whole point of
        // the rule — so an untracked picture is reported unbinary here exactly as git reports it.
        isBinary: status != .untracked,
        isSubmodule: false,
        stats: ChangeStats(filesChanged: 1, insertions: 0, deletions: 0),
        contentHash: String(repeating: "e", count: 64),
        estimatedLineCount: 0,
        isViewed: isViewed,
        isTruncated: false,
        language: nil
    )
}
