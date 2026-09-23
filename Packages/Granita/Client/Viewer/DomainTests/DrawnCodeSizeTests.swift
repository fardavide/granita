import Foundation
import Testing

@testable import ClientViewerDomain

/// Which of the reader's two sizes is on screen, and whether the control that swaps them is
/// operable.
///
/// **The two `codePointSize` answers this replaces used to live on `DiffPaneLayout`**, where they
/// were a fact about the room. They are a fact about a setting now, and the second answer here
/// decides whether a toolbar item can be pressed — which is the class of question this project has
/// shipped wrong before.
@Suite("Drawn code size")
struct DrawnCodeSizeTests {

    // MARK: - Which half is on screen

    @Test
    func `given the unified scroll on a phone when the code is measured then it is today's smaller size`() {
        // given - when
        let drawn = DrawnCodeSize(
            codeSize: .default,
            textSize: .default,
            fitsSelectorColumn: false,
            isSplit: false,
            rowWidth: 390
        )

        // then — 11pt, which is what shipped before this setting existed.
        #expect(drawn.pointSize == DiffPaneLayout.codePointSize)
    }

    @Test
    func `given a pane beside the column when the code is measured then it is one point larger`() {
        // given — the review's iPad measurement: an 846pt pane holds about 110 characters at 12pt.
        // when
        let drawn = DrawnCodeSize(
            codeSize: .default,
            textSize: .default,
            fitsSelectorColumn: true,
            isSplit: false,
            rowWidth: 846
        )

        // then
        #expect(drawn.pointSize == DiffPaneLayout.codePointSizeBesideTheSelector)
        #expect(DiffPaneLayout.codePointSizeBesideTheSelector > DiffPaneLayout.codePointSize)
    }

    @Test
    func `given the two halves differ when the mode is flipped then the size on screen flips with it`() {
        // given — **the whole scroll takes the split's size, not the block rows alone.** Context
        // drawn at one size beside a block drawn at another is two text sizes in one file.
        let size = CodeSize(unified: .custom(14), split: .custom(9))

        // when
        let unified = DrawnCodeSize(codeSize: size, textSize: .default, fitsSelectorColumn: false, isSplit: false, rowWidth: 390)
        let split = DrawnCodeSize(codeSize: size, textSize: .default, fitsSelectorColumn: false, isSplit: true, rowWidth: 390)

        // then
        #expect(unified.pointSize == 14)
        #expect(split.pointSize == 9)
    }

    @Test
    func `given Follow system past the ceiling when the mode is off then the held size is still reported`() {
        // given — the reader is reading unified at seventeen points and has not pressed anything.
        // when
        let drawn = DrawnCodeSize(
            codeSize: .default,
            textSize: .accessibility5,
            fitsSelectorColumn: false,
            isSplit: false,
            rowWidth: 390
        )

        // then — the unified scroll is unclamped, and what the split *would* be is what the screen
        // has to explain rather than what it is currently drawing.
        #expect(drawn.pointSize == CodeSize.largest)
        #expect(drawn.heldBackFrom == CodeSize.largest)
    }

    // MARK: - Whether two columns can be had

    @Test
    func `given a phone at the default size when the split is asked about then it is available`() {
        // given - when
        let drawn = DrawnCodeSize(codeSize: .default, textSize: .default, fitsSelectorColumn: false, isSplit: false, rowWidth: 390)

        // then — 11pt is 22 characters a side, two above the floor.
        #expect(drawn.splitRefusal == nil)
    }

    @Test
    func `given a custom split size past the ceiling when the split is asked about then the size is blamed`() {
        // given — the state the code-size setting made reachable on a phone for the first time, and
        // the reason *Widen the window* could not be the only sentence: a phone has no widening.
        let size = CodeSize(unified: .followSystem, split: .custom(15))

        // when
        let drawn = DrawnCodeSize(codeSize: size, textSize: .default, fitsSelectorColumn: false, isSplit: false, rowWidth: 390)

        // then
        #expect(drawn.splitRefusal == .codeTooLarge)
    }

    @Test
    func `given a window dragged under the floor when the split is asked about then the width is blamed`() {
        // given - when — a Mac window at 250pt, which holds seventeen characters a side even at the
        // smallest size this setting reaches.
        let drawn = DrawnCodeSize(codeSize: .default, textSize: .default, fitsSelectorColumn: false, isSplit: false, rowWidth: 250)

        // then
        #expect(drawn.splitRefusal == .tooNarrow)
    }

    @Test
    func `given Follow system at an accessibility size when the split is asked about then it is still available`() {
        // given — Davide's call of 23 September 2026 seen from the control's end: holding the split
        // at the ceiling is what keeps an accessibility text size from taking the feature away.
        // when
        let drawn = DrawnCodeSize(
            codeSize: .default,
            textSize: .accessibility5,
            fitsSelectorColumn: false,
            isSplit: true,
            rowWidth: 390
        )

        // then — twelve points on screen and an operable toolbar item, where an unclamped seventeen
        // would have given neither.
        #expect(drawn.pointSize == 12)
        #expect(drawn.splitRefusal == nil)
    }

    @Test
    func `given no width reported yet when the split is asked about then nothing is refused`() {
        // given - when — the first body, before its geometry has been reported back.
        let drawn = DrawnCodeSize(codeSize: .default, textSize: .default, fitsSelectorColumn: false, isSplit: false, rowWidth: 0)

        // then — a control disabled by a measurement that has not happened yet blinks off and on
        // every time the screen appears.
        #expect(drawn.splitRefusal == nil)
    }
}
