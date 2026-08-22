import AppKit
import SnapshotTesting

/// A snapshot strategy that renders at a **pinned** pixel scale instead of the display's.
///
/// **This is the difference between a baseline and a souvenir.** The library's own `NSView` strategy
/// asks the view for `bitmapImageRepForCachingDisplay`, which takes its resolution from the window's
/// backing scale — so a Retina Mac records 1240 × 1120 for a 620 × 560pt pane and a CI runner, which
/// is headless and has no Retina display, renders the same pane at 620 × 560. Every pixel differs,
/// the diff report is two images of identical content at different sizes, and the failure says only
/// "does not match reference". The baselines were correct and could never have passed anywhere but
/// the machine that recorded them.
///
/// So the rep is built here with its pixel dimensions stated and its `size` left in points, which is
/// what makes it a 2× rep whatever the screen underneath is. Two is chosen over one because it is
/// what a reader actually sees, and because a baseline is reviewed by eye — half the resolution is
/// half of what a reviewer can catch.
///
/// The tolerances are the caller's; this type only decides the raster.
extension Snapshotting where Value == NSView, Format == NSImage {

    static func fixedScaleImage(
        scale: CGFloat = 2,
        precision: Float,
        perceptualPrecision: Float
    ) -> Snapshotting {
        SimplySnapshotting.image(precision: precision, perceptualPrecision: perceptualPrecision)
            .pullback { view in
                let bounds = view.bounds
                let rendered = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: Int(bounds.width * scale),
                    pixelsHigh: Int(bounds.height * scale),
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                )
                guard let rendered else {
                    // Unrepresentable rather than merely failed: there is no size, colour space or
                    // sample count here that AppKit can refuse, so reaching this means the pane was
                    // laid out at zero and the picture would assert nothing anyway.
                    fatalError("Could not make a \(scale)× bitmap for a view of \(bounds.size)")
                }
                // Points, not pixels. The pair — pixel dimensions above, point size here — is what
                // states the scale; setting only one of them gets the display's.
                rendered.size = bounds.size

                view.cacheDisplay(in: bounds, to: rendered)

                let image = NSImage(size: bounds.size)
                image.addRepresentation(rendered)
                return image
            }
    }
}
