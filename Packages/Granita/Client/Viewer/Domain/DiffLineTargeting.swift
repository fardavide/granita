import Foundation

import CoreDiffDomain
import CoreReviewDomain

/// The current measured file layout used by every phase of a touch.
public struct DiffLineTargeting {

    public let acceptsTargeting: Bool
    private let hunks: [Hunk]
    private let frames: [Int: CGRect]
    private let pointSize: CGFloat
    private let rowHeight: CGFloat
    private let isSplit: Bool

    public init(
        hunks: [Hunk],
        frames: [Int: CGRect],
        pointSize: CGFloat,
        rowHeight: CGFloat,
        isSplit: Bool,
        acceptsTargeting: Bool
    ) {
        self.hunks = hunks
        self.frames = frames
        self.pointSize = pointSize
        self.rowHeight = rowHeight
        self.isSplit = isSplit
        self.acceptsTargeting = acceptsTargeting
    }

    public func line(at point: CGPoint) -> DiffLinePosition? {
        guard let width = frames.values.first?.size.width else { return nil }
        return GutterTarget.line(
            at: point,
            in: hunks,
            frames: frames,
            rowHeight: rowHeight,
            splitting: isSplit && SplitBlockLayout.fits(
                rowWidth: width,
                highestLineNumber: highestNumber,
                atPointSize: pointSize,
                trailingInset: DiffGutter.codeTrailingInset
            ),
            cellWidth: SplitBlockLayout.cellWidth(inRowWidth: width, trailingInset: DiffGutter.codeTrailingInset)
        )
    }

    private var highestNumber: Int {
        let lines = hunks.flatMap(\.lines)
        let highestOld = lines.compactMap(\.oldNumber).max() ?? 0
        let highestNew = lines.compactMap(\.newNumber).max() ?? 0
        return max(highestOld, highestNew)
    }
}
