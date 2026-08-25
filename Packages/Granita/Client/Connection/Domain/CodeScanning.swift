import CorePairingDomain

/// The camera, as far as pairing is concerned: a run of the things it made out, and a way to stop
/// it.
///
/// **It hands up what a read amounted to rather than the text that was read**, which is the one
/// choice in this seam worth arguing about. `PairingLink.scanned` is a pure function in `Core` and
/// could be called from anywhere; keeping it below this line means a stranger's QR — a Wi-Fi code on
/// a poster, a URL on the back of a laptop — never leaves the layer that saw it. Design §5 asks the
/// screen never to read a foreign code back to the reader, and a seam carrying strings would leave
/// that a promise instead of a shape.
///
/// A stream rather than a one-shot, because a viewfinder reads several times a second and most of
/// what it finds is not ours: the screen throttles what it says about that, and it cannot throttle
/// what it is never told.
///
/// **What this cannot say is that the camera never opened**, and that is deliberate rather than
/// overlooked: design §5 draws no state for it — on a phone whose reader granted access, the camera
/// works — so a stream that ends without a code is the whole of what a caller learns. If a device
/// ever proves otherwise, the answer is a state in that section before it is a case here.
public protocol CodeScanning: Sendable {

    /// Begins reading, and reports every machine-readable code the camera makes out until it is
    /// stopped — ours, ours and broken, and everybody else's alike.
    func start() -> AsyncStream<ScannedCode>

    /// Stops the camera and ends the run.
    ///
    /// Called when a code is found, because design §5 freezes the frame the instant one is — the
    /// stopped session is the only acknowledgement the reader gets that the phone saw anything —
    /// and again when the screen goes away. So it has to survive being called twice, and being
    /// called before anything was started.
    func stop()
}
