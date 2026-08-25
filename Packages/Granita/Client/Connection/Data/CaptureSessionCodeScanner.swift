import AVFoundation
import Dispatch
import Synchronization

import ClientConnectionDomain
import CorePairingDomain

/// A real `AVCaptureSession` with one metadata output on it, reading QR codes and nothing else.
///
/// **Not one line of this can be run on a build machine, and that is the whole of what it is.**
/// Opening a camera is a privacy-checked act: an unsigned test binary has no grant to check, and a
/// process whose bundle carries no usage description is terminated for asking rather than refused.
/// So it sits behind `CodeScanning` for the reason the Keychain store sits behind its own protocol,
/// and everything downstream is tested against a fake. The bar is the same: unrunnable by
/// construction, never merely untested.
///
/// The one thing here that *is* decidable was taken out rather than left in — `MachineReadableCode`
/// next door — precisely so that saying this file cannot be measured hides nothing that could be.
/// What remains is session plumbing and a delegate that passes each object through that function.
///
/// **The live preview is not drawn here**, but the session it draws is offered here, because a
/// viewfinder is a layer over a session and only the composition root may see both this and the
/// screen. That is the join this file's earlier note said would arrive when the screen did.
public final class CaptureSessionCodeScanner: CodeScanning {

    /// The one queue every AVFoundation call in this file runs on, the metadata callbacks included.
    /// Configuring and starting a session block, so neither may happen on the main actor — and a
    /// serial queue is also what makes `Capture` safe to hand between them.
    private static let queue = DispatchQueue(label: "granita.pairing.scanner")

    /// The session a viewfinder draws.
    ///
    /// **Made once here and never replaced**, which is the whole reason it is a property rather
    /// than a local in `start`. A preview layer follows a session *object*: one swapped underneath
    /// it goes black and stays black, and the screen has to be able to attach a layer before the
    /// camera is opened — the reader is looking at the viewfinder while the permission alert is
    /// still up. An empty session opens nothing and needs no grant; the camera joins it when a run
    /// starts, which is after the alert has been answered.
    ///
    /// `nonisolated(unsafe)`: `AVCaptureSession` predates the concurrency check and claims no
    /// `Sendable`. What upholds the invariant is that every line here that configures, starts or
    /// stops it runs on the queue above, and the only other reader is a preview layer, which
    /// AVFoundation requires be attached from the main thread and which configures nothing.
    public nonisolated(unsafe) let session = AVCaptureSession()

    private let state = Mutex(State())

    public init() {}

    public func start() -> AsyncStream<ScannedCode> {
        AsyncStream { continuation in
            // Any previous run ends here. `stop` finishes a run rather than the scanner — the reader
            // can walk away from this screen and come back to it — and two live sessions on one
            // camera is not a state worth being able to reach.
            stop()
            state.withLock { $0.isStopped = false }

            // The camera stops when the run does, whatever ended it. A screen that forgets to say so
            // would otherwise leave the green dot lit over the list it went back to.
            continuation.onTermination = { [weak self] _ in self?.stop() }

            // `self` strongly, and only until this has run: a `Mutex` is non-copyable and cannot be
            // captured on its own, and the scanner has to outlive the session it is about to own
            // anyway.
            Self.queue.async {
                guard let capture = Self.capture(on: self.session, reporting: continuation) else {
                    // No camera on this device, or one this process may not open. Design §5 draws no
                    // screen for that, so the honest report is a run that ends having read nothing
                    // rather than an outcome invented here.
                    return continuation.finish()
                }
                // Stopped while the session was being built, which is what a reader who tapped back
                // during the half-second a camera takes to configure looks like. The session was
                // never started, so there is nothing to stop and nothing to hold on to.
                guard self.state.withLock({ $0.adopt(capture) }) else { return }
                capture.session.startRunning()
            }
        }
    }

    public func stop() {
        let capture = state.withLock { state in
            state.isStopped = true
            defer { state.capture = nil }
            return state.capture
        }
        guard let capture else { return }
        Self.queue.async { capture.session.stopRunning() }
    }

    /// Fits the camera to the standing session, or answers that there is nothing to fit.
    ///
    /// **A second run finds the camera already on it**, because the session outlives every run and a
    /// preview layer has been drawing through it since the screen appeared: taking the input off to
    /// put an identical one back would blank the viewfinder in front of the reader. The output is
    /// replaced rather than kept, because the delegate it reports to belongs to one run and a run
    /// that ended must not be able to receive another frame.
    ///
    /// The metadata types are set **after** the output joins the session: an output that belongs to
    /// nothing supports no types at all, and assigning one to it then is a trap rather than a
    /// no-op.
    private static func capture(
        on session: AVCaptureSession,
        reporting continuation: AsyncStream<ScannedCode>.Continuation
    ) -> Capture? {
        let output = AVCaptureMetadataOutput()
        let reader = CodeReader(reporting: continuation)
        do {
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            for spent in session.outputs {
                session.removeOutput(spent)
            }
            if session.inputs.isEmpty {
                guard let camera = AVCaptureDevice.default(for: .video) else { return nil }
                let input = try AVCaptureDeviceInput(device: camera)
                guard session.canAddInput(input) else { return nil }
                session.addInput(input)
            }
            guard session.canAddOutput(output) else { return nil }
            session.addOutput(output)
        } catch {
            return nil
        }
        output.setMetadataObjectsDelegate(reader, queue: queue)
        output.metadataObjectTypes = [.qr]

        return Capture(session: session, reader: reader)
    }

    private struct State {

        var isStopped = false
        var capture: Capture?

        /// Takes the session on if the run is still wanted, and says whether it was.
        mutating func adopt(_ capture: Capture) -> Bool {
            guard isStopped == false else { return false }
            self.capture = capture
            return true
        }
    }
}

// MARK: -

/// One run: the session it reads through, and the object it reports to.
///
/// The reader is held because a metadata output does not hold its delegate, so nothing else would.
/// The session is not this run's to throw away — it belongs to the scanner and to the preview layer
/// drawing through it — so what ending a run does to it is stop it, and nothing more.
///
/// `@unchecked Sendable`: AVFoundation predates the check and none of its types claims it. What
/// upholds the invariant is that every line touching either of these runs on the scanner's serial
/// queue — the session is configured, started and stopped there, and the same queue is what the
/// metadata output calls back on — so there is never more than one thread inside.
private final class Capture: @unchecked Sendable {

    let session: AVCaptureSession
    let reader: CodeReader

    init(session: AVCaptureSession, reader: CodeReader) {
        self.session = session
        self.reader = reader
    }
}

// MARK: -

/// The object AVFoundation talks to, because a metadata output wants a delegate rather than a
/// closure. It holds the run and puts one answer on it per code, which is the whole of the part only
/// a real camera executes.
private final class CodeReader: NSObject, AVCaptureMetadataOutputObjectsDelegate {

    private let continuation: AsyncStream<ScannedCode>.Continuation

    init(reporting continuation: AsyncStream<ScannedCode>.Continuation) {
        self.continuation = continuation
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for object in metadataObjects {
            let readable = object as? AVMetadataMachineReadableCodeObject
            continuation.yield(MachineReadableCode.scanned(readable?.stringValue))
        }
    }
}
