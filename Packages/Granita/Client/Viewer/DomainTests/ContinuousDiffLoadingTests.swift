import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// The rule underneath the whole viewer, and the one `SPEC.md` §10 marks as the defect that kills
/// naive implementations: **nothing above the reader's finger may change size.**
///
/// A lazy stack estimates the height of what it has not drawn. When a placeholder becomes real
/// content its height changes, and everything after it shifts — which is invisible below the
/// viewport and is the content jumping under the finger above it. The resolution is ordering rather
/// than exact estimates, so what these assert is the ordering.
@Suite("Continuous diff loading")
struct ContinuousDiffLoadingTests {

    @Test
    func `given nothing loaded when the top of the list is visible then it asks for the window`() {
        // given
        let files = fileIds(count: 12)

        // when
        let wanted = ContinuousDiffLoading.next(from: 0, of: files, held: [], inFlight: [], deferred: [])

        // then — the visible file and four after it, because the file being read has to be one of
        // the five rather than the one the window starts after.
        #expect(wanted == Array(files.prefix(5)))
    }

    @Test
    func `given the reader is halfway down when the window is asked for then nothing behind them is in it`() {
        // given — the file at index 6 is on screen, and the three before it were never fetched,
        // which is what happens when a reader arrives partway down.
        let files = fileIds(count: 12)

        // when
        let wanted = ContinuousDiffLoading.next(from: 6, of: files, held: Set(files.prefix(3)), inFlight: [], deferred: [])

        // then — **the three gaps behind them stay gaps.** Filling one would turn a placeholder
        // sitting above the viewport into real content, and everything below it, the viewport
        // included, would move.
        #expect(wanted == Array(files[6..<11]))
    }

    @Test
    func `given the window is partly held when it is asked for then it reaches further down the list`() {
        // given
        let files = fileIds(count: 12)

        // when — two of the five ahead are already in hand.
        let wanted = ContinuousDiffLoading.next(from: 2, of: files, held: [files[3], files[5]], inFlight: [], deferred: [])

        // then — five files' worth of work rather than five positions' worth: the window is how
        // much is being fetched, and one already fetched costs nothing to skip.
        #expect(wanted == [files[2], files[4], files[6], files[7], files[8]])
    }

    @Test
    func `given a request already in flight when the window is asked for then it is not asked for twice`() {
        // given — scrolling produces a position update per frame, so without this the same file is
        // requested every frame until the first answer lands.
        let files = fileIds(count: 12)

        // when
        let wanted = ContinuousDiffLoading.next(
            from: 0,
            of: files,
            held: [],
            inFlight: [files[0], files[1]],
            deferred: []
        )

        // then
        #expect(wanted == Array(files[2..<7]))
    }

    @Test
    func `given a file drawn shut when the window is asked for then it is stepped over`() {
        // given — a file the scroll is drawing as a bar. `SPEC.md` §10 puts a *Load diff*
        // affordance on the big ones, and a phone that fetched them anyway would be offering to do
        // something it had already done.
        let files = fileIds(count: 12)

        // when
        let wanted = ContinuousDiffLoading.next(
            from: 0,
            of: files,
            held: [],
            inFlight: [],
            deferred: [files[1], files[2]]
        )

        // then — stepped over rather than stopped at: the window is five files of work, and the two
        // nobody asked for cost nothing to skip.
        #expect(wanted == [files[0], files[3], files[4], files[5], files[6]])
    }

    @Test
    func `given the file being read is drawn shut when the window is asked for then the rest still loads`() {
        // given — the reader is resting on a bar, which is the ordinary case for a change set they
        // have already been through once: every file they read is shut.
        let files = fileIds(count: 12)

        // when
        let wanted = ContinuousDiffLoading.next(
            from: 0,
            of: files,
            held: [],
            inFlight: [],
            deferred: [files[0]]
        )

        // then — a deferred file is skipped and never a stopping point, or a reader who marked the
        // first file read would have stopped the scroll fetching anything at all.
        #expect(wanted == Array(files[1..<6]))
    }

    @Test
    func `given everything ahead is held when the window is asked for then nothing is asked for`() {
        // given
        let files = fileIds(count: 4)

        // when
        let wanted = ContinuousDiffLoading.next(from: 1, of: files, held: Set(files), inFlight: [], deferred: [])

        // then
        #expect(wanted.isEmpty)
    }

    @Test
    func `given the last file is visible when the window is asked for then it stops at the end`() {
        // given
        let files = fileIds(count: 3)

        // when
        let wanted = ContinuousDiffLoading.next(from: 2, of: files, held: [], inFlight: [], deferred: [])

        // then
        #expect(wanted == [files[2]])
    }

    @Test
    func `given a position past the end when the window is asked for then nothing is asked for`() {
        // given — reachable while a change set is being replaced under a scroll that has not been
        // told yet, and the alternative to answering it is an index out of range.
        let files = fileIds(count: 3)

        // when
        let wanted = ContinuousDiffLoading.next(from: 9, of: files, held: [], inFlight: [], deferred: [])

        // then
        #expect(wanted.isEmpty)
    }

    @Test
    func `given a negative position when the window is asked for then it starts at the top`() {
        // given — a scroll offset above the first row is a real reading during a rubber-band, and
        // clamping is the honest answer rather than refusing to load anything.
        let files = fileIds(count: 3)

        // when
        let wanted = ContinuousDiffLoading.next(from: -2, of: files, held: [], inFlight: [], deferred: [])

        // then
        #expect(wanted == files)
    }

    @Test
    func `given no files at all when the window is asked for then nothing is asked for`() {
        // given - when
        let wanted = ContinuousDiffLoading.next(from: 0, of: [], held: [], inFlight: [], deferred: [])

        // then
        #expect(wanted.isEmpty)
    }

    @Test
    func `given a window when it is spent then it is never more than one request may carry`() {
        // given — `/diffs` refuses more than twenty identifiers, and the window is what decides how
        // many go in one. Asserted rather than left to the constant, because raising the window is
        // a one-character change and the refusal it would earn arrives from the other machine.
        #expect(ContinuousDiffLoading.filesAhead <= 20)
    }
}

// MARK: -

private func fileIds(count: Int) -> [FileID] {
    (0..<count).map { FileID(rawValue: "file-\($0)") }
}
