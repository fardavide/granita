import AppKit
import CoreImage
import SwiftUI

/// A pairing link, as the thing a camera can read.
///
/// CoreImage rather than a fourth dependency: `CIQRCodeGenerator` is a system filter, and turning a
/// value into pixels for rendering is `Ui` work in the same sense that turning source into an
/// attributed string is. Nothing here decides anything — the link is the contract and this is a
/// picture of it.
struct PairingQrCode: View {

    /// Points per module, and the reason the QR is not simply given a frame.
    ///
    /// Four is what scans from arm's length across a desk. Sizing from the module count rather than
    /// to a fixed square is what keeps every module the same width: a 53-module code squeezed into a
    /// 240pt box would put some modules at four points and others at five, which is exactly the
    /// unevenness a scanner reads as noise. Design §5 gives the resulting size as a range — 236 to
    /// 244pt — for that reason.
    static let pointsPerModule: CGFloat = 4

    /// Eight, so that the rendered bitmap is an exact 2× of the drawn size and an exact 2:1
    /// downsample at 1×. Any other factor makes nearest-neighbour sampling drop or double module
    /// rows, and interpolating instead blurs the edges the scanner is looking for.
    private static let pixelsPerModule: CGFloat = 8

    let payload: String

    var body: some View {
        if let code = Self.image(of: payload) {
            Image(nsImage: code)
                .interpolation(.none)
                // White under it whatever the appearance, and that is functional rather than
                // decorative: a QR inverted for dark mode is a QR most scanners will not read, and
                // this is the one surface where the reader is holding a camera up to the screen.
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityLabel("Pairing code, as a QR code")
        } else {
            // Reachable only if the system filter is gone, which is not a state this app can
            // produce — and it still says something, because a blank square where a QR should be
            // reads as an app that is broken rather than as one telling you what to do instead.
            Text("This Mac cannot draw a QR code. Type the words below instead.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 240)
        }
    }

    /// The picture, at its natural size in points and at twice that in pixels.
    ///
    /// Error correction M is what SPEC §8's payload was sized against: about 140 bytes once the
    /// digest is percent-encoded, which in byte mode at M is a code of 49 to 53 modules.
    private static func image(of payload: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let modules = filter.outputImage else { return nil }

        let scaled = modules.transformed(by: CGAffineTransform(scaleX: pixelsPerModule, y: pixelsPerModule))
        guard let rendered = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }

        // Pixel dimensions come from the `CGImage`; the size below is in points. The pair is what
        // states the scale, exactly as the snapshot strategy's bitmap does.
        return NSImage(
            cgImage: rendered,
            size: CGSize(
                width: modules.extent.width * pointsPerModule,
                height: modules.extent.height * pointsPerModule
            )
        )
    }
}
