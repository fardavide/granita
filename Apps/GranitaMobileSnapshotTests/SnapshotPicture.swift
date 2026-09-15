import CoreDiffDomain
import Foundation
import UIKit

/// Two pictures a baseline can tell apart from across the room.
///
/// **Drawn rather than committed as a fixture**, which keeps the diff corpus out of this and keeps
/// the two sides honestly different: the whole claim a card makes is that these are two versions of
/// one screenshot, so a suite that photographed the same bytes twice would pass while the card drew
/// one picture in both frames.
///
/// **Flat fills and one rectangle**, because these go through the image-comparison pipeline twice —
/// once as ImageIO subsamples them for the card and once as the snapshot raster is compared — and
/// anything with a gradient or an edge in it would spend the drift budget on the fixture rather than
/// on the layout under test.
enum SnapshotPicture {

    /// The pixel size of both sides, which is a phone screenshot's aspect rather than a square: a
    /// square picture in a 220pt frame says nothing about how a tall one letterboxes, and a tall one
    /// is what a screenshot test produces.
    static let size = CGSize(width: 240, height: 480)

    static func bytes(for side: DiffSide) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size, format: opaqueFormat)
        return renderer.pngData { context in
            // **Fixed greys rather than the semantic ones, and that is not a style slip.** A dynamic
            // `UIColor` resolves against whatever trait collection is current when it is *drawn*,
            // and these are drawn once, lazily, by whichever render reaches the fixture first — so
            // the light baselines came out holding near-black pictures because a dark render had got
            // there first. A fixture whose colour depends on the order the suite ran in is a
            // baseline that cannot be trusted whether it passes or not.
            //
            // The committed side is the paler of the two, so *before* reads as the faded one at a
            // glance and the direction of the comparison is never in doubt.
            UIColor(white: side == .old ? 0.82 : 0.58, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // The one thing that moved between the two versions, which is what a screenshot test's
            // diff usually amounts to.
            UIColor(red: 0.16, green: 0.5, blue: 0.9, alpha: 1).setFill()
            context.fill(CGRect(
                x: 40,
                y: side == .old ? 80 : 260,
                width: size.width - 80,
                height: 140
            ))
        }
    }

    /// Bytes that claim to be a PNG and are not, for the frame that says so.
    ///
    /// A real possibility rather than a contrivance: the Mac hands over whatever is on disk, and a
    /// build script that wrote an error message into an asset path produces exactly this.
    static let undecodable = Data("not a picture".utf8)

    /// **Opaque and at scale 1**, so the raster is the same on a phone and on an iPad. A scale taken
    /// from the device would make the same fixture two different pictures, which is two baselines
    /// disagreeing about a fixture rather than about a layout.
    private static var opaqueFormat: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        format.scale = 1
        return format
    }
}
