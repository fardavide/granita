import Foundation

/// What the *Code size* screen shows, for both halves at once.
///
/// **The readout is in characters, which is design call 11.** Points are what you set; characters
/// are what you get, and predicting a monospaced grid from a point size is arithmetic nobody should
/// be asked to do in their head. A pure numeric stepper with no sample was rejected for that; so was
/// quoting both devices' numbers, which is arithmetic about a screen that is not here.
///
/// **One value for both groups rather than one each**, because the two facts the screen has to
/// explain — that the split was held back, and that it is currently refused — belong to the pair
/// rather than to either half: what is held back is the split's size, and the reason it is worth
/// saying is that the unified half was not.
public struct CodeSizeReadout: Hashable, Sendable {

    public let unified: Half
    public let split: Half

    /// What *Follow system* asked for before the split's ceiling took it, and nothing where nothing
    /// was held back.
    public let heldBackFrom: CGFloat?

    /// Why two columns are unavailable at the split's size, and nothing where they are. The same
    /// sentence the disabled toolbar item carries, said here where the reader can act on it.
    public let refusal: SplitRefusal?

    /// **Built from the window's width rather than from the diff pane's own**, because this screen is
    /// a sheet and cannot see the pane it is describing. `WorktreeDiffScreen` measures the real thing
    /// for the decision that matters — whether its toolbar item is operable — so a point of
    /// disagreement here costs a character in a sentence and never a press.
    public init(
        codeSize: CodeSize,
        textSize: ReaderTextSize,
        fitsSelectorColumn: Bool,
        rowWidth: CGFloat
    ) {
        let unifiedPoints = codeSize.resolvedUnified(at: textSize, besideSelector: fitsSelectorColumn).pointSize
        let resolvedSplit = codeSize.resolvedSplit(
            at: textSize,
            besideSelector: fitsSelectorColumn,
            inRowWidth: rowWidth
        )
        unified = Half(
            choice: codeSize.unified,
            pointSize: unifiedPoints,
            characters: DiffGutter.codeCharacters(
                inRowWidth: rowWidth,
                highestLineNumber: SplitBlockLayout.statedHighestLineNumber,
                atPointSize: unifiedPoints,
                trailingInset: DiffGutter.codeTrailingInset
            )
        )
        split = Half(
            choice: codeSize.split,
            pointSize: resolvedSplit.pointSize,
            characters: SplitBlockLayout.characters(
                inRowWidth: rowWidth,
                highestLineNumber: SplitBlockLayout.statedHighestLineNumber,
                atPointSize: resolvedSplit.pointSize,
                trailingInset: DiffGutter.codeTrailingInset
            )
        )
        heldBackFrom = resolvedSplit.heldBackFrom
        refusal = SplitRefusal.refusal(
            inRowWidth: rowWidth,
            atPointSize: resolvedSplit.pointSize,
            trailingInset: DiffGutter.codeTrailingInset
        )
    }

    /// What the reader sees when they switch a group to *Custom*, which is the size they were
    /// already reading at.
    ///
    /// **Continuous rather than a fixed starting point.** A stepper that opened at eleven for a
    /// reader whose text size had them at fifteen would move their code the moment they touched the
    /// control that is supposed to be about *not* moving it.
    public func choosing(unified isCustom: Bool) -> CodeSize {
        CodeSize(unified: isCustom ? .custom(unified.pointSize) : .followSystem, split: split.choice)
    }

    public func choosing(split isCustom: Bool) -> CodeSize {
        CodeSize(unified: unified.choice, split: isCustom ? .custom(self.split.pointSize) : .followSystem)
    }

    // MARK: -

    /// One group's own three facts.
    public struct Half: Hashable, Sendable {

        public let choice: CodeSizeChoice
        public let pointSize: CGFloat
        public let characters: Int

        /// Whether the segmented control's second segment is the one that is on, which is also what
        /// decides whether the stepper under it exists at all.
        public var isCustom: Bool {
            if case .custom = choice { true } else { false }
        }

        public init(choice: CodeSizeChoice, pointSize: CGFloat, characters: Int) {
            self.choice = choice
            self.pointSize = pointSize
            self.characters = characters
        }
    }
}
