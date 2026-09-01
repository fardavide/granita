import SwiftUI

/// A strip with semicircular bites taken out of one edge, which is what makes design §4's expander
/// read as a tear rather than as a band.
///
/// **Drawn rather than themed, and it is the one place in this app that is.** There is no system
/// control shaped like a page torn across, and the whole argument for the treatment is that a broken
/// edge is recognised before any label is read — a stock separator is the thing it exists not to be.
/// What it does keep from the system is everything that matters at a boundary: it is a `Shape`, so it
/// fills with whatever colour the caller resolves in the current appearance, and it scales with the
/// row rather than being an image at one size.
///
/// The bites are punched with an even-odd fill: the rectangle and the circles are both in the path,
/// so the overlap is what is left out. A mask would work and would cost a separate layer per row.
struct TornEdge: Shape {

    /// How deep the tear is. Half a bite, so a scallop meets the strip's far edge exactly and the
    /// pattern reads as a torn line rather than as a row of holes.
    static let depth: CGFloat = 5

    /// Along the row, from one bite to the next.
    static let period: CGFloat = 9

    static let radius: CGFloat = 3.5

    /// The edge the bites are taken *from*, which is the inner one — the tear faces the code it is
    /// standing between, so a row torn at the top has its bites along its top edge's underside.
    let bitesFrom: VerticalAlignment

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        // Centred on the strip's inner edge so each bite is a half circle, and started half a period
        // in so the row does not open with a clipped one.
        let y = bitesFrom == .top ? rect.maxY : rect.minY
        var x = rect.minX + Self.period / 2
        while x - Self.radius < rect.maxX {
            path.addEllipse(
                in: CGRect(
                    x: x - Self.radius,
                    y: y - Self.radius,
                    width: Self.radius * 2,
                    height: Self.radius * 2
                )
            )
            x += Self.period
        }
        return path
    }
}

/// An arrow and the lines it would reveal: three dashes on the side the content is missing from, and
/// an arrow pointing the way out of them.
///
/// **It is what let the glyph move into the gutter.** The first build put a chevron on the trailing
/// edge and argued that the leading column belongs to the line numbers, "and a glyph there reads as a
/// line number" — which is true of a chevron and is the reason this is not one. Three short rules
/// *are* line numbers, or near enough: they stand for the rows that are not being drawn, which is
/// exactly what the column is empty for.
///
/// Design §4's own drawing, at its own size. Stroked by the caller so the width and the colour are
/// stated once beside the row that uses them.
struct HiddenLines: Shape {

    enum Direction: Hashable {
        /// Arrow above the dashes: the missing lines are above, and pressing goes up into them.
        case upward
        /// Dashes above the arrow: the missing lines are below.
        case downward
    }

    static let size = CGSize(width: 13, height: 15)

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width / Self.size.width, rect.height / Self.size.height)
        let point = { (x: CGFloat, y: CGFloat) in
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        switch direction {
        case .upward:
            path.move(to: point(6.5, 8.4))
            path.addLine(to: point(6.5, 1.5))
            path.move(to: point(3.3, 4.6))
            path.addLine(to: point(6.5, 1.4))
            path.addLine(to: point(9.7, 4.6))
            addDashes(to: &path, atRows: [11.3, 13.9], point: point)
        case .downward:
            path.move(to: point(6.5, 6.6))
            path.addLine(to: point(6.5, 13.5))
            path.move(to: point(3.3, 10.4))
            path.addLine(to: point(6.5, 13.6))
            path.addLine(to: point(9.7, 10.4))
            addDashes(to: &path, atRows: [1.1, 3.7], point: point)
        }
        return path
    }

    private func addDashes(to path: inout Path, atRows rows: [CGFloat], point: (CGFloat, CGFloat) -> CGPoint) {
        for row in rows {
            for start in [1.7, 5.8, 9.8] as [CGFloat] {
                path.move(to: point(start, row))
                path.addLine(to: point(start + 1.5, row))
            }
        }
    }
}
