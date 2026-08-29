import AVFoundation
import ClientConnectionDomain
import ClientConnectionPresentation
import CorePairingDomain
import SwiftUI

/// A Mac to pair with, the four collaborators a pairing screen needs behind it, and a picture to put
/// where the camera would be.
///
/// Deliberately a second copy of what `Client/Connection/PresentationTests` already has, for the
/// reason its worktree sibling gives: there is no way to share test code between a SwiftPM test
/// target and an Xcode one, and the alternative is a production module existing to be borrowed by
/// tests.
///
/// **Kept as small as a render needs**, which is smaller than the model's own suite needs. Not one
/// of these can be made to take its time, because nothing here asserts what was on screen while
/// somebody else was thinking — a baseline is taken from a settled model, so a fake that suspended
/// would only make the raster a race.
struct FakeServerDiscovery: ServerDiscovering {

    let states: [DiscoveryState]

    func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            for state in states { continuation.yield(state) }
            continuation.finish()
        }
    }
}

// MARK: -

/// A Mac that ends every attempt the same way.
///
/// One answer for both the spend and the write, because a baseline is taken after exactly one of
/// them: the screen it photographs is the one that answer produced.
struct FakeMacJoining: MacJoining {

    let answering: PairingOutcome

    /// Which Macs the phone can open without pairing, defaulted to none because that is what every
    /// pairing baseline is about: a Mac already paired with never reaches these screens.
    var remembering: Set<BonjourInstanceName> = []

    func pair(
        with attempt: PairingAttempt,
        on mac: DiscoveredServer,
        as device: PairingDevice
    ) async -> PairingOutcome {
        answering
    }

    func saveToken(of pairing: PairedMac) async -> PairingOutcome { answering }

    func rememberedMacs() async -> Set<BonjourInstanceName> { remembering }
}

// MARK: -

/// What the system already says about the camera, and what it would say if asked.
///
/// The same answer twice, deliberately: the states that hold a *pending* alert are the ones a
/// baseline cannot take, since the screen behind it is only up while somebody is deciding. What this
/// reaches is the two settled refusals, which are the two the reader is most likely to see.
struct FakeCameraAuthorization: CameraAuthorizing {

    let current: CameraAccess

    func request() async -> CameraAccess { current }
}

// MARK: -

/// A camera with nothing in front of it.
///
/// It yields nothing, so the model stays wherever opening the camera left it rather than falling
/// through to an ending nothing produced — and it **ends**, which a viewfinder pointed at an empty
/// desk does not. That difference is the whole reason it is written this way: a baseline of the
/// scanner has to settle the model before the shutter rather than race the screen's own task, and a
/// run that never returns cannot be awaited. What the screen is left showing is the same either way.
struct FakeCodeScanner: CodeScanning {

    func start() -> AsyncStream<ScannedCode> { AsyncStream { $0.finish() } }

    func stop() {}
}

// MARK: -

/// Where a browsed Mac is, or why it could not be found.
struct FakeServerAddressResolver: ServerAddressResolving {

    let answering: Result<ServerAddress, ServerAddressResolutionFailure>

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        switch answering {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}

// MARK: -

/// What the viewfinder is handed in place of a camera.
///
/// **This is the whole reason `PairingScannerView` takes its preview from outside.** A simulator has
/// no camera and a runner has no room to point one at, so the one screen in this app built around a
/// live image is photographed against a still — and the still is drawn rather than stored, so no
/// baseline depends on a second file being what it was.
///
/// Fixed colours rather than semantic ones, which is the call the reticle already makes one file
/// over: what a camera returns is the room's palette and not the app's. So this renders identically
/// in light and dark, and the only thing that differs between those two baselines is the chrome
/// around it — which is exactly the comparison the pair is for.
struct CameraStill: View {

    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.11, blue: 0.13), Color(red: 0.28, green: 0.30, blue: 0.34)],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            // A Mac's screen at an angle nobody holds a phone at is a picture of a photograph. Flat
            // and centred instead: what the reticle has to be legible against is a pale panel with a
            // dark square on it, and that is the whole of what this has to be.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.92))
                .aspectRatio(1.6, contentMode: .fit)
                .overlay {
                    Rectangle()
                        .fill(Color(white: 0.08))
                        .aspectRatio(1, contentMode: .fit)
                        .padding(28)
                }
                .padding(36)
        }
    }
}

// MARK: -

/// The Mac every pairing baseline is taken against.
///
/// Two words rather than one, and no apostrophe: design §5 puts this name in a navigation title on
/// four screens and in the middle of five sentences, so what it has to survive is being read inline
/// rather than being long.
nonisolated let aMacName = "Mac Studio"

nonisolated let aDiscoveredMac = DiscoveredServer(
    id: BonjourInstanceName(rawValue: aMacName),
    name: aMacName
)

/// A name and a port that could only have come from Bonjour: the system chose the port, so it is a
/// five-figure number nobody would have picked, which is what makes it worth photographing.
nonisolated let aMacAddress = ServerAddress(host: "Mac-Studio.local", port: 54_321)

/// A pairing that bought a token, for the one screen that is drawn after one was bought and could
/// not be written down. Nothing on that screen renders any of these fields.
nonisolated let aPairedMac = PairedMac(
    instance: aDiscoveredMac.id,
    name: aMacName,
    device: PairedDevice(
        token: PairingToken(rawValue: "not-a-token-any-Mac-ever-issued"),
        deviceId: DeviceId(rawValue: "device-1"),
        serverInstanceId: ServerInstanceId(rawValue: "server-1")
    ),
    address: aMacAddress,
    fingerprint: SpkiFingerprint(rawValue: "9dQ0mHXWiHc4T0uQr4nqe3sBEUqB1qkFqjNwr8SsCkI="),
    wakeAddresses: []
)

/// Six words a Mac could really have minted, in the order a reader would type them.
nonisolated let aSpokenCode = ["amber", "anchor", "apple", "arrow", "autumn", "bacon"]

/// What the machine running the tests would tell a Mac about itself.
///
/// A function rather than a value, because a capture session is not `Sendable` and a global holding
/// one would be shared state between renders of a screen that draws it. Empty and never started: the
/// preview layer attached to it has no camera to show, which is the only thing a simulator can be
/// honest about — and it needs no permission, so building one raises nothing.
@MainActor
func aPhone() -> ThisPhone {
    ThisPhone(
        device: PairingDevice(name: "Davide's iPhone", platform: "iOS"),
        cameraSession: AVCaptureSession()
    )
}
