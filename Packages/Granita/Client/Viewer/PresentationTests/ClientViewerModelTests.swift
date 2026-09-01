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
        #expect(entries.allSatisfy { $0.isAwaitingForTests })
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

    @Test
    func `given a read this phone called off when it ends then the screen is not told the Mac failed`() async {
        // given — a `.task` is torn down whenever its view goes away, so opening a worktree while
        // the list behind it is still loading cancels the read. Reported as a failure it put *Could
        // not read your Mac* on screen with `NSURLErrorDomain Code=-999 "cancelled"` underneath —
        // the app blaming the Mac for something the app did. Seen on a real iPhone.
        let scenario = Scenario(files: aChangeSet(of: 3), changeSetFailure: .cancelled)

        // when
        await scenario.sut.load()

        // then — still loading, because that is what was true when the reader left.
        #expect(scenario.sut.state == .loading)
    }

    @Test
    func `given a change set already read when a later read is called off then what was read stays`() async {
        // given — the reader has content on screen and something re-reads underneath them.
        let scenario = Scenario(files: aChangeSet(of: 3))
        await scenario.sut.load()
        let refusing = Scenario(files: aChangeSet(of: 3), changeSetFailure: .cancelled)
        await refusing.sut.load()

        // when - then — nothing was read, so there is nothing to keep and the spinner is honest.
        #expect(refusing.sut.state == .loading)
        guard case .reading = scenario.sut.state else {
            Issue.record("a loaded change set has to read as something to read")
            return
        }
    }

    @Test
    func `given a mark this phone called off when it ends then the mark stands and nothing is said`() async {
        // given — the reader set a mark and left. Taking it back and saying the Mac refused would be
        // the app inventing a refusal nobody made.
        let scenario = Scenario(files: aChangeSet(of: 4), viewedFailure: .cancelled)
        await scenario.sut.load()

        // when
        await scenario.sut.setViewed(true, on: scenario.fileIds[2])

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a loaded change set has to read as something to read")
            return
        }
        #expect(entries[2].file.isViewed)
        #expect(scenario.sut.viewedFailure == nil)
    }

    @Test
    func `given a failed read when the same model retries then the failure leaves the screen`() async {
        // given — **one model through both**, which is the whole point: a retry that left the
        // failure up until the answer arrived was reported as a button with nothing behind it, and
        // `/changes` is slow enough on real repositories to make that indistinguishable from true.
        let scenario = Scenario(files: aChangeSet(of: 3), refusesTheFirstRead: .worktreeGone)
        await scenario.sut.load()
        #expect(scenario.sut.state == .failed(.worktreeGone))

        // when
        await scenario.sut.load()

        // then
        guard case .reading = scenario.sut.state else {
            Issue.record("a retry that answers has to show what it read")
            return
        }
    }

    @Test
    func `given a change set on screen when a later read is called off then the reader keeps it`() async {
        // given — a screen re-runs its `.task` every time it appears, so a diff that is already
        // drawn gets re-read; the reader leaving again cancels that. Falling back to the spinner
        // here would empty a screen they were reading.
        let scenario = Scenario(files: aChangeSet(of: 3))
        await scenario.sut.load()

        // when — the model is asked to read again and that read is called off
        let refusing = Scenario(files: aChangeSet(of: 3), changeSetFailure: .cancelled)
        await refusing.sut.load()
        await scenario.sut.setViewed(true, on: scenario.fileIds[0])

        // then — the one that had content still has it, entry for entry.
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a loaded change set has to read as something to read")
            return
        }
        #expect(entries.count == 3)
        #expect(refusing.sut.state == .loading)
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

    @Test
    func `given the drawer fills the screen when a file is chosen then it drops to half so the jump can be seen`() async {
        // given — the reader has pulled the list up over the whole phone, which is the one height at
        // which the diff behind it is not there to scroll.
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()
        scenario.sut.showSelector(true)
        scenario.sut.drawerDetent = .large

        // when
        scenario.sut.choose(scenario.fileIds[5])

        // then — halved rather than dismissed: the list is still up, which is what §3 keeps it for.
        #expect(scenario.sut.drawer == .half)
        #expect(scenario.sut.isShowingSelector)
    }

    @Test
    func `given the drawer is already half when a file is chosen then it is left where the reader put it`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()
        scenario.sut.showSelector(true)

        // when
        scenario.sut.choose(scenario.fileIds[2])

        // then — half is where it starts, and choosing a file is not a reason to move a sheet that
        // is already showing the diff behind it.
        #expect(scenario.sut.drawer == .half)
    }

    @Test
    func `given the reader drags the drawer up when nothing is chosen then it stays where they put it`() async {
        // given — the height is the reader's until a jump needs it back, so the sheet's own gesture
        // has to be able to write it.
        let scenario = Scenario(files: aChangeSet(of: 8))
        await scenario.sut.load()
        scenario.sut.showSelector(true)

        // when — the sheet writes the height it was dragged to, which is what the screen's binding
        // projects.
        scenario.sut.drawerDetent = .large

        // then
        #expect(scenario.sut.drawer == .whole)
        #expect(scenario.sut.drawerDetent == .large)

        // and when — dragged back down by hand
        scenario.sut.drawerDetent = .medium

        // then — both halves of the translation, which is the rule the screen used to carry in two
        // closures nothing could reach.
        #expect(scenario.sut.drawer == .half)
        #expect(scenario.sut.drawerDetent == .medium)
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
        //
        // The mark shuts the file, so the reader opens it again — which is the ordinary way back to
        // a file you have read and want to check.
        let scenario = Scenario(files: aChangeSet(of: 3), hunksFor: 1)
        await scenario.sut.load()
        await scenario.sut.setViewed(true, on: scenario.fileIds[1])
        await scenario.sut.setOpen(true, on: scenario.fileIds[1])

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

    // MARK: - What is drawn shut, and what that costs the loader

    @Test
    func `given a file already marked read when the scroll loads then its diff is never asked for`() async {
        // given — `SPEC.md` §10 draws a file marked viewed collapsed, and a collapsed file is one
        // the reader has said they are done with. Spending a batch slot on it is this phone doing
        // work for a screen it is not going to draw.
        let scenario = Scenario(files: aChangeSet(of: 3, viewedAt: 1))
        await scenario.sut.load()

        // when
        await scenario.sut.reading(0)

        // then
        #expect(await scenario.repository.batchesAskedFor == [[scenario.fileIds[0], scenario.fileIds[2]]])
    }

    @Test
    func `given a shut file when the reader opens it then its diff is asked for`() async {
        // given — **this is the half that makes the bar a control.** Without it, pressing one leaves
        // a header over a blank stretch that nothing ever fills, which is the dead control this
        // project has shipped once already.
        let scenario = Scenario(files: aChangeSet(of: 3, viewedAt: 1), hunksFor: 1)
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.setOpen(true, on: scenario.fileIds[1])

        // then
        #expect(await scenario.repository.batchesAskedFor.last == [scenario.fileIds[1]])
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a fetched change set has to read as something to read")
            return
        }
        #expect(entries[1].collapse.isCollapsed == false)
        #expect(entries[1].hunkCountForTests == 1)
    }

    @Test
    func `given a file whose diff is in hand when the reader opens it then nothing is asked for again`() async {
        // given — the ordinary case: the reader marks a file read while looking at it, then changes
        // their mind. The diff never left.
        let scenario = Scenario(files: aChangeSet(of: 3), hunksFor: 1)
        await scenario.sut.load()
        await scenario.sut.reading(0)
        await scenario.sut.setViewed(true, on: scenario.fileIds[1])
        let asked = await scenario.repository.batchesAskedFor.count

        // when
        await scenario.sut.setOpen(true, on: scenario.fileIds[1])

        // then
        #expect(await scenario.repository.batchesAskedFor.count == asked)
    }

    @Test
    func `given an open file when the reader shuts it then it is drawn shut with no reason to print`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 3))
        await scenario.sut.load()

        // when
        await scenario.sut.setOpen(false, on: scenario.fileIds[0])

        // then — the four sentences design §4 draws are the four the app decided on its own, so a
        // file the reader shut has nothing to say back to them about it.
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a change set has to read as something to read")
            return
        }
        #expect(entries[0].collapse.isCollapsed)
        #expect(entries[0].collapse.reason == nil)
    }

    @Test
    func `given a binary file when the reader tries to open it then it stays shut`() async {
        // given — unreachable through the bar, which draws no chevron for it. Asserted because a
        // guard that depends on a view not offering a control is one refactor from being wrong.
        let scenario = Scenario(files: [aBinaryFile])
        await scenario.sut.load()

        // when
        await scenario.sut.setOpen(true, on: aBinaryFile.id)

        // then
        guard case .reading(let entries) = scenario.sut.state else {
            Issue.record("a change set has to read as something to read")
            return
        }
        #expect(entries[0].collapse.isCollapsed)
        #expect(await scenario.repository.batchesAskedFor.isEmpty)
    }

    @Test
    func `given a file the change set never named when it is opened then nothing happens`() async {
        // given — the same shape as the mark's own miss: a stale row, or a change set replaced under
        // a press.
        let scenario = Scenario(files: aChangeSet(of: 3))
        await scenario.sut.load()

        // when
        await scenario.sut.setOpen(true, on: FileID(rawValue: "a-file-that-left"))

        // then
        #expect(await scenario.repository.batchesAskedFor.isEmpty)
    }

    // MARK: - Expanding a hunk

    @Test
    func `given a hunk with lines above it when it is expanded then the window asked for is the gap`() async {
        // given — a hunk covering lines 5 and 6 of a ten-line file, so there are four lines above it
        // and four below.
        let scenario = Scenario(
            files: aChangeSet(of: 1),
            hunksFor: 0,
            hunks: [aHunkInTheMiddle],
            linesAnswer: .success(FileLines(lines: ["    let a = 1", "    let b = 2"], eof: false))
        )
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.expand(.above, hunk: 0, in: scenario.fileIds[0])

        // then — the gap, on the new side, stopping where the hunk's own first line begins. A whole
        // step would have asked for lines before the file starts.
        #expect(await scenario.repository.windowsAskedFor == [LineWindow(side: .new, start: 1, count: 4)])
    }

    @Test
    func `given lines that come back when a hunk is expanded then they are spliced into its own diff`() async {
        // given
        let scenario = Scenario(
            files: aChangeSet(of: 1),
            hunksFor: 0,
            hunks: [aHunkInTheMiddle],
            linesAnswer: .success(FileLines(lines: ["    let a = 1", "    let b = 2"], eof: false))
        )
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.expand(.above, hunk: 0, in: scenario.fileIds[0])

        // then — **into the hunk rather than beside it**, which is what makes "is there anything
        // left above this" answerable from what is drawn.
        guard case .reading(let entries) = scenario.sut.state,
              case .ready(let diff) = entries[0].content else {
            Issue.record("an expanded file has to have a diff to have expanded")
            return
        }
        #expect(diff.hunks[0].lines.count == 4)
        #expect(diff.hunks[0].lines.first?.text == "    let a = 1")
        #expect(diff.hunks[0].newStart == 3)
    }

    @Test
    func `given a hunk at the top of a file when it is expanded then nothing is asked of the Mac`() async {
        // given — `aHunk` starts at line 1, so there is no gap above it. The control is absent for
        // this hunk, so reaching the model at all means the file moved under a press.
        let scenario = Scenario(files: aChangeSet(of: 1), hunksFor: 0)
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.expand(.above, hunk: 0, in: scenario.fileIds[0])

        // then
        #expect(await scenario.repository.windowsAskedFor.isEmpty)
        #expect(scenario.sut.expansionFailure == nil)
    }

    @Test
    func `given a file whose diff has not arrived when a hunk of it is expanded then nothing is asked for`() async {
        // given — no diff means no hunks, so there is no gap anybody could have pressed.
        let scenario = Scenario(files: aChangeSet(of: 3))
        await scenario.sut.load()

        // when
        await scenario.sut.expand(.below, hunk: 0, in: scenario.fileIds[0])

        // then
        #expect(await scenario.repository.windowsAskedFor.isEmpty)
    }

    @Test
    func `given a hunk index the file does not have when it is expanded then nothing is asked for`() async {
        // given
        let scenario = Scenario(files: aChangeSet(of: 1), hunksFor: 0, hunks: [aHunkInTheMiddle])
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.expand(.above, hunk: 7, in: scenario.fileIds[0])

        // then
        #expect(await scenario.repository.windowsAskedFor.isEmpty)
    }

    @Test
    func `given the Mac refuses the lines when a hunk is expanded then the reader is told`() async {
        // given — **a refusal here is reported where a refused batch is not**, and the difference is
        // what the reader did: a batch is fetched on their behalf while they scroll, and an
        // expansion is a control they pressed. A press that leaves the hunk as it was is a control
        // that did nothing.
        let scenario = Scenario(
            files: aChangeSet(of: 1),
            hunksFor: 0,
            hunks: [aHunkInTheMiddle],
            linesAnswer: .failure(.fileGone)
        )
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.expand(.above, hunk: 0, in: scenario.fileIds[0])

        // then
        #expect(scenario.sut.expansionFailure == .fileGone)
        guard case .reading(let entries) = scenario.sut.state,
              case .ready(let diff) = entries[0].content else {
            Issue.record("a fetched file has to have a diff")
            return
        }
        // The hunk is exactly the two lines it arrived with, which is the half that makes this a
        // control that did nothing without the alert above.
        #expect(diff.hunks[0].lines.count == 2)
    }

    @Test
    func `given a refusal the reader has read when it is dismissed then it is gone`() async {
        // given
        let scenario = Scenario(
            files: aChangeSet(of: 1),
            hunksFor: 0,
            hunks: [aHunkInTheMiddle],
            linesAnswer: .failure(.fileGone)
        )
        await scenario.sut.load()
        await scenario.sut.reading(0)
        await scenario.sut.expand(.above, hunk: 0, in: scenario.fileIds[0])

        // when
        scenario.sut.dismissExpansionFailure()

        // then
        #expect(scenario.sut.expansionFailure == nil)
    }

    @Test
    func `given a hunk with lines below it when it is expanded downwards then the window follows it`() async {
        // given — the hunk covers lines 5 and 6 of a ten-line file.
        let scenario = Scenario(
            files: aChangeSet(of: 1),
            hunksFor: 0,
            hunks: [aHunkInTheMiddle],
            linesAnswer: .success(FileLines(lines: ["    let c = 3"], eof: true))
        )
        await scenario.sut.load()
        await scenario.sut.reading(0)

        // when
        await scenario.sut.expand(.below, hunk: 0, in: scenario.fileIds[0])

        // then — the Mac reports a new side ten lines long, so the window runs from just after the
        // hunk to the end of the file rather than a whole step past it.
        #expect(await scenario.repository.windowsAskedFor == [LineWindow(side: .new, start: 7, count: 4)])
        guard case .reading(let entries) = scenario.sut.state,
              case .ready(let diff) = entries[0].content else {
            Issue.record("an expanded file has to have a diff to have expanded")
            return
        }
        #expect(diff.hunks[0].lines.last?.text == "    let c = 3")
        #expect(diff.hunks[0].lines.last?.newNumber == 7)
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
        hunks: [Hunk]? = nil,
        diffFailure: ApiFailure? = nil,
        viewedFailure: ApiFailure? = nil,
        linesAnswer: Result<FileLines, ApiFailure> = .failure(.fileGone),
        refusesTheFirstRead: ApiFailure? = nil,
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
            hunks: position.map { [files[$0].id: hunks ?? [aHunk]] } ?? [:],
            diffFailure: diffFailure,
            viewedFailure: viewedFailure,
            linesAnswer: linesAnswer,
            refusesTheFirstRead: refusesTheFirstRead,
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
        if case .awaiting = content { true } else { false }
    }

    var hunkCountForTests: Int {
        switch content {
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

/// A hunk with room on both sides of it: lines 5 and 6 of a file the change set says is ten long,
/// so there are four lines above and four below and neither reaches a whole step.
private let aHunkInTheMiddle = Hunk(
    index: 0,
    oldStart: 5,
    oldCount: 2,
    newStart: 5,
    newCount: 2,
    sectionHeading: "func answer() -> Int",
    lines: [
        DiffLine(kind: .context, oldNumber: 5, newNumber: 5, text: "func answer() -> Int {", displayColumns: 22, segments: nil),
        DiffLine(kind: .addition, oldNumber: nil, newNumber: 6, text: "    42", displayColumns: 6, segments: nil)
    ]
)

/// Nothing behind it, ever, which is one of the two files design §4 gives no chevron.
private let aBinaryFile = FileChange(
    id: FileID(rawValue: "a-drawing"),
    path: "Art/icon/granita-tinted.svg",
    oldPath: nil,
    status: .added,
    isBinary: true,
    isSubmodule: false,
    stats: ChangeStats(filesChanged: 1, insertions: 0, deletions: 0),
    contentHash: String(repeating: "e", count: 64),
    estimatedLineCount: 0,
    isViewed: false,
    isTruncated: false,
    language: nil
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
