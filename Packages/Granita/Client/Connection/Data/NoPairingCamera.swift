import ClientConnectionDomain
import CorePairingDomain

/// Mac pairing accepts six words and has no camera capability or permission prompt.
public struct NoPairingCamera: CameraAuthorizing, CodeScanning {

    public init() {}

    public var current: CameraAccess { .restricted }

    public func request() async -> CameraAccess { .restricted }

    public func start() -> AsyncStream<ScannedCode> {
        AsyncStream { $0.finish() }
    }

    public func stop() {}
}
