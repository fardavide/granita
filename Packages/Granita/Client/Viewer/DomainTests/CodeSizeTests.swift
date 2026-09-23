import Foundation
import Testing

@testable import ClientViewerDomain

/// The setting `SPEC.md` §10 has claimed since the beginning, and the arithmetic the reader is shown
/// instead of a point size.
///
/// **The numbers here are issue #106's own table**, at 390pt with a three-figure column: 61, 54, 49
/// and 45 characters unified at 9, 10, 11 and 12pt, and 28, 24, 22 and 20 a side split. They are
/// asserted rather than derived, because a table a reader is shown and a table the code computes
/// agreeing is the whole of what this type promises.
@Suite("Code size")
struct CodeSizeTests {

    // MARK: - Follow system

    @Test
    func `given the default text size when the system size is derived then it is today's two constants`() {
        // given - when — Large is the size every measurement in design §4 was taken at, so *Follow
        // system* there has to land on exactly what shipped before this setting existed.

        // then
        #expect(CodeSize.systemPointSize(at: .large, besideSelector: false) == DiffPaneLayout.codePointSize)
        #expect(
            CodeSize.systemPointSize(at: .large, besideSelector: true)
                == DiffPaneLayout.codePointSizeBesideTheSelector
        )
    }

    @Test
    func `given a text size below Large when the system size is derived then it steps down a point each`() {
        // given - when - then — one point per Dynamic Type step, which is what makes 8pt reachable
        // from the smallest of them and no smaller.
        #expect(CodeSize.systemPointSize(at: .medium, besideSelector: false) == 10)
        #expect(CodeSize.systemPointSize(at: .small, besideSelector: false) == 9)
        #expect(CodeSize.systemPointSize(at: .xSmall, besideSelector: false) == 8)
        #expect(CodeSize.systemPointSize(at: .xSmall, besideSelector: true) == 9)
    }

    @Test
    func `given an accessibility text size when the system size is derived then it stops at the largest`() {
        // given - when — Large plus eight steps is 19, which is past the range the stepper offers.

        // then — clamped rather than refused, because a reader on the largest accessibility size has
        // not asked for anything this setting should argue with.
        #expect(CodeSize.systemPointSize(at: .accessibility1, besideSelector: false) == 15)
        #expect(CodeSize.systemPointSize(at: .accessibility3, besideSelector: false) == 17)
        #expect(CodeSize.systemPointSize(at: .accessibility5, besideSelector: false) == CodeSize.largest)
        #expect(CodeSize.systemPointSize(at: .accessibility5, besideSelector: true) == CodeSize.largest)
    }

    @Test
    func `given every text size when its distance from Large is read then it is its position in the list`() {
        // given - when - then — the twelve steps are the whole of what the view layer has to map
        // `DynamicTypeSize` onto, so an added case is a compile error there rather than a silent 0.
        #expect(ReaderTextSize.allCases.count == 12)
        #expect(ReaderTextSize.large.stepsFromLarge == 0)
        #expect(ReaderTextSize.allCases.map(\.stepsFromLarge) == Array(-3...8))
    }

    // MARK: - What a point buys

    @Test
    func `given the unified scroll on a phone when its sizes are measured then they are issue 106's table`() {
        // given — 390pt of row and a three-figure column, which is the width the table is stated at.
        let characters = [9, 10, 11, 12].map { pointSize in
            DiffGutter.codeCharacters(
                inRowWidth: 390,
                highestLineNumber: SplitBlockLayout.statedHighestLineNumber,
                atPointSize: CGFloat(pointSize),
                trailingInset: DiffGutter.codeTrailingInset
            )
        }

        // when - then — about five characters a point, from a number that starts at 49.
        #expect(characters == [61, 54, 49, 45])
    }

    @Test
    func `given a split block on a phone when its sizes are measured then twelve points is the floor`() {
        // given - when
        let characters = [9, 10, 11, 12].map { pointSize in
            SplitBlockLayout.characters(
                inRowWidth: 390,
                highestLineNumber: SplitBlockLayout.statedHighestLineNumber,
                atPointSize: CGFloat(pointSize),
                trailingInset: DiffGutter.codeTrailingInset
            )
        }

        // then — about two a side a point, from a number that starts at 22, so 12pt is exactly the
        // twenty the floor is written in and 13 is below it.
        #expect(characters == [28, 24, 22, 20])
        #expect(characters.last == SplitBlockLayout.floorCharacters)
    }

    @Test
    func `given a phone's width when the largest fitting split size is asked for then it is twelve points`() {
        // given - when
        let largest = SplitBlockLayout.largestFittingPointSize(inRowWidth: 390, trailingInset: DiffGutter.codeTrailingInset)

        // then
        #expect(largest == 12)
    }

    @Test
    func `given the iPad's pane when the largest fitting split size is asked for then nothing is held back`() {
        // given - when — 846pt holds 35 characters a side even at the largest size the stepper
        // offers, so the ceiling is the range rather than the room.
        let largest = SplitBlockLayout.largestFittingPointSize(inRowWidth: 846, trailingInset: DiffGutter.codeTrailingInset)

        // then
        #expect(largest == CodeSize.largest)
    }

    @Test
    func `given a window narrower than the floor when the largest fitting split size is asked for then there is none`() {
        // given - when — 250pt of row holds seventeen characters a side at 8pt, which is below the
        // floor at every size this setting can reach.
        let largest = SplitBlockLayout.largestFittingPointSize(inRowWidth: 250, trailingInset: DiffGutter.codeTrailingInset)

        // then — nothing rather than the smallest size, because a size that still refuses is not an
        // answer the split group can offer.
        #expect(largest == nil)
    }

    // MARK: - Resolving the unified half

    @Test
    func `given the unified half when it is resolved then it is never held back`() {
        // given — a text size whose split half would be held, so the two halves are seen to differ.
        let size = CodeSize(unified: .followSystem, split: .followSystem)

        // when
        let resolved = size.resolvedUnified(at: .accessibility5, besideSelector: false)

        // then — legibility is the unified question and there is no width argument against it.
        #expect(resolved == .asChosen(CodeSize.largest))
        #expect(resolved.pointSize == CodeSize.largest)
        #expect(resolved.heldBackFrom == nil)
    }

    @Test
    func `given a custom unified size when it is resolved then the text size is ignored`() {
        // given
        let size = CodeSize(unified: .custom(9), split: .followSystem)

        // when
        let resolved = size.resolvedUnified(at: .accessibility5, besideSelector: true)

        // then — *Custom* means this number, which is the whole of what the segment says.
        #expect(resolved == .asChosen(9))
    }

    @Test
    func `given a stored size outside the range when it is resolved then it is brought back into it`() {
        // given — the one way to get here is a defaults file edited by hand or a newer build that
        // offered a wider range, and in both cases what the reader wants is a size that draws.
        let size = CodeSize(unified: .custom(40), split: .custom(1))

        // when - then
        #expect(size.resolvedUnified(at: .large, besideSelector: false).pointSize == CodeSize.largest)
        #expect(size.resolvedSplit(at: .large, besideSelector: false, inRowWidth: 390).pointSize == CodeSize.smallest)
    }

    // MARK: - Resolving the split half

    @Test
    func `given Follow system at the default text size when the split is resolved then it fits as it stands`() {
        // given
        let size = CodeSize.default

        // when
        let resolved = size.resolvedSplit(at: .large, besideSelector: false, inRowWidth: 390)

        // then — 11pt is 22 characters a side, two above the floor.
        #expect(resolved == .asChosen(11))
    }

    @Test
    func `given Follow system above the floor's size when the split is resolved then it is held at the ceiling`() {
        // given — Davide's call of 23 September 2026: the floor does not bend, and an accessibility
        // text size never takes the feature away.
        let size = CodeSize.default

        // when
        let resolved = size.resolvedSplit(at: .accessibility5, besideSelector: false, inRowWidth: 390)

        // then — 17pt was asked for and 12 is the most two columns can take at 390pt.
        #expect(resolved == .heldBack(to: 12, from: CodeSize.largest))
        #expect(resolved.pointSize == 12)
        #expect(resolved.heldBackFrom == CodeSize.largest)
    }

    @Test
    func `given Follow system on the iPad's pane when the split is resolved then nothing is held back`() {
        // given — the clamp is this device's width rather than a constant, which is what keeps a
        // reader on a wide window from being given the phone's twelve points.
        let size = CodeSize.default

        // when
        let resolved = size.resolvedSplit(at: .accessibility5, besideSelector: true, inRowWidth: 846)

        // then
        #expect(resolved == .asChosen(CodeSize.largest))
    }

    @Test
    func `given a custom split size past the ceiling when it is resolved then it is left where it was put`() {
        // given — capping the stepper was rejected as a ceiling that moves while a Mac window is
        // dragged. The reader gets the size they asked for and the toolbar item says what it costs.
        let size = CodeSize(unified: .followSystem, split: .custom(15))

        // when
        let resolved = size.resolvedSplit(at: .large, besideSelector: false, inRowWidth: 390)

        // then
        #expect(resolved == .asChosen(15))
    }

    @Test
    func `given a window below the floor at every size when the split is resolved then nothing is held back`() {
        // given — there is no size that would fit, so holding one back would be a clamp to a number
        // that refuses too.
        let size = CodeSize.default

        // when
        let resolved = size.resolvedSplit(at: .accessibility5, besideSelector: false, inRowWidth: 250)

        // then — the size stands and the toolbar item carries the width's own sentence instead.
        #expect(resolved == .asChosen(CodeSize.largest))
    }

    // MARK: - Why two columns are refused

    @Test
    func `given a window dragged under the floor when the refusal is named then it is the width`() {
        // given - when — 250pt holds eleven characters a side at 11pt and seventeen even at the
        // smallest size this setting reaches, so the room is what ran out rather than the size.
        let refusal = SplitRefusal.refusal(inRowWidth: 250, atPointSize: 11, trailingInset: DiffGutter.codeTrailingInset)

        // then
        #expect(refusal == .tooNarrow)
        #expect(refusal?.sentence == "Widen the window to review side by side")
    }

    @Test
    func `given a phone at a size past the ceiling when the refusal is named then it is the code size`() {
        // given - when — 390pt holds thirty-one characters a side at 8pt, so the width is not what
        // crossed the floor and telling a phone reader to widen a window would be a dead end.
        let refusal = SplitRefusal.refusal(inRowWidth: 390, atPointSize: 15, trailingInset: DiffGutter.codeTrailingInset)

        // then
        #expect(refusal == .codeTooLarge)
        #expect(refusal?.sentence == "Choose a smaller code size to review side by side")
    }

    @Test
    func `given a row that fits when the refusal is named then there is none`() {
        // given - when
        let refusal = SplitRefusal.refusal(inRowWidth: 390, atPointSize: 11, trailingInset: DiffGutter.codeTrailingInset)

        // then — nothing to say, and the toolbar item stays live.
        #expect(refusal == nil)
    }
}
