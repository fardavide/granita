import AVFoundation

import ClientConnectionDomain

/// The two things about the machine this is running on that no screen can read for itself.
///
/// Carried together rather than as two parameters because they travel the same route — down every
/// screen in the pairing spine — and because both are answers only a composition root may look up:
/// a view does no I/O, and asking the system what this device is called is I/O.
public struct ThisPhone {

    /// What the Mac lists in its Devices tab once it has let this phone in.
    public let device: PairingDevice

    /// The session the viewfinder draws.
    ///
    /// It belongs to the scanner the model reads codes from, and the two cannot be told apart from
    /// a screen: a preview attached to any other session would show a camera nobody is reading,
    /// which is the most convincing possible version of a control that does nothing.
    public let cameraSession: AVCaptureSession

    public init(device: PairingDevice, cameraSession: AVCaptureSession) {
        self.device = device
        self.cameraSession = cameraSession
    }
}
