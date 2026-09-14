import AVFoundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// The live camera, as a view.
///
/// **The only thing in this app that draws a capture session, and it draws one it did not make.** A
/// preview layer is a window onto a session rather than a source of one, so the session arrives from
/// outside: the composition root is the one place allowed to see both the scanner that owns it and
/// the screen that shows it. That separation is also what lets the viewfinder be photographed on a
/// machine with no camera — the screen above takes any view at all, and a baseline hands it a still.
///
/// **The black rectangle used to be the macOS answer, and issue #73 made that a defect rather than a
/// fallback.** It stood for *the Mac app does not link this module*; the Client has a Mac destination
/// now, and design §5 orders the camera first, so the primary way into this product was a screen that
/// drew nothing and never said why. AVFoundation's preview layer is the same class on both platforms;
/// what differs is which representable protocol wraps it, and where the layer is allowed to come from
/// — UIKit takes it as the view's `layerClass`, AppKit has to be given one and told to want it.
///
/// The final `#else` keeps the rectangle for a host with neither framework, which is the one case the
/// original sentence still describes.
public struct CameraPreviewView: View {

    private let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public var body: some View {
        #if canImport(AppKit) || canImport(UIKit)
        CameraPreviewLayer(session: session)
        #else
        Color.black
        #endif
    }
}

// MARK: -

#if canImport(AppKit)
/// `AVCaptureVideoPreviewLayer`, wrapped so SwiftUI can lay it out.
private struct CameraPreviewLayer: NSViewRepresentable {

    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        // Filled rather than fitted, the same as the phone's: the reader is aiming, and a letterboxed
        // preview would mean the code they can see is not the whole of what the camera is reading.
        preview.videoGravity = .resizeAspectFill
        let view = NSView()
        // Layer-backed by hand, which a plain `NSView` is not: on AppKit a view has no layer until it
        // is asked for one, and `layer` stays nil — so the preview would be attached to nothing and
        // the viewfinder would be the same empty rectangle this file exists to stop drawing.
        view.wantsLayer = true
        view.layer = preview
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
}
#elseif canImport(UIKit)
/// `AVCaptureVideoPreviewLayer`, wrapped so SwiftUI can lay it out.
private struct CameraPreviewLayer: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUiView {
        let view = CameraPreviewUiView()
        view.show(session)
        return view
    }

    func updateUIView(_ view: CameraPreviewUiView, context: Context) {
        view.show(session)
    }
}

/// A view whose *backing* layer is the preview layer.
///
/// Backing rather than a sublayer, so the image follows the view's bounds for free — through
/// rotation, and through the safe-area inset the screen puts a button in. A sublayer added by hand
/// has to be resized in `layoutSubviews`, and what it shows in the meantime is a frame behind the
/// one the reader is aiming with.
private final class CameraPreviewUiView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    /// The cast cannot fail — `layerClass` above is what the layer was made from — so the guard is
    /// here in place of the force this project does not allow rather than for a case that happens.
    func show(_ session: AVCaptureSession) {
        guard let preview = layer as? AVCaptureVideoPreviewLayer else { return }
        preview.session = session
        // Filled rather than fitted: the reader is aiming, and a letterboxed preview would mean the
        // code they can see is not the whole of what the camera is reading.
        preview.videoGravity = .resizeAspectFill
    }
}
#endif
