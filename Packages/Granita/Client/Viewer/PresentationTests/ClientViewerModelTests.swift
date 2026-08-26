import Testing

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

@testable import ClientViewerPresentation

/// What the diff screen holds, and — mostly — which files it asked the Mac for.
///
/// The ordering rule itself is asserted one layer down in `ContinuousDiffLoadingTests`, over a pure
/// function. What is left here is whether the model spends that rule correctly: the right batch,
/// once, against state that moves while requests are in flight.
@Suite("Client viewer model")
@MainActor
struct ClientViewerModelTests {

    @Test
    func `given a worktree with changes when it loads then every file is named before any is fetched`() async {
        // given — the change set carries the file list and the stats and never the hunks, which is
        // what lets the scroll reserve space for all of them from the first frame.
        let scenario = Scenario(files: aChangeSet(of: 8))

        // when
        await scenario.sut.load()

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a worktree with changes has to read as something to read")
            return
        }
        #expect(entries.count == 8)
        #expect(entries.allSatisfy { if case .awaiting = $0 { true } else { false } })
        #expect(await scenario.repository.batchesAskedFor.isEmpty)
    }

    @Test
    func `given a clean worktree when it loads then it says so rather than showing an empty scroll`() async {
        // given — reachable on purpose: the sidebar's "show them anyway" is how a reader opens a
        // worktree with nothing in it, so this is a destination rather than an accident.
        let scenario = Scenario(files: [])

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.state == .nothingChanged)
    }

    @Test
    func `given a Mac that refuses when it loads then the refusal is what the screen holds`() async {
        // given
        let scenario = Scenario(changeSetFailure: .worktreeGone)

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.state == .failed(.worktreeGone))
    }

    // MARK: - Which files get fetched, which is SPEC §10's rule being spent

    @Test
    func `given the top of a change set when the reader arrives then five files are asked for at once`() async {
        // given — one request rather than five, because opening a forty-file worktree must not be
        // forty-one round trips each spawning a git process on the other machine.
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        #expect(await scenario.repository.batchesAskedFor == [Array(scenario.fileIds.prefix(5))])
    }

    @Test
    func `given files already fetched when the reader moves on then only the new ones are asked for`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.reading(3)

        // then — the window is a count of files rather than of positions, so three already in hand
        // are stepped over rather than re-fetched.
        #expect(await scenario.repository.batchesAskedFor.count == 2)
        #expect(await scenario.repository.batchesAskedFor.last == Array(scenario.fileIds[5..<8]))
    }

    @Test
    func `given a reader who scrolled past a gap when they scroll on then the gap is never filled`() async {
        // given — this is the whole of §10's trap. The reader arrived at file six without file
        // three ever being fetched; filling it now turns a placeholder above the viewport into real
        // content, and everything below it — the screen they are reading — moves.
        let scenario = Scenario(files: aChangeSet(of: 10))
        await scenario.sut.load()

        // when
        await scenario.sut.reading(6)

        // then
        let asked = await scenario.repository.batchesAskedFor.flatMap { $0 }
        #expect(asked == Array(scenario.fileIds[6..<10]))
        #expect(asked.contains(scenario.fileIds[3]) == false)
    }

    @Test
    func `given a diff that arrives when it is placed then it lands on its own file`() async {
        // given — the answer comes back as a list and the entries are positional, so a fetch that
        // matched by order rather than by identifier would put one file's hunks under another's
        // name the first time the Mac answered out of order.
        let scenario = Scenario(files: aChangeSet(of: 3), hunksFor: 1)
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a fetched change set has to read as something to read")
            return
        }
        // Every entry keeps its own position and its own identity, and the one hunk that exists is
        // under the file it belongs to rather than under whichever came back first.
        #expect(entries.map(\.id) == scenario.fileIds)
        #expect(entries.map(\.hunkCountForTests) == [0, 1, 0])
        #expect(entries.allSatisfy { $0.id == $0.file.id })
    }

    @Test
    func `given a batch the Mac refused when it is asked for then the screen keeps what it had`() async {
        // given — losing one batch of hunks is not losing the screen. The file list arrived, so the
        // reader still has every name and every size; replacing all of that with an error because
        // the fourth batch failed would throw away what they had already read.
        let scenario = Scenario(files: aChangeSet(of: 4), diffFailure: .gitFailure(message: "index.lock"))
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a refused batch must not replace the file list")
            return
        }
        #expect(entries.count == 4)
        #expect(entries.allSatisfy { $0.isAwaitingForTests })
    }

    @Test
    func `given a diff for a file the list never had when it arrives then it is dropped`() async {
        // given — the worktree moves while the phone reads it, so a batch asked for against one
        // revision can be answered against the next. Appending a file nobody scrolled to would put
        // content *below* everything, which is harmless, and matching it positionally would put it
        // under another file's name, which is not.
        let scenario = Scenario(files: aChangeSet(of: 3), alsoAnswering: aFileNobodyAskedFor)
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a fetched change set has to read as something to read")
            return
        }
        #expect(entries.map(\.id) == scenario.fileIds)
    }

    @Test
    func `given a position past the end when the reader reports it then nothing is asked for`() async {
        // given — reachable while a change set is being replaced under a scroll that has not been
        // told yet, and the alternative to answering it is an index out of range.
        let scenario = Scenario(files: aChangeSet(of: 3))
        await scenario.sut.load()

        // when
        await scenario.sut.reading(9)

        // then
        #expect(await scenario.repository.batchesAskedFor.isEmpty)
    }

    @Test
    func `given nothing loaded yet when a position arrives then nothing is asked for`() async {
        // given — the scroll reports a position as soon as it draws a row, and `load()` may not have
        // answered. Without the guard this is a `/diffs` with an empty list, which the Mac answers
        // with nothing and which costs a round trip to learn that.
        let scenario = Scenario(files: aChangeSet(of: 3))

        // when
        await scenario.sut.reading(0)

        // then
        #expect(await scenario.repository.batchesAskedFor.isEmpty)
    }

    // MARK: - The selector beside it

    @Test
    func `given a change set when it loads then the selector holds the same files arranged`() async {
        // given — one model, two views onto it: the selector is not a second list but the change set
        // the scroll is drawing, put in design §3's order.
        let scenario = Scenario(files: aChangeSet(of: 8))

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.selector.rows.compactMap(\.file?.id) == scenario.fileIds)
    }

    @Test
    func `given a truncated change set when it loads then the selector is the thing that says so`() async {
        // given — the scroll draws what it was served and cannot say what it was not, so the footer
        // under the selector is the only place a reader learns the list is incomplete.
        let scenario = Scenario(files: aChangeSet(of: 6), isTruncated: true)

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.selector.footer == .notAllServed(shown: 6))
    }

    @Test
    func `given a listing when the reader chooses an arrangement then the rows are rebuilt in it`() async {
        // given — eight files across two directories, so a tree is worth offering at all.
        let scenario = Scenario(files: aChangeSetAcrossTwoDirectories())
        await scenario.sut.load()

        // when
        scenario.sut.show(.flat)

        // then
        #expect(scenario.sut.selector.mode == .flat)
        #expect(scenario.sut.selector.rows.compactMap(\.directory).isEmpty)
    }

    @Test
    func `given an open directory when the reader shuts it then its files leave the list`() async {
        // given
        let scenario = Scenario(files: aChangeSetAcrossTwoDirectories())
        await scenario.sut.load()
        let directory = "Sources/Client"

        // when
        scenario.sut.toggle(directory)

        // then
        #expect(scenario.sut.selector.rows.compactMap(\.file?.path).allSatisfy {
            $0.hasPrefix("\(directory)/") == false
        })

        // and when — the same control, pressed again
        scenario.sut.toggle(directory)

        // then — it comes back, which is the half a control that only shuts would get wrong.
        #expect(scenario.sut.selector.rows.contains { $0.file?.path.hasPrefix("\(directory)/") == true })
    }

    @Test
    func `given the drawer is up when a file is chosen then it stays up`() async {
        // given — design §3's whole argument for a drawer over a modal is that the reader walks a
        // change set file by file without a dismiss-present cycle between each one. A `choose` that
        // also closed it would be the modal this design rejected, wearing a detent.
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()
        scenario.sut.showSelector(true)

        // when
        scenario.sut.choose(scenario.fileIds[5])

        // then
        #expect(scenario.sut.isShowingSelector)

        // and when — the reader pulls it back down themselves, which is the only thing that shuts it
        scenario.sut.showSelector(false)

        // then
        #expect(scenario.sut.isShowingSelector == false)
    }

    // MARK: - The jump, which is the selector's whole job

    @Test
    func `given a file when the reader chooses it then the scroll is asked for it and told once`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()

        // when
        scenario.sut.choose(scenario.fileIds[5])

        // then
        #expect(scenario.sut.jumpTarget == scenario.fileIds[5])
    }

    @Test
    func `given a jump the scroll has made when the same file is chosen again then it is asked for again`() async {
        // given — the reader taps a row, scrolls away by hand, and taps the same row. Held as the
        // value alone that second tap would be a change from a value to itself: no change, no
        // scroll, and a row that did nothing.
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()
        scenario.sut.choose(scenario.fileIds[5])

        // when
        scenario.sut.didJump()

        // then
        #expect(scenario.sut.jumpTarget == nil)

        // and when
        scenario.sut.choose(scenario.fileIds[5])

        // then
        #expect(scenario.sut.jumpTarget == scenario.fileIds[5])
    }

    // MARK: - The mark, which is the one thing this app is for

    @Test
    func `given a file when the reader marks it read then the Mac is told against the content they read`() async {
        // given — the hash is not decoration: a mark applied to a version nobody saw is the one way
        // this feature can actively mislead someone, so the Mac refuses it rather than applying it.
        let scenario = Scenario(files: aChangeSet(of: 4))
        await scenario.sut.load()

        // when
        await scenario.sut.setViewed(true, on: scenario.fileIds[2])

        // then
        #expect(await scenario.repository.viewedWrites == [
            ViewedWrite(
                isViewed: true,
                file: scenario.fileIds[2],
                contentHash: String(repeating: "2", count: 64)
            )
        ])
    }

    @Test
    func `given a file when the reader marks it read then both the header and the selector say so`() async {
        // given — the toggle is in the file header and the report is in the selector, and they are
        // one fact. A mark that moved in one of them would be the app disagreeing with itself about
        // the only thing it is for.
        let scenario = Scenario(files: aChangeSet(of: 4))
        await scenario.sut.load()

        // when
        await scenario.sut.setViewed(true, on: scenario.fileIds[2])

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a loaded change set has to read as something to read")
            return
        }
        #expect(entries[2].file.isViewed)
        #expect(scenario.sut.selector.rows.compactMap(\.file).filter(\.isViewed).map(\.id) == [scenario.fileIds[2]])
    }

    @Test
    func `given every file marked read when the last one lands then the selector says the read is done`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 4))
        await scenario.sut.load()

        // when
        for file in scenario.fileIds {
            await scenario.sut.setViewed(true, on: file)
        }

        // then
        #expect(scenario.sut.selector.footer == .everythingViewed(count: 4))
    }

    @Test
    func `given a Mac that refuses the mark when it is written then it goes back and the reader is told`() async {
        // given — the row changes under the finger and the Mac is a network away, so the write is
        // optimistic. What makes taking it back honest rather than baffling is being told.
        let scenario = Scenario(files: aChangeSet(of: 4), viewedFailure: .fileGone)
        await scenario.sut.load()

        // when
        await scenario.sut.setViewed(true, on: scenario.fileIds[2])

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a refused mark must not replace the file list")
            return
        }
        #expect(entries[2].file.isViewed == false)
        #expect(scenario.sut.selector.rows.compactMap(\.file).contains { $0.isViewed } == false)
        #expect(scenario.sut.viewedFailure == .fileGone)

        // and when — the alert is dismissed
        scenario.sut.dismissViewedFailure()

        // then
        #expect(scenario.sut.viewedFailure == nil)
    }

    @Test
    func `given a file the change set never had when a mark is written then nothing leaves the phone`() async {
        // given — the worktree moves while the phone reads it, and a selector row that outlived its
        // file is a row whose write would name a file this Mac cannot resolve.
        let scenario = Scenario(files: aChangeSet(of: 4))
        await scenario.sut.load()

        // when
        await scenario.sut.setViewed(true, on: FileID(rawValue: "a-file-that-left"))

        // then
        #expect(await scenario.repository.viewedWrites.isEmpty)
        #expect(scenario.sut.viewedFailure == nil)
    }

    @Test
    func `given a mark set on a file whose diff then arrives when it lands then the mark survives it`() async {
        // given — the batch was asked for before the mark was written, so the file that comes back
        // carries the Mac's answer to a question that predates it. Taking the mark off would be the
        // network undoing something the reader did.
        let scenario = Scenario(files: aChangeSet(of: 3), hunksFor: 1)
        await scenario.sut.load()
        await scenario.sut.setViewed(true, on: scenario.fileIds[1])

        // when
        await scenario.sut.reading(0)

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a fetched change set has to read as something to read")
            return
        }
        #expect(entries[1].hunkCountForTests == 1)
        #expect(entries[1].file.isViewed)
    }
}

// MARK: -

private struct Scenario {

    let sut: ClientViewerModel
    let repository: FakeGranitaRepository
    let fileIds: [FileID]

    init(
        files: [FileChange] = [],
        changeSetFailure: ApiFailure? = nil,
        hunksFor position: Int? = nil,
        diffFailure: ApiFailure? = nil,
        viewedFailure: ApiFailure? = nil,
        isTruncated: Bool = false,
        alsoAnswering stranger: FileChange? = nil
    ) {
        fileIds = files.map(\.id)
        let changes = WorktreeChanges(
            revision: "9d41e0c7",
            stats: ChangeStats(filesChanged: files.count, insertions: 12, deletions: 4),
            files: files,
            isTruncated: isTruncated
        )
        repository = FakeGranitaRepository(
            changeSet: changeSetFailure.map(Result.failure) ?? .success(changes),
            hunks: position.map { [files[$0].id: [aHunk]] } ?? [:],
            diffFailure: diffFailure,
            viewedFailure: viewedFailure,
            alsoAnswering: stranger
        )
        sut = ClientViewerModel(worktree: aWorktree, repository: repository)
    }
}

private extension ContinuousDiffEntry {

    /// Named for the tests rather than shipped on the type: nothing on a screen asks either of
    /// these, and a property no screen has agreed to is one this repository has removed twice
    /// already.
    var isAwaitingForTests: Bool {
        if case .awaiting = self { true } else { false }
    }

    var hunkCountForTests: Int {
        switch self {
        case .awaiting: 0
        case .ready(let diff): diff.hunks.count
        }
    }
}

private let aWorktree = WorktreeID(rawValue: "b7c1e0a4f2d84391")

/// Named nothing like the change set's own files, so a diff landing on the wrong row reads as a
/// mix-up rather than as a match.
private let aFileNobodyAskedFor = FileChange(
    id: FileID(rawValue: "a-file-from-the-next-revision"),
    path: "Sources/Arrived.swift",
    oldPath: nil,
    status: .added,
    isBinary: false,
    isSubmodule: false,
    stats: ChangeStats(filesChanged: 1, insertions: 7, deletions: 0),
    contentHash: String(repeating: "f", count: 64),
    estimatedLineCount: 7,
    isViewed: false,
    isTruncated: false,
    language: "swift"
)

private let aHunk = Hunk(
    index: 0,
    oldStart: 1,
    oldCount: 1,
    newStart: 1,
    newCount: 1,
    sectionHeading: nil,
    lines: [
        DiffLine(
            kind: .addition,
            oldNumber: nil,
            newNumber: 1,
            text: "let answer = 42",
            displayColumns: 15,
            segments: nil
        )
    ]
)

/// Eight files across two directories, which is the shape design §3 draws a tree for: over three
/// files, and more than one directory, so the arrangement is a question with two answers.
private func aChangeSetAcrossTwoDirectories() -> [FileChange] {
    aChangeSet(of: 8).enumerated().map { position, file in
        FileChange(
            id: file.id,
            path: position < 5
                ? "Sources/Client/File\(position).swift"
                : "Sources/Server/File\(position).swift",
            oldPath: nil,
            status: file.status,
            isBinary: false,
            isSubmodule: false,
            stats: file.stats,
            contentHash: file.contentHash,
            estimatedLineCount: file.estimatedLineCount,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        )
    }
}

/// Files named so a wrong one is obvious in a failure rather than being one hash among several.
private func aChangeSet(of count: Int) -> [FileChange] {
    (0..<count).map { position in
        FileChange(
            id: FileID(rawValue: "file-\(position)"),
            path: "Sources/File\(position).swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: position, deletions: 1),
            contentHash: String(repeating: "\(position % 10)", count: 64),
            estimatedLineCount: 10 + position,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        )
    }
}
