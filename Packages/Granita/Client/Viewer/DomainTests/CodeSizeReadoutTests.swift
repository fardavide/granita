import Foundation
import Testing

@testable import ClientViewerDomain

/// What the *Code size* screen says, which is characters rather than points.
///
/// **The numbers are issue #106's table and design §4.2's floor**, so a change to the gutter, the
/// gap or the rule moves them here rather than on a device.
@Suite("Code size readout")
struct CodeSizeReadoutTests {

    // MARK: - What each half says

    @Test
    func `given a phone at the default size when the screen is read then both halves say today's numbers`() {
        // given - when
        let readout = CodeSizeReadout(codeSize: .default, textSize: .default, fitsSelectorColumn: false, rowWidth: 390)

        // then — 11pt either way, 49 characters a line and 22 a side.
        #expect(readout.unified.pointSize == 11)
        #expect(readout.unified.characters == 49)
        #expect(readout.split.pointSize == 11)
        #expect(readout.split.characters == 22)
        #expect(readout.heldBackFrom == nil)
        #expect(readout.refusal == nil)
    }

    @Test
    func `given the two halves set apart when the screen is read then each says its own number`() {
        // given — the whole reason there are two settings: legibility unified, width split.
        let size = CodeSize(unified: .custom(14), split: .custom(10))

        // when
        let readout = CodeSizeReadout(codeSize: size, textSize: .default, fitsSelectorColumn: false, rowWidth: 390)

        // then
        #expect(readout.unified.characters == 38)
        #expect(readout.split.characters == 24)
    }

    @Test
    func `given an iPad's pane when the screen is read then it says the iPad's numbers`() {
        // given - when — 874pt is an iPad Pro 11″ in landscape less the tree.
        let readout = CodeSizeReadout(codeSize: .default, textSize: .default, fitsSelectorColumn: true, rowWidth: 874)

        // then — 12pt beside the selector, and a split cell nothing in an ordinary change set fills.
        #expect(readout.split.pointSize == 12)
        #expect(readout.split.characters == 53)
    }

    // MARK: - What the split group has to explain

    @Test
    func `given an accessibility text size on a phone when the screen is read then the hold is reported`() {
        // given - when
        let readout = CodeSizeReadout(
            codeSize: .default,
            textSize: .accessibility5,
            fitsSelectorColumn: false,
            rowWidth: 390
        )

        // then — the unified half takes the seventeen points it asked for and the split half says why
        // it did not, which is the sentence Davide's call of 23 September 2026 owes the reader.
        #expect(readout.unified.pointSize == 17)
        #expect(readout.split.pointSize == 12)
        #expect(readout.heldBackFrom == 17)
        #expect(readout.split.characters == SplitBlockLayout.floorCharacters)
        #expect(readout.refusal == nil)
    }

    @Test
    func `given a custom split size past the ceiling when the screen is read then it names the size`() {
        // given — the reader put the number there themselves, so nothing holds it back and the screen
        // says what it costs instead.
        let size = CodeSize(unified: .followSystem, split: .custom(15))

        // when
        let readout = CodeSizeReadout(codeSize: size, textSize: .default, fitsSelectorColumn: false, rowWidth: 390)

        // then
        #expect(readout.heldBackFrom == nil)
        #expect(readout.refusal == .codeTooLarge)
        #expect(readout.split.characters < SplitBlockLayout.floorCharacters)
    }

    @Test
    func `given a window under the floor when the screen is read then it names the width`() {
        // given - when
        let readout = CodeSizeReadout(codeSize: .default, textSize: .default, fitsSelectorColumn: false, rowWidth: 250)

        // then
        #expect(readout.refusal == .tooNarrow)
    }

    // MARK: - Moving between the two segments

    @Test
    func `given Follow system when Custom is chosen then the stepper opens at the size already on screen`() {
        // given — a reader whose text size has them at fifteen points. A stepper opening at eleven
        // would move their code the moment they touched the control that is about not moving it.
        let readout = CodeSizeReadout(
            codeSize: .default,
            textSize: .accessibility1,
            fitsSelectorColumn: false,
            rowWidth: 390
        )

        // when
        let chosen = readout.choosing(unified: true)

        // then — and the other half is left exactly as it was.
        #expect(chosen == CodeSize(unified: .custom(15), split: .followSystem))
    }

    @Test
    func `given the split held at the ceiling when Custom is chosen then it opens at the held size`() {
        // given — what is on screen is twelve, not the seventeen that was asked for, so that is what
        // the reader is stepping away from.
        let readout = CodeSizeReadout(
            codeSize: .default,
            textSize: .accessibility5,
            fitsSelectorColumn: false,
            rowWidth: 390
        )

        // when
        let chosen = readout.choosing(split: true)

        // then
        #expect(chosen == CodeSize(unified: .followSystem, split: .custom(12)))
    }

    @Test
    func `given a custom size when Follow system is chosen then the stored number goes`() {
        // given
        let size = CodeSize(unified: .custom(14), split: .custom(10))
        let readout = CodeSizeReadout(codeSize: size, textSize: .default, fitsSelectorColumn: false, rowWidth: 390)

        // when
        let chosen = readout.choosing(split: false)

        // then
        #expect(chosen == CodeSize(unified: .custom(14), split: .followSystem))
        #expect(readout.split.isCustom)
        #expect(readout.unified.isCustom)
    }

    @Test
    func `given Follow system when the segment is read then it is not the custom one`() {
        // given - when - then — the stepper exists only under the second segment, so this answer is
        // what decides whether a control is on the screen at all.
        let readout = CodeSizeReadout(codeSize: .default, textSize: .default, fitsSelectorColumn: false, rowWidth: 390)
        #expect(readout.unified.isCustom == false)
        #expect(readout.split.isCustom == false)
    }
}
