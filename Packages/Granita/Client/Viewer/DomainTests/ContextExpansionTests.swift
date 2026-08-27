import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// The lines between the hunks, and who owns the question of which of them are on screen.
///
/// **`SPEC.md` §8 makes the server stateless about this on purpose**: a single parameter cannot
/// express "hunk 2 expanded up and hunk 5 expanded down", so the Mac hands over raw lines and holds
/// no position. Everything here is that position — which window to ask for, and what the hunk
/// becomes once the answer lands.
///
/// The window is asked for on the **new** side throughout. Context lines are by definition the same
/// on both, the reader is reading the working copy, and a file with no new side — a deletion — has
/// no gap to expand into, which is asserted below rather than assumed.
@Suite("Context expansion")
struct ContextExpansionTests {

    // MARK: - What there is room for

    @Test
    func `given a hunk with lines above it when the window above is asked for then it stops at the file's top`() {
        // given — a hunk starting at line 8 has seven lines above it, which is fewer than one step.
        let hunk = aHunk(oldStart: 8, oldCount: 4, newStart: 8, newCount: 4)

        // when
        let window = ContextExpansion.above(hunk, after: nil)

        // then — seven, from line 1. Asking for twenty would be asking the Mac for lines 12 through
        // 7, and a window that starts before the file does is a request whose answer nobody can
        // splice.
        #expect(window == LineWindow(side: .new, start: 1, count: 7))
    }

    @Test
    func `given a deep hunk when the window above is asked for then it is one step`() {
        // given
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let window = ContextExpansion.above(hunk, after: nil)

        // then — a step below the hunk's own first line, on the side the reader is reading.
        #expect(window == LineWindow(side: .new, start: 138 - ContextExpansion.step, count: ContextExpansion.step))
    }

    @Test
    func `given a hunk at the top of the file when the window above is asked for then there is none`() {
        // given
        let hunk = aHunk(oldStart: 1, oldCount: 4, newStart: 1, newCount: 4)

        // when
        let window = ContextExpansion.above(hunk, after: nil)

        // then — no window, which is what the header reads to decide whether to draw the control at
        // all. A chevron over an empty gap is design §4's smallest possible lie.
        #expect(window == nil)
    }

    @Test
    func `given hunks that meet when the window between them is asked for then there is none`() {
        // given — the previous hunk ends at line 20 and this one starts at 21, so the two are
        // already contiguous even though git drew them apart.
        let previous = aHunk(oldStart: 11, oldCount: 10, newStart: 11, newCount: 10)
        let hunk = aHunk(oldStart: 21, oldCount: 4, newStart: 21, newCount: 4)

        // when
        let window = ContextExpansion.above(hunk, after: previous)

        // then
        #expect(window == nil)
    }

    @Test
    func `given a gap smaller than a step when the window above is asked for then it fills the gap`() {
        // given — the previous hunk ends at 20 and this one starts at 26: five lines between them.
        let previous = aHunk(oldStart: 11, oldCount: 10, newStart: 11, newCount: 10)
        let hunk = aHunk(oldStart: 26, oldCount: 4, newStart: 26, newCount: 4)

        // when
        let window = ContextExpansion.above(hunk, after: previous)

        // then — exactly the gap, so one press closes it and the control then goes.
        #expect(window == LineWindow(side: .new, start: 21, count: 5))
    }

    @Test
    func `given a hunk with the file running on below it when the window below is asked for then it is one step`() {
        // given — the hunk covers 138 to 144 of a 400-line file.
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let window = ContextExpansion.below(hunk, before: nil, endingAt: 400)

        // then
        #expect(window == LineWindow(side: .new, start: 145, count: ContextExpansion.step))
    }

    @Test
    func `given a hunk near the end of the file when the window below is asked for then it stops at the end`() {
        // given — the hunk ends at line 144 of a 150-line file.
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let window = ContextExpansion.below(hunk, before: nil, endingAt: 150)

        // then — six lines, 145 through 150. `newLineCount` is on `FileDiff` for exactly this: it
        // is what makes "can this hunk expand downwards" answerable without asking the Mac.
        #expect(window == LineWindow(side: .new, start: 145, count: 6))
    }

    @Test
    func `given a hunk reaching the end of the file when the window below is asked for then there is none`() {
        // given
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let window = ContextExpansion.below(hunk, before: nil, endingAt: 144)

        // then
        #expect(window == nil)
    }

    @Test
    func `given another hunk below when the window below is asked for then it stops before it`() {
        // given — this hunk ends at 144 and the next one starts at 152.
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)
        let next = aHunk(oldStart: 154, oldCount: 4, newStart: 152, newCount: 4)

        // when
        let window = ContextExpansion.below(hunk, before: next, endingAt: 400)

        // then — seven lines, 145 through 151. Overrunning into the next hunk would splice lines
        // this file already draws, and the reader would scroll through them twice.
        #expect(window == LineWindow(side: .new, start: 145, count: 7))
    }

    @Test
    func `given a deleted file when its window is asked for then there is nothing to expand either way`() {
        // given — git reports a wholly deleted file as `@@ -1,5 +0,0 @@`: every line is in the hunk
        // already, and there is no new side for a window to be read from.
        let hunk = aHunk(oldStart: 1, oldCount: 5, newStart: 0, newCount: 0)

        // when
        let above = ContextExpansion.above(hunk, after: nil)
        let below = ContextExpansion.below(hunk, before: nil, endingAt: 0)

        // then
        #expect(above == nil)
        #expect(below == nil)
    }

    // MARK: - What the hunk becomes

    @Test
    func `given lines from above when they are spliced then the hunk starts earlier on both sides`() {
        // given — the two sides are two apart, which is what makes this worth asserting: a spliced
        // context line has to carry a number on each side, and getting the offset wrong produces a
        // gutter that is plausible and wrong.
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let expanded = ContextExpansion.expanded(hunk, above: ["import Foundation", "", "extension Api {"])

        // then
        #expect(expanded.newStart == 135)
        #expect(expanded.newCount == 10)
        #expect(expanded.oldStart == 137)
        #expect(expanded.oldCount == 9)
    }

    @Test
    func `given lines from above when they are spliced then they arrive as context in file order`() {
        // given
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let expanded = ContextExpansion.expanded(hunk, above: ["import Foundation", "", "extension Api {"])

        // then
        let spliced = Array(expanded.lines.prefix(3))
        #expect(spliced.map(\.kind) == [.context, .context, .context])
        #expect(spliced.map(\.text) == ["import Foundation", "", "extension Api {"])
        #expect(spliced.map(\.newNumber) == [135, 136, 137])
        #expect(spliced.map(\.oldNumber) == [137, 138, 139])
        // And the hunk's own lines are still behind them, unchanged.
        #expect(expanded.lines.count == hunk.lines.count + 3)
        #expect(expanded.lines.dropFirst(3).map(\.text) == hunk.lines.map(\.text))
    }

    @Test
    func `given lines from below when they are spliced then they follow the hunk's own`() {
        // given
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let expanded = ContextExpansion.expanded(hunk, below: ["    }", "}"])

        // then — the numbering carries on from where each side stopped: new 145, old 146.
        let spliced = Array(expanded.lines.suffix(2))
        #expect(spliced.map(\.newNumber) == [145, 146])
        #expect(spliced.map(\.oldNumber) == [146, 147])
        #expect(expanded.newStart == 138)
        #expect(expanded.newCount == 9)
        #expect(expanded.oldCount == 8)
    }

    @Test
    func `given a spliced line when it is measured then the columns are the same ones the Mac would send`() {
        // given — a tab and a wide character, which are the two the grid gets wrong if the client
        // counts characters. **The measurement is `Core`'s own**, which is the whole point: two
        // implementations of one Unicode judgement is a row-count error waiting for a wrap mode.
        let hunk = aHunk(oldStart: 10, oldCount: 2, newStart: 10, newCount: 2)

        // when
        let expanded = ContextExpansion.expanded(hunk, above: ["\tlet label = \"図形\""])

        // then — 22: one tab to the first stop, thirteen ASCII characters, two columns per wide
        // glyph and the closing quote. Seventeen is what counting characters would have answered,
        // so this number is also the assertion that it does not.
        #expect(expanded.lines.first?.displayColumns == 22)
        #expect(expanded.lines.first?.needsMeasurement == false)
    }

    @Test
    func `given nothing to splice when a hunk is expanded then it is handed back untouched`() {
        // given — reachable when a window is asked for at the moment the file grows underneath it,
        // and the alternative to answering is a hunk whose counts moved by zero and whose identity
        // did not.
        let hunk = aHunk(oldStart: 140, oldCount: 6, newStart: 138, newCount: 7)

        // when
        let expanded = ContextExpansion.expanded(hunk, above: [])

        // then
        #expect(expanded == hunk)
    }
}

// MARK: -

private func aHunk(oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) -> Hunk {
    Hunk(
        index: 0,
        oldStart: oldStart,
        oldCount: oldCount,
        newStart: newStart,
        newCount: newCount,
        sectionHeading: "func health() async throws(ApiFailure) -> HealthResponse",
        lines: [
            DiffLine(
                kind: .context,
                oldNumber: oldStart,
                newNumber: newStart,
                text: "    func health() {",
                displayColumns: 19,
                segments: nil
            )
        ]
    )
}
