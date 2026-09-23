import Foundation

/// How wide the two cells of a block are, and the one width below which there are no cells at all.
///
/// **Stated in characters rather than in devices, which is design §4.2's call 7.** A floor written as
/// "the iPad and above" would make a 500pt Mac window refuse a layout it has the room for, and would
/// have to be re-decided the first time a phone changed size. Twenty characters a side is the floor,
/// and every screen is measured against it by the same arithmetic.
///
/// The iPhone at 390pt with a three-figure column reaches 22, which puts it about 32pt above the
/// floor — the measurement that decides whether this feature exists on the phone at all. The iPad's
/// 846pt pane at 12pt reaches 51, and the Mac Client is the iPad's layout at whatever the window
/// gives it.
public enum SplitBlockLayout {

    /// Between a cell and the rule, on each side of it.
    public static let gap: CGFloat = 8

    /// The hairline between the two cells, and the only thing that says the block continues past an
    /// empty one.
    public static let ruleWidth: CGFloat = 1

    /// **Twenty characters a side, and the toolbar item goes below it.** Not a device, not a size
    /// class, and not the iPad's pane width — a number the reader could in principle count.
    public static let floorCharacters = 20

    /// The figure count every stated number in the design and in the *Code size* screen is taken at.
    ///
    /// **A file's own column is sized from its own highest line number**, so a thousand-line file
    /// pays a fourth figure and loses a character — 21 a side rather than 22 at 11pt. The screen
    /// cannot state a number per file, and the ordinary file in this product is under a thousand
    /// lines, so three figures is what it quotes and `DiffFileLines` remains the authority on what is
    /// actually drawn.
    public static let statedHighestLineNumber = 999

    /// One cell's whole width, figures included.
    ///
    /// The two cells share what is left after the rule, its two gaps and the same trailing inset the
    /// unified row already ends on — so a block and the context above it stop at the same place.
    public static func cellWidth(inRowWidth rowWidth: CGFloat, trailingInset: CGFloat) -> CGFloat {
        max(0, (rowWidth - trailingInset - 2 * gap - ruleWidth) / 2)
    }

    /// What is left of a cell once its own figure column is taken out, which is where the code goes.
    ///
    /// **Each cell carries its own figures, which is design §4.3's call 3.** One shared column cannot
    /// say which side it numbers on the rows where the two differ, and those are most of the rows in
    /// a block. What goes instead is the `+`/`−` marker: inside a block every left row is a deletion
    /// and every right row an addition, so the glyph is 18pt restating the column it is standing in.
    public static func codeWidth(
        inCellWidth cellWidth: CGFloat,
        highestLineNumber highest: Int,
        atPointSize pointSize: CGFloat
    ) -> CGFloat {
        max(0, cellWidth - DiffGutter.columnWidth(forHighestLineNumber: highest, atPointSize: pointSize))
    }

    /// How many characters of code one cell shows, which is the number the floor is written in.
    public static func characters(
        inRowWidth rowWidth: CGFloat,
        highestLineNumber highest: Int,
        atPointSize pointSize: CGFloat,
        trailingInset: CGFloat
    ) -> Int {
        let cell = cellWidth(inRowWidth: rowWidth, trailingInset: trailingInset)
        let code = codeWidth(inCellWidth: cell, highestLineNumber: highest, atPointSize: pointSize)
        return Int(code / DiffGutter.advanceWidth(atPointSize: pointSize))
    }

    /// Whether this row is wide enough to draw a block in at all.
    ///
    /// Below it every block draws unified and the control that asked for them goes disabled carrying
    /// its reason — `SPEC.md`'s third permitted state for a control, and the one that re-enables
    /// itself on the drag back. A width that simply drew narrower cells would reach a column too
    /// narrow to hold the start of a line, which is the only thing a cell is for.
    public static func fits(
        rowWidth: CGFloat,
        highestLineNumber highest: Int,
        atPointSize pointSize: CGFloat,
        trailingInset: CGFloat
    ) -> Bool {
        characters(
            inRowWidth: rowWidth,
            highestLineNumber: highest,
            atPointSize: pointSize,
            trailingInset: trailingInset
        ) >= floorCharacters
    }

    /// The largest size in the settable range at which a block still clears the floor, or nothing
    /// where no size in it does.
    ///
    /// **Nothing rather than the smallest size**, and the difference is what the split group says: a
    /// width that refuses two columns at 8pt refuses them at every size this setting can reach, so
    /// holding *Follow system* back would clamp to a number that also draws nothing. That row is the
    /// width's to answer, not the size's.
    ///
    /// Whole points, because the stepper offers whole points — a ceiling of 12.4 is a number the
    /// reader cannot choose and would be shown as one they can.
    public static func largestFittingPointSize(inRowWidth rowWidth: CGFloat, trailingInset: CGFloat) -> CGFloat? {
        stride(from: CodeSize.largest, through: CodeSize.smallest, by: -1).first { points in
            fits(
                rowWidth: rowWidth,
                highestLineNumber: statedHighestLineNumber,
                atPointSize: points,
                trailingInset: trailingInset
            )
        }
    }
}
