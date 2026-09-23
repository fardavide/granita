import ClientSettingsUi
import ClientViewerDomain
import SwiftUI
import Testing

/// The two halves of the code size, in every state the screen can be in.
///
/// **Five subjects, and three of them exist for a sentence.** The screen's arithmetic is unit-tested
/// to the character; what only a raster holds is whether the sentence the arithmetic produces is on
/// screen at all — the held-back explanation and both refusals are `if let`s in a footer, and a
/// footer that silently drew nothing would pass every test in `CodeSizeReadoutTests`.
///
/// **The stepper's presence is the fourth thing they hold.** It is absent under *Follow system*
/// rather than disabled, which is a structural difference a photograph can see and an assertion on
/// the readout cannot.
@Suite("Code size", .serialized)
@MainActor
struct CodeSizeViewSnapshotTests {

    @Test(arguments: CodeSizeCase.all, SnapshotLayout.all)
    func `given a code size state when it renders then it matches its baseline`(
        subject: CodeSizeCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            NavigationStack {
                CodeSizeView(
                    readout: CodeSizeReadout(
                        codeSize: subject.codeSize,
                        textSize: subject.textSize,
                        fitsSelectorColumn: layout.isRegularWidth,
                        // Stated by the subject where it is the subject, and the layout's own
                        // otherwise: a Mac window dragged under the floor is a width rather than a
                        // device, and there is no layout in this suite that is one.
                        rowWidth: subject.rowWidth ?? layout.diffRowWidth
                    ),
                    onChoose: { _ in }
                )
            },
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct CodeSizeCase: Sendable, CustomTestStringConvertible {

    let name: String
    var codeSize: CodeSize = .default
    var textSize: ReaderTextSize = .default

    /// A width the subject is about rather than the layout's, for the one state no device in this
    /// suite can produce.
    var rowWidth: CGFloat?

    var testDescription: String { name }

    static let all: [CodeSizeCase] = [
        // **What a reader who has never opened this screen sees**: both segments on *Follow system*,
        // no steppers, and two counts that are today's numbers.
        CodeSizeCase(name: "following-the-system"),

        // Both halves on *Custom*, which is the only subject with two steppers in it — and the one
        // that shows the halves set apart, which is the whole argument for there being two.
        CodeSizeCase(
            name: "two-sizes-of-their-own",
            codeSize: CodeSize(unified: .custom(14), split: .custom(10))
        ),

        // **The sentence Davide's call of 23 September 2026 owes the reader.** At the largest
        // accessibility size the unified half takes seventeen points and the split half is held at
        // the ceiling, and the footer has to say which number is which.
        CodeSizeCase(name: "held-at-the-ceiling", textSize: .accessibility5),

        // **The refusal a phone can reach and a Mac window cannot fix.** Fifteen points is fifteen
        // characters a side at 390pt, so the columns are gone and the lever is the stepper on this
        // screen rather than a window edge.
        CodeSizeCase(
            name: "the-size-closed-the-columns",
            codeSize: CodeSize(unified: .followSystem, split: .custom(15))
        ),

        // **The refusal design §4.2 drew**, which needs a width rather than a device: a Mac window
        // dragged to 250pt holds seventeen characters a side even at the smallest size this screen
        // offers, so nothing the reader does here brings the columns back.
        CodeSizeCase(name: "the-window-closed-the-columns", rowWidth: 250)
    ]
}
