import AVFoundation

import ClientConnectionDomain

/// What the system already knows about this app and the camera, and the one alert it will ever raise
/// about it.
///
/// Two of the three things here cannot be run on a build machine. `authorizationStatus` reads a
/// grant recorded against a signed bundle, and a SwiftPM test binary is unsigned and has none;
/// `requestAccess` puts a system alert on screen and waits for somebody in the room to tap it, and
/// on macOS it terminates a process whose bundle carries no usage description at all. So it sits
/// behind `CameraAuthorizing` for the reason the Keychain store sits behind its own protocol, and
/// everything downstream is tested against a fake. The bar is the same: unrunnable by construction,
/// never merely untested.
///
/// The third thing is the mapping, and it is a function here rather than a `switch` inside those
/// calls precisely so a host test reaches it — the same arrangement the Bonjour connection uses to
/// keep the part only a real network runs down to one line.
public struct CaptureDeviceCameraAuthorization: CameraAuthorizing {

    public var current: CameraAccess {
        Self.access(for: AVCaptureDevice.authorizationStatus(for: .video))
    }

    public init() {}

    /// What each status the system can answer with means to the screen that has to draw something.
    ///
    /// **`restricted` does not join `denied`.** They differ in exactly one control and that control
    /// is the whole question: a reader who declined can flip a switch in Settings, and a reader
    /// under a restriction has no switch to flip. An unrecognised status is read the same way rather
    /// than as a refusal, because that answer is safe in both directions — the camera stays shut,
    /// and nobody is sent looking for a switch that may not be the thing holding it.
    static func access(for status: AVAuthorizationStatus) -> CameraAccess {
        switch status {
        case .notDetermined: .notAsked
        case .restricted: .restricted
        case .denied: .refused
        case .authorized: .granted
        @unknown default: .restricted
        }
    }

    /// The `Bool` this answers with is thrown away and the status read back instead, because `false`
    /// is two different screens: a reader who tapped *Don't Allow*, and a device that never showed
    /// the alert at all because a restriction had already answered for them.
    public func request() async -> CameraAccess {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return current
    }
}
