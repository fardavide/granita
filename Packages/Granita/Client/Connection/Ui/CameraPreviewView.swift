import AVFoundation
import SwiftUI
#if canImport(UIKit)
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
/// Off the phone it is a black rectangle. The package compiles for the host so `make test` can run
/// there, and on that side of the `#if` there is no UIKit and no camera; the Mac app does not link
/// this module.
public struct CameraPreviewView: View {

    private let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public var body: some View {
        #if canImport(UIKit)
        CameraPreviewLayer(session: session)
        #else
        Color.black
        #endif
    }
}

// MARK: -

#if canImport(UIKit)
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
