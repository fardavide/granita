import Foundation

import CoreDiffDomain

/// Which row a thumb on the gutter meant.
///
/// **The gutter is a coordinate, not a column of controls, and that distinction is design §7's whole
/// answer to the 44pt rule.** A row is 18pt tall at the smallest code size a reader can choose, which
/// is under the minimum this project treats as a defect — but the minimum governs *discrete* targets,
/// things with a boundary you have to land inside, where a miss produces nothing. One recogniser over
/// the whole strip is the other kind: it has no boundaries, no dead space, and no way to fail. A miss
/// cannot produce nothing; it can only land one row off, and the composer's own range control makes
/// that one tap to fix, at full size, after the aim rather than during it.
///
/// It is also the only version that costs nothing at render time. Forty-two gesture recognisers per
/// screen inside a lazy stack is a scrolling problem; one is not. And a 44pt `contentShape` per row
/// — the obvious alternative — overhangs its neighbours by 13pt on each side, so three targets claim
/// the same point and the winner is decided by z-order. This gives the same forgiveness with a
/// defined answer.
///
/// **Recorded as a departure**: `SPEC.md` treats a control under 44pt as a defect with no exception,
/// and until Davide writes that exception the spec wins. See `.claude/docs/decisions.md`.
public enum GutterTarget {

    /// The row a touch at `y` points at, or nothing when no row there can carry a comment.
    ///
    /// **It clamps rather than refusing at either end.** A strip is laid out to the point and a thumb
    /// is not; refusing outside the content would make the first and last rows of every hunk harder
    /// to hit than the ones between them, which is the opposite of what a continuous target is for.
    ///
    /// **A row the gutter draws no figure for is skipped**, resolved instead to whichever numbered
    /// centre is nearer — the row above on a tie, so two taps in one place cannot answer differently.
    /// That is `\ No newline at end of file`, the one row that is not a line of the file: it can sit
    /// inside a commented run and can never be an end of one, which is the same rule `CommentAnchor`
    /// enforces from the other side.
    public static func row(at y: CGFloat, of lines: [DiffLine], rowHeight: CGFloat) -> Int? {
        guard lines.isEmpty == false, rowHeight > 0 else { return nil }
        let landed = min(lines.count - 1, max(0, Int((y / rowHeight).rounded(.down))))
        guard DiffGutter.number(of: lines[landed]) == nil else { return landed }
        return nearestNumbered(to: y, of: lines, rowHeight: rowHeight)
    }

    /// The numbered row whose centre is closest to the touch, preferring the earlier one when two are
    /// equally close.
    private static func nearestNumbered(to y: CGFloat, of lines: [DiffLine], rowHeight: CGFloat) -> Int? {
        var nearest: Int?
        var shortest = CGFloat.infinity
        for (index, line) in lines.enumerated() where DiffGutter.number(of: line) != nil {
            let distance = abs(y - (CGFloat(index) + 0.5) * rowHeight)
            if distance < shortest {
                shortest = distance
                nearest = index
            }
        }
        return nearest
    }
}
