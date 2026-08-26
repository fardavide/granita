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
        alsoAnswering stranger: FileChange? = nil
    ) {
        fileIds = files.map(\.id)
        let changes = WorktreeChanges(
            revision: "9d41e0c7",
            stats: ChangeStats(filesChanged: files.count, insertions: 12, deletions: 4),
            files: files,
            isTruncated: false
        )
        repository = FakeGranitaRepository(
            changeSet: changeSetFailure.map(Result.failure) ?? .success(changes),
            hunks: position.map { [files[$0].id: [aHunk]] } ?? [:],
            diffFailure: diffFailure,
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
