import Foundation
import Testing

@testable import ClientViewerDomain

/// The block's own arithmetic, which is design §4.2's floor and the numbers every frame was drawn
/// against.
///
/// **The floor is the subject here, not the cell width.** A cell that is merely narrow is the
/// feature working; a cell too narrow to hold the start of a line is the feature pretending to. So
/// these assert the three widths the design names — the phone, the iPad's pane, a Mac window dragged
/// under it — against the one number that decides between them.
@Suite("Split block layout")
struct SplitBlockLayoutTests {

    // MARK: - The three widths the design was drawn against

    @Test
    func `given an iPhone at 390pt when a block is measured then each cell holds 22 characters`() {
        // given - when — 11pt code and a three-figure column, which is design §4.1's own arithmetic:
        // 4pt of inset, 19.8 of figures, 9 of trailing space and 148 of code in each 181pt cell.
        let characters = SplitBlockLayout.characters(
            inRowWidth: 390,
            highestLineNumber: 999,
            atPointSize: 11,
            trailingInset: 12
        )

        // then — one character less than the brief's most generous split case, and it keeps both
        // line numbers rather than throwing away what a comment anchors to.
        #expect(characters == 22)
        #expect(SplitBlockLayout.cellWidth(inRowWidth: 390, trailingInset: 12) == 180.5)
    }

    @Test
    func `given a four figure file on the phone when a block is measured then it loses one character`() {
        // given - when — the column is sized from the file's own highest number, so a thousand-line
        // file pays a figure for it.
        let characters = SplitBlockLayout.characters(
            inRowWidth: 390,
            highestLineNumber: 1_240,
            atPointSize: 11,
            trailingInset: 12
        )

        // then — 21, and still above the floor.
        #expect(characters == 21)
        #expect(SplitBlockLayout.fits(rowWidth: 390, highestLineNumber: 1_240, atPointSize: 11, trailingInset: 12))
    }

    @Test
    func `given the iPad's pane at 846pt when a block is measured then each cell holds 51 characters`() {
        // given - when — 12pt code beside the selector column, which is the brief's own number.
        let characters = SplitBlockLayout.characters(
            inRowWidth: 846,
            highestLineNumber: 999,
            atPointSize: 12,
            trailingInset: 12
        )

        // then
        #expect(characters == 51)
    }

    // MARK: - The floor

    @Test
    func `given a Mac window dragged below the floor when a block is measured then it does not fit`() {
        // given — 340pt of row, which design §4.2 draws as the state where every block closes and the
        // toolbar item goes disabled carrying its reason.
        let fits = SplitBlockLayout.fits(
            rowWidth: 340,
            highestLineNumber: 999,
            atPointSize: 11,
            trailingInset: 12
        )

        // then
        #expect(fits == false)
    }

    @Test
    func `given the narrowest row that still fits when it is measured then it is 20 characters`() {
        // given — the floor stated in the unit the rule is written in, so a change to the gap or the
        // rule moves this number and is noticed here rather than on a device.
        //
        // **358.6 rather than design §4.2's 358**, and the difference is a rounding rather than a
        // disagreement: 20 characters of code is 132pt, which with a 32.8pt figure column makes a
        // 164.8pt cell and a 358.6pt row. The count is truncated rather than rounded because a cell
        // showing nineteen characters and most of a twentieth shows nineteen — the last one is
        // clipped, and a floor that counts it is a floor that is one character generous.
        let rowWidth: CGFloat = 358.6

        // when
        let characters = SplitBlockLayout.characters(
            inRowWidth: rowWidth,
            highestLineNumber: 999,
            atPointSize: 11,
            trailingInset: 12
        )

        // then — and the phone at 390 sits above it, which is the measurement that decides whether
        // this feature exists on the phone at all.
        #expect(characters == SplitBlockLayout.floorCharacters)
        #expect(SplitBlockLayout.fits(rowWidth: rowWidth, highestLineNumber: 999, atPointSize: 11, trailingInset: 12))
        #expect(SplitBlockLayout.fits(rowWidth: 358, highestLineNumber: 999, atPointSize: 11, trailingInset: 12) == false)
    }

    @Test
    func `given a row with no width at all when a block is measured then nothing goes negative`() {
        // given — the first layout pass, before any geometry has been reported. A negative frame
        // traps in SwiftUI rather than drawing small.
        let cell = SplitBlockLayout.cellWidth(inRowWidth: 0, trailingInset: 12)

        // when - then
        #expect(cell == 0)
        #expect(SplitBlockLayout.codeWidth(inCellWidth: cell, highestLineNumber: 999, atPointSize: 11) == 0)
        #expect(SplitBlockLayout.fits(rowWidth: 0, highestLineNumber: 999, atPointSize: 11, trailingInset: 12) == false)
    }
}
