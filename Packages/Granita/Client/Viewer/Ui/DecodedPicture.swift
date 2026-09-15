import CoreGraphics
import ImageIO
import SwiftUI

/// Turns the bytes a Mac sent into something SwiftUI can draw.
///
/// **ImageIO rather than `UIImage`**, and the reason is the platform list rather than taste: the
/// client builds for macOS natively now, so a `UIImage` here is a module that compiles on one of the
/// two platforms it ships to. `Image(decorative:scale:)` takes a `CGImage` on both.
///
/// **Subsampled to the size it will be drawn at.** A re-recorded iPad baseline is 2,048 points on its
/// long edge and the card draws it at about 170; decoding the full raster to do that is twelve
/// megabytes of pixels per frame, per card, held for as long as the scroll keeps the row alive.
/// ImageIO reads the header, picks a whole-number subsampling factor and decodes once — which is why
/// this asks for a thumbnail even at full screen, where the ceiling is simply the screen.
enum DecodedPicture {

    /// The picture, or nothing at all when the bytes are not one.
    ///
    /// **Nothing rather than a placeholder**, because the caller has somewhere to say so: a `.png`
    /// holding something else is a card printing a sentence, not a decoder inventing a grey square.
    ///
    /// **One failure path rather than two**, and that is why it is a `flatMap`. Written as a `guard`
    /// over the source and a `return` over the thumbnail, the first arm is one no bytes reach:
    /// `CGImageSourceCreateWithData` answers with a source for anything at all — it is the *decode*
    /// that refuses — so it would be a region nothing could ever cover, and a claim about behaviour
    /// that does not happen.
    static func from(_ data: Data, fittingWithin edge: CGFloat, scale: CGFloat) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { source in
            CGImageSourceCreateThumbnailAtIndex(source, 0, [
                // Always, rather than only when one is embedded: a PNG has no embedded thumbnail,
                // which is every screenshot this feature exists for, and without this the call
                // answers nil for a picture that decodes perfectly.
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, edge * scale),
                // A camera roll picture carries an orientation and a screenshot does not; honouring
                // it costs nothing and its absence is a photograph on its side.
                kCGImageSourceCreateThumbnailWithTransform: true
            ] as CFDictionary)
        }
    }
}
