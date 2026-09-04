import Foundation
import Testing

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

@testable import ClientViewerPresentation

/// Which sides get lexed, in what order, and what happens when the answer is unusable.
///
/// **`SPEC.md` §10's highlighting rules are all about the questions rather than the colours** — per
/// file per side, never per hunk; the visible file first; never a file nobody opened; render plain
/// and upgrade in place — so this suite asserts what left the model and what came back onto which
/// row, and never what a keyword looks like. The theme belongs to the view layer and is held by the
/// baselines.
@Suite("Client viewer highlighting")
struct ClientViewerHighlightingTests {

    // MARK: - What is lexed

    @Test
    func `given a diff that has arrived when the reader reaches it then both its sides are lexed once`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])

        // when
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // then — two strings, one per side, each the whole of that side of the file rather than one
        // hunk of it. The deletion is in the old and the addition in the new, and the context lines
        // are in both.
        #expect(scenario.highlighter.requests.map(\.text) == [
            "func answer() -> Int {\n    41\n}",
            "func answer() -> Int {\n    42\n}"
        ])
        #expect(scenario.highlighter.requests.allSatisfy { $0.language == "swift" })
    }

    @Test
    func `given a lexed file when a row asks for its code then it carries the line it came from`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])

        // when
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // then — the two rows of the changed pair are coloured from two different answers, which is
        // the whole reason a side is a part of the key.
        let file = scenario.sut.highlighted[scenario.fileIds[0]]
        #expect(file?.text(of: theDeletion) == AttributedString("    41"))
        #expect(file?.text(of: theAddition) == AttributedString("    42"))
    }

    @Test
    func `given a file claiming no language when it arrives then nothing is lexed`() async {
        // given — `SPEC.md` §10 skips entirely when `language` is nil, and the Mac sends nothing for
        // an extension it does not recognise rather than guessing.
        let scenario = Scenario(files: [aFileWithNoLanguage], hunks: [aChangedPair])

        // when
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // then
        #expect(scenario.highlighter.requests.isEmpty)
        #expect(scenario.sut.highlighted.isEmpty)
    }

    @Test
    func `given a file the reader shut when the screen re-reports its appearance then it is not lexed`() async {
        // given — **the rule is "never speculatively highlight unopened files", and a file with its
        // diff already in hand is exactly where that can be broken without noticing.** The loader
        // steps over a shut file, so nothing else in the model would have caught this.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        await scenario.sut.setOpen(false, on: scenario.fileIds[0])

        // when — a different appearance, so every cached answer is thrown away and everything open
        // is asked again.
        await scenario.sut.drawing(in: .dark, at: 11)

        // then — the two light-mode requests and not one more.
        #expect(scenario.highlighter.requests.count == 2)
        #expect(scenario.sut.highlighted.isEmpty)
    }

    @Test
    func `given a file the reader opens when its diff arrives then it is lexed`() async {
        // given — a file marked viewed is drawn shut, so the scroll never fetched it and the lexer
        // never saw it. Opening one is what makes design §4's *Load diff* a control rather than a
        // label, and the colours have to follow the same press.
        let scenario = Scenario(files: aChangeSet(of: 1, viewedAt: 0), hunks: [aChangedPair])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        #expect(scenario.highlighter.requests.isEmpty)

        // when
        await scenario.sut.setOpen(true, on: scenario.fileIds[0])

        // then
        #expect(scenario.highlighter.requests.count == 2)
        #expect(scenario.sut.highlighted[scenario.fileIds[0]]?.text(of: theAddition) == AttributedString("    42"))
    }

    @Test
    func `given a file already in hand when the reader opens it then it is lexed without a second fetch`() async {
        // given — shut by hand rather than by the mark, so its diff is already here. Opening it must
        // colour it and must not ask the Mac for what it is holding.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        await scenario.sut.setOpen(false, on: scenario.fileIds[0])
        await scenario.sut.drawing(in: .dark, at: 11)
        let batches = scenario.repository.batchesAskedFor.count

        // when
        await scenario.sut.setOpen(true, on: scenario.fileIds[0])

        // then
        #expect(scenario.repository.batchesAskedFor.count == batches)
        #expect(scenario.sut.highlighted[scenario.fileIds[0]]?.text(of: theAddition) == AttributedString("    42"))
    }

    @Test
    func `given the reader partway down a change set when its files are lexed then theirs is the first`() async {
        // given — **files are fetched five *ahead*, so walking the change set from the top would
        // colour the file they have left before the one they are on.** `SPEC.md` §10: highlight the
        // visible file first.
        let files = aChangeSet(of: 12)
        let scenario = Scenario(files: files, hunks: files.indices.map { anAdditionSaying("let file = \($0)") })
        await scenario.sut.load()

        // when
        await scenario.sut.reading(5)

        // then — file 5 is the one under the thumb and the one lexed first, and the four fetched
        // ahead of it follow. Every side here is an addition, so there is one request per file.
        #expect(scenario.highlighter.requests.map(\.text) == (5...9).map { "let file = \($0)" })
    }

    // MARK: - What invalidates it

    @Test
    func `given the appearance changing when the screen says so then every side is lexed again for it`() async {
        // given — the colours are baked into the answer rather than applied over it, so a dark screen
        // needs a different answer and not the same one restyled.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.drawing(in: .dark, at: 11)

        // then
        #expect(scenario.highlighter.requests.count == 4)
        #expect(scenario.highlighter.requests.suffix(2).allSatisfy { $0.appearance == .dark })
    }

    @Test
    func `given an unchanged appearance when the screen says so again then nothing is lexed twice`() async {
        // given — the screen reports on every appearance of the view, and a `.task` re-runs whenever
        // it comes back. Without the record of what has already been asked, scrolling away and back
        // would re-lex the whole change set.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.drawing(in: .light, at: Double(DiffPaneLayout.codePointSize))
        await scenario.sut.drawing(in: .light, at: Double(DiffPaneLayout.codePointSize))

        // then
        #expect(scenario.highlighter.requests.count == 2)
    }

    @Test
    func `given a change set read again when it lands then nothing lexed against the last one is kept`() async {
        // given — a retry after a failure reads the whole change set again, and what was coloured
        // against the last one addresses files this screen may no longer draw.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])
        await scenario.sut.load()
        await scenario.sut.reading(0)
        #expect(scenario.sut.highlighted.isEmpty == false)

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.highlighted.isEmpty)
    }

    @Test
    func `given nothing read yet when the screen reports what it draws with then nothing is lexed`() async {
        // given — the screen reports its appearance from its own `.task`, which can run before the
        // change set has arrived.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair])

        // when
        await scenario.sut.drawing(in: .dark, at: 12)

        // then
        #expect(scenario.highlighter.requests.isEmpty)
    }

    // MARK: - When the answer cannot be used

    @Test
    func `given a lexer that refuses when a side is offered then the file draws plain`() async {
        // given — an unknown language, a bundle without that grammar, a JavaScript context that
        // would not build: every one of them is the same outcome, which is the state every file is
        // already in before its colours land.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair], lexerRefuses: true)

        // when
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // then — asked, and nothing filed.
        #expect(scenario.highlighter.requests.count == 2)
        #expect(scenario.sut.highlighted.isEmpty)
    }

    @Test
    func `given a lexer that answered short when a side is offered then none of that side is drawn`() async {
        // given — the lexer is a JavaScript engine behind a bridge and the string it is handed has
        // been through two splits. A result one line short would shift every colour after it onto the
        // wrong row, which reads as a highlighter that is subtly wrong rather than one that did not
        // run.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair], lexerDropsALine: true)

        // when
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // then
        #expect(scenario.sut.highlighted.isEmpty)
    }

    @Test
    func `given a lexer that refused once when the same side comes round again then it is not asked twice`() async {
        // given — a refusal is a property of the text and the language, so asking again spends a
        // round trip through a JavaScript engine to be told the same thing.
        let scenario = Scenario(files: aChangeSet(of: 1), hunks: [aChangedPair], lexerRefuses: true)
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.drawing(in: .light, at: Double(DiffPaneLayout.codePointSize))

        // then
        #expect(scenario.highlighter.requests.count == 2)
    }
}

// MARK: -

private struct Scenario {

    let sut: ClientViewerModel
    let repository: FakeGranitaRepository
    let highlighter: FakeSyntaxHighlighter
    let fileIds: [FileID]

    /// One hunk per file, in the change set's own order, so a request can be traced back to the file
    /// that produced it by its text alone.
    init(
        files: [FileChange],
        hunks: [Hunk],
        lexerRefuses: Bool = false,
        lexerDropsALine: Bool = false
    ) {
        fileIds = files.map(\.id)
        let changes = WorktreeChanges(
            revision: "9d41e0c7",
            stats: ChangeStats(filesChanged: files.count, insertions: 12, deletions: 4),
            files: files,
            isTruncated: false
        )
        repository = FakeGranitaRepository(
            changeSet: .success(changes),
            hunks: Dictionary(
                uniqueKeysWithValues: zip(files.map(\.id), hunks.map { [$0] })
            )
        )
        highlighter = FakeSyntaxHighlighter(refuses: lexerRefuses, dropsALine: lexerDropsALine)
        sut = ClientViewerModel(
            worktree: WorktreeID(rawValue: "b7c1e0a4f2d84391"),
            worktreeName: "TLS pinning",
            projectName: "granita",
            repository: repository,
            commentStore: FakeReviewCommentStore(),
            pasteboard: FakeReviewPasteboard(),
            highlighter: highlighter
        )
    }
}

// MARK: -

/// A pair the parser changed, so the two sides are different strings and a mix-up between them is
/// visible in the assertion rather than hidden by them agreeing.
private let aChangedPair = Hunk(
    index: 0,
    oldStart: 5,
    oldCount: 3,
    newStart: 5,
    newCount: 3,
    sectionHeading: "func answer() -> Int",
    lines: [
        DiffLine(kind: .context, oldNumber: 5, newNumber: 5, text: "func answer() -> Int {", displayColumns: 22, segments: nil),
        theDeletion,
        theAddition,
        DiffLine(kind: .context, oldNumber: 7, newNumber: 7, text: "}", displayColumns: 1, segments: nil)
    ]
)

private let theDeletion = DiffLine(
    kind: .deletion,
    oldNumber: 6,
    newNumber: nil,
    text: "    41",
    displayColumns: 6,
    segments: nil
)

private let theAddition = DiffLine(
    kind: .addition,
    oldNumber: nil,
    newNumber: 6,
    text: "    42",
    displayColumns: 6,
    segments: nil
)

/// One added line, which puts the whole of a file on the new side and leaves the old side with
/// nothing to lex — so one file is one request and the order of them is readable.
private func anAdditionSaying(_ text: String) -> Hunk {
    Hunk(
        index: 0,
        oldStart: 0,
        oldCount: 0,
        newStart: 1,
        newCount: 1,
        sectionHeading: nil,
        lines: [
            DiffLine(kind: .addition, oldNumber: nil, newNumber: 1, text: text, displayColumns: text.count, segments: nil)
        ]
    )
}

private let aFileWithNoLanguage = FileChange(
    id: FileID(rawValue: "a-drawing"),
    path: "Art/icon/granita-tinted.svg",
    oldPath: nil,
    status: .modified,
    isBinary: false,
    isSubmodule: false,
    stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 1),
    contentHash: String(repeating: "e", count: 64),
    estimatedLineCount: 4,
    isViewed: false,
    isTruncated: false,
    language: nil
)

private func aChangeSet(of count: Int, viewedAt read: Int? = nil) -> [FileChange] {
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
            isViewed: position == read,
            isTruncated: false,
            language: "swift"
        )
    }
}
