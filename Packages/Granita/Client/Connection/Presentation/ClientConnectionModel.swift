import Observation

import ClientConnectionDomain
import CorePairingDomain

/// What the phone knows about Macs nearby and about joining one.
///
/// **One model for the unit, not one per screen.** Discovery and pairing are two views onto the same
/// question — which Mac is this phone talking to — so design §5's four screens read this rather than
/// bringing three more state objects between them.
///
/// It holds outcomes and never sequences. Reading a Mac's health, spending the code and writing the
/// token down is one operation over three protocols, and that belongs in the layer that owns them:
/// what this holds is what a screen shows next.
@Observable
public final class ClientConnectionModel {

    public private(set) var discovery: DiscoveryState = .idle

    /// Which browse is current. The screen keys its task on this, so changing it is what tears the
    /// running browse down and starts another.
    ///
    /// A restart has to be a new browser rather than a new reading of the old one: a dead browser is
    /// dead for good, and the reader taps Search Again precisely when the one they have has stopped
    /// finding anything.
    public private(set) var attempt = 0

    public private(set) var pairing: PairingState = .notStarted

    /// What is in the six-word field, exactly as it was typed.
    ///
    /// **Never corrected.** The server lowercases and accepts spaces, hyphens, middle dots and the
    /// en dash iOS types whether or not anyone meant to, so there is nothing here to fix — and a
    /// refusal keeps the phrase rather than clearing it, because there is no countdown on this phone
    /// and the consequence arriving is what replaces the clock.
    public var typedWords = ""

    /// The words the phone made out, in the order they were typed.
    ///
    /// This and the two below are here rather than left to the view because `Ui` cannot see the word
    /// list: it is contract, so it lives in `Core` beside the link that carries the code, and the
    /// view layer is not allowed to reach that far.
    public var spokenWords: [String] {
        SpokenWords.words(in: typedWords)
    }

    /// The first word typed that no code could contain, or nothing.
    public var firstUnknownWord: String? {
        SpokenWords.firstUnknownWord(in: typedWords)
    }

    /// Whether the phrase is spendable. Six words entered lights the button, and the button turning
    /// blue is the whole announcement — there is no count in its label and no ready badge.
    public var isCodeComplete: Bool {
        spokenWords.count == SpokenWords.wordsInACode
    }

    /// The Mac whose screens are up, and the boundary the two values below it belong inside.
    ///
    /// This model is one instance for the life of the app, so nothing on it is torn down by a
    /// screen going away — which means a credential kept here outlives the Mac it was offered to
    /// unless something says which Mac that was. This is that something, and it is what lets a
    /// retry refuse.
    private var pairingWith: DiscoveredServer?

    /// The credential the last attempt spent at that Mac, and `nil` whenever the last attempt spent
    /// nothing.
    ///
    /// The outcome screen's *Try Again* re-runs the attempt that failed, and neither credential
    /// exists anywhere else by the time that screen is up: a scanned link goes with the viewfinder,
    /// and a phrase that never found an address never became an attempt at all.
    ///
    /// **Written on every path that tries to spend, including the ones that spend nothing**, which
    /// is the half that was missing. Six words with nowhere to send them have to resolve again
    /// before they can be spent — a different act — so that path clears this rather than leaving
    /// whatever an earlier attempt put here for a retry to find and re-send.
    private var spentCredential: PairingAttempt?

    private let browsing: any ServerDiscovering
    private let joining: any MacJoining
    private let camera: any CameraAuthorizing
    private let scanner: any CodeScanning
    private let addresses: any ServerAddressResolving

    /// How long the hint stays replaced by the capsule that says a code was not ours.
    private let hintReturnsAfter: Duration

    public convenience init(
        browsing: any ServerDiscovering,
        joining: any MacJoining,
        camera: any CameraAuthorizing,
        scanner: any CodeScanning,
        addresses: any ServerAddressResolving
    ) {
        self.init(
            browsing: browsing,
            joining: joining,
            camera: camera,
            scanner: scanner,
            addresses: addresses,
            hintReturnsAfter: .seconds(2)
        )
    }

    /// The seam, without a default on it, so a test that means "the capsule's whole life" has to say
    /// how long that is rather than wait it out.
    init(
        browsing: any ServerDiscovering,
        joining: any MacJoining,
        camera: any CameraAuthorizing,
        scanner: any CodeScanning,
        addresses: any ServerAddressResolving,
        hintReturnsAfter: Duration
    ) {
        self.browsing = browsing
        self.joining = joining
        self.camera = camera
        self.scanner = scanner
        self.addresses = addresses
        self.hintReturnsAfter = hintReturnsAfter
    }

    /// Consumes discovery updates until the stream ends or the surrounding task is cancelled.
    ///
    /// Servers appear and disappear while the screen is open — a Mac waking from sleep is the common
    /// case — so this follows the stream rather than taking one reading.
    public func start() async {
        for await update in browsing.discover() {
            discovery = update
        }
    }

    /// Throws the current browse away and begins another.
    ///
    /// Reported as searching straight away rather than waiting for the replacement to say so,
    /// because the tap has to visibly do something and searching is what is true from this instant.
    public func searchAgain() {
        discovery = .searching
        attempt += 1
    }

    /// Throws away whatever the last attempt left behind, and is what opening a Mac's own screen
    /// does.
    ///
    /// **This model is one instance for the life of the app**, so nothing on it is torn down by a
    /// screen going away — and design §5's four screens all read it. Without this the next Mac's
    /// viewfinder opens on the dimmed frame of a spend that finished two Macs ago, with its back
    /// button hidden for a request nobody made; the six-word screen arrives with somebody else's
    /// phrase already typed and its button lit; and *Try Again* reaches for a credential the reader
    /// last held up to a different machine.
    ///
    /// Unconditional rather than only when the Mac changes, because coming back to the Mac that
    /// just refused you is starting an attempt too. What survives a refusal is the phrase on the
    /// screen the reader backs out to, which is one push below this one and never passes through
    /// here.
    public func beginPairing(with server: DiscoveredServer) {
        pairingWith = server
        pairing = .notStarted
        typedWords = ""
        spentCredential = nil
    }

    /// Looks up where a Mac the browse listed is answering, for the screen that names it.
    ///
    /// **Returns rather than records.** The answer belongs to one screen and one Mac: a value kept
    /// on this model would sit under the *next* Mac's name for as long as its own lookup took, which
    /// is a lie rather than a stale caption. It is also read again when six words are spent, because
    /// an address held while a reader types is one that can have gone stale by the time it is used.
    ///
    /// **Silent on failure, and this is the one place that is.** It draws a line under two buttons;
    /// a Mac that will not resolve says so properly, with a screen and a remedy, the moment a
    /// credential is spent on it.
    public func address(of server: DiscoveredServer) async -> ServerAddress? {
        do {
            return try await addresses.address(of: server)
        } catch {
            return nil
        }
    }

    /// Opens the camera if it may be opened, and reads until a code is found or the screen goes
    /// away.
    ///
    /// **The Mac is handed in rather than read off this model**, the same way the two spends below
    /// take it: what a scanned link buys is titled after the Mac whose screen the reader was
    /// pointing at, and one model serving the whole app cannot be trusted to still be holding that
    /// one.
    ///
    /// **The alert is raised from here rather than on the way in.** iOS gives an app one of them,
    /// ever, and design §5 rejects pre-flighting it on the entry screen precisely because that burns
    /// the one prompt at the moment it is least explicable. The state is set before the ask so that
    /// the screen the alert lands on is a screen rather than a blank.
    public func readCode(on server: DiscoveredServer, as device: PairingDevice) async {
        var access = camera.current
        if access == .notAsked {
            pairing = .waitingForCameraAccess
            access = await camera.request()
        }
        switch access {
        case .granted:
            await read(on: server, as: device)
        case .notAsked, .refused:
            // Still unanswered after the one prompt this app gets is not a state AVFoundation
            // produces, and the refusal screen is where it belongs anyway: it is the one that offers
            // the other credential rather than the one that hides a switch.
            pairing = .cameraRefused
        case .restricted:
            pairing = .cameraRestricted
        }
    }

    /// Spends the six words the reader typed against the Mac the browse offered.
    ///
    /// The address is resolved first because the words do not carry one, and a browse result is an
    /// identity rather than a location. Nothing is sent when the phrase is short: the button is dark
    /// then, but the keyboard's Go key is not, and it submits whatever is in the field.
    public func spendTypedWords(on server: DiscoveredServer, as device: PairingDevice) async {
        guard isCodeComplete else { return }
        pairing = .spending
        do {
            let address = try await addresses.address(of: server)
            // What the echo showed, rather than what was typed: the reader's proof that the phone
            // read the phrase they meant is that line, so the line is what gets spent.
            await join(
                .spoken(code: spokenWords.joined(separator: "-"), at: address),
                on: server,
                as: device
            )
        } catch {
            // Nothing left the phone, so nothing is held for a retry to re-send. Saying so is the
            // point: what is here otherwise is a credential from an attempt the reader has already
            // walked away from, and *Try Again* would spend it at whichever Mac is on screen now.
            spentCredential = nil
            pairing = .notReached(error)
        }
    }

    /// Re-runs the attempt that failed, which is not the same attempt on the two paths.
    ///
    /// **The Mac is handed in, and it is checked against the one this attempt is about.** The
    /// outcome screen is titled after the Mac it was given; a credential this model is still
    /// holding for any other one is not this screen's to spend, and pairing with a machine whose
    /// name is nowhere on the screen is the worst ending this flow has.
    public func spendAgain(on server: DiscoveredServer, as device: PairingDevice) async {
        if pairingWith == server, case .scanned(let link) = spentCredential {
            // The QR is still on the Mac's screen and the handshake never reached the Mac, so the
            // code it carries is still worth what it was.
            await join(.scanned(link), on: server, as: device)
        } else {
            // Six words are resolved again before they are spent: the address they borrow is
            // precisely the thing that can have gone stale between the two taps, and a phrase that
            // never found one at all is the same act from one step earlier.
            await spendTypedWords(on: server, as: device)
        }
    }

    /// Spends a credential and records what came of it.
    func join(_ attempt: PairingAttempt, on server: DiscoveredServer, as device: PairingDevice) async {
        pairing = .spending
        spentCredential = attempt
        pairing = .finished(await joining.pair(with: attempt, on: server, as: device))
    }

    /// Retries the Keychain write, and nothing else.
    ///
    /// **The code that bought this token is spent**, so re-running the handshake would ask a Mac to
    /// honour a credential that no longer exists. What can be retried is the step that failed, and
    /// `errSecInteractionNotAllowed` — the common cause — is transient far more often than not.
    ///
    /// The pairing comes out of the state rather than from the caller, so there is one place that
    /// could be wrong about which Mac is being written down instead of two.
    ///
    /// **Both endings a write has reach it**, refused and never answered: the phone is in the same
    /// place after either — paired, holding a token, with the code that bought it spent — so a retry
    /// that reached only one of them would be a lit button that did nothing on the other.
    public func saveTokenAgain() async {
        let mac: PairedMac
        switch pairing {
        case .finished(.tokenNotStored(let paired, _)), .finished(.neverAnswered(.writingTheKey(let paired))):
            mac = paired
        case .finished(.paired), .finished(.wrongContract), .finished(.refused),
             .finished(.neverAnswered(.readingTheContract)), .finished(.neverAnswered(.spendingTheCode)),
             .notStarted, .waitingForCameraAccess, .cameraRefused, .cameraRestricted, .looking,
             .sawSomethingElse, .spending, .savingToken, .notReached:
            return
        }
        pairing = .savingToken
        pairing = .finished(await joining.saveToken(of: mac))
    }

    /// Runs the camera until a code is found or the reader leaves.
    private func read(on server: DiscoveredServer, as device: PairingDevice) async {
        pairing = .looking
        // Whatever ends this — a code spent, or SwiftUI cancelling the task the screen was driving —
        // the camera goes off with it. Saying so twice is allowed and is what the protocol asks for.
        defer { scanner.stop() }
        for await code in scanner.start() {
            switch code {
            case .pairingLink(let link):
                // Finding one freezes the frame, and the frozen frame is the only acknowledgement
                // the reader gets that the phone saw anything at all — so it happens before the
                // request rather than after it.
                scanner.stop()
                await join(.scanned(link), on: server, as: device)
            case .damagedPairingLink, .somethingElse:
                sayThatWasNotOurs()
            }
        }
    }

    /// Replaces the hint with the capsule, at most once every two seconds.
    private func sayThatWasNotOurs() {
        // The throttle and the capsule's life are the same two seconds, and this guard is both of
        // them: while it is up nothing re-triggers it, and a frame that was already in flight when a
        // code was found cannot put a hint back over a frozen screen.
        guard pairing == .looking else { return }
        pairing = .sawSomethingElse
        Task {
            try? await Task.sleep(for: hintReturnsAfter)
            if pairing == .sawSomethingElse {
                pairing = .looking
            }
        }
    }
}
