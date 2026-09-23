import Foundation

/// The size the diff screen draws its code at, and whether two columns are available at it.
///
/// **One value rather than two computed properties on the screen**, for `DiffPaneLayout`'s own
/// reason: the second of them decides whether a control is operable, and "is this control offered,
/// and does it say why when it is not" is a question that belongs somewhere a test can ask it
/// directly rather than somewhere only a photograph can.
///
/// **The mode picks the half, and it picks it for the whole scroll.** A split block's cells and the
/// context rows around them are one grid; drawing the block at the split's size and the context at
/// the unified one would put two text sizes in one file. So *Side by Side* is what chooses between
/// the reader's two numbers, and flipping it re-lexes exactly as a theme change already does.
public struct DrawnCodeSize: Hashable, Sendable {

    /// What every row on the screen is drawn at.
    public let pointSize: CGFloat

    /// Why two columns are unavailable, and nothing where they are.
    ///
    /// **Asked at the split's size whether or not the split is on**, because the control this answers
    /// for is the one that turns it on: a reader deciding whether to press needs to know what
    /// pressing would get them, not what their current mode costs.
    public let splitRefusal: SplitRefusal?

    /// What *Follow system* asked for before the split's ceiling took it, and nothing where nothing
    /// was held back. The *Code size* screen is the only reader; the diff screen never mentions it.
    public let heldBackFrom: CGFloat?

    public init(
        codeSize: CodeSize,
        textSize: ReaderTextSize,
        fitsSelectorColumn: Bool,
        isSplit: Bool,
        rowWidth: CGFloat
    ) {
        let split = codeSize.resolvedSplit(
            at: textSize,
            besideSelector: fitsSelectorColumn,
            inRowWidth: rowWidth
        )
        let unified = codeSize.resolvedUnified(at: textSize, besideSelector: fitsSelectorColumn)
        pointSize = isSplit ? split.pointSize : unified.pointSize
        heldBackFrom = split.heldBackFrom
        splitRefusal = SplitRefusal.refusal(
            inRowWidth: rowWidth,
            atPointSize: split.pointSize,
            trailingInset: DiffGutter.codeTrailingInset
        )
    }
}
