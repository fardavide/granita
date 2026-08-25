import Testing

import ClientConnectionDomain
import CorePairingDomain

@testable import ClientConnectionPresentation

/// One model for the unit. The browse and design §5's four screens are the same question — which Mac
/// is this phone talking to — so both are asserted here, and the three steps of joining one are
/// asserted where they happen, in `MacPairingTests`.
@Suite("Client connection model")
struct ClientConnectionModelTests {

    // MARK: - The browse

    @Test
    func `given nothing has happened when created then it is idle`() {
        // given - when
        let scenario = Scenario(discovering: [])

        // then
        #expect(scenario.sut.discovery == .idle)
        #expect(scenario.sut.pairing == .notStarted)
    }

    @Test
    func `given a server is nearby when searching then it is offered`() async {
        // given
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(discovering: [.searching, .found([mac])])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.discovery == .found([mac]))
    }

    @Test
    func `given permission is refused when searching then that is reported as its own state`() async {
        // given — a denial is not a failure the user can only stare at: it is the one they can fix.
        let scenario = Scenario(discovering: [.searching, .localNetworkDenied])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.discovery == .localNetworkDenied)
    }

    @Test
    func `given nothing was found when the reader searches again then it is looking once more`() async {
        // given — the browse went quiet and the Mac was plugged in afterwards. Without this the
        // reader's only recourse is to kill the app.
        let scenario = Scenario(discovering: [.searching, .found([])])
        await scenario.sut.start()

        // when
        scenario.sut.searchAgain()

        // then
        #expect(scenario.sut.discovery == .searching)
    }

    @Test
    func `given a browse is running when the reader searches again then a fresh attempt replaces it`() {
        // given
        let scenario = Scenario(discovering: [])
        let before = scenario.sut.attempt

        // when
        scenario.sut.searchAgain()

        // then — the screen keys its task on this, so changing it is what tears the running browse
        // down and puts a new one in its place. Asking the old stream to start over would not make a
        // new browser, and a new browser is the whole mechanism.
        #expect(scenario.sut.attempt != before)
    }

    @Test
    func `given a server disappears when searching then the list empties without erroring`() async {
        // given — a Mac going to sleep is the common case, not an error.
        let mac = DiscoveredServer(id: "MacBook", name: "MacBook")
        let scenario = Scenario(discovering: [.found([mac]), .found([])])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.discovery == .found([]))
    }

    // MARK: - Where the Mac being paired with answers

    @Test
    func `given a Mac the browse found when its address is looked up then the screen can name it`() async {
        // given — the line under the two credentials. A browse result is an identity rather than a
        // location, so the only way to draw it is to ask.
        let scenario = Scenario()

        // when
        let address = await scenario.sut.address(of: aMacTheBrowseFound)

        // then
        #expect(address == anAddress)
    }

    @Test
    func `given a Mac that will not answer when its address is looked up then nothing is named`() async {
        // given — absent rather than guessed: it is a caption under two buttons, and a Mac that
        // cannot be reached says so properly the moment a credential is spent on it.
        let scenario = Scenario(resolving: .failure(.unreachable(diagnostic: "No such record")))

        // when
        let address = await scenario.sut.address(of: aMacTheBrowseFound)

        // then
        #expect(address == nil)
    }

    // MARK: - The camera, which is a preference rather than a fault

    @Test(.timeLimit(.minutes(1)))
    func `given nobody has answered the alert when the scanner opens then the screen behind it says so`() async {
        // given — the state usually left undrawn: the alert lands on this screen and the reader
        // reads it while deciding, so it exists for exactly as long as somebody is thinking.
        let scenario = Scenario(cameraSaying: .notAsked, answering: .granted, answeredAfter: .seconds(60))
        let reading = Task { await scenario.sut.readCode(as: anIphone) }

        // when
        await scenario.settling(from: .notStarted)

        // then
        #expect(scenario.sut.pairing == .waitingForCameraAccess)
        reading.cancel()
        await reading.value
    }

    @Test
    func `given nobody has answered the alert when the scanner opens then it is raised once`() async {
        // given — iOS gives an app one of these, ever, so it is asked from the screen that survives
        // either answer rather than ahead of it.
        let scenario = Scenario(cameraSaying: .notAsked, answering: .granted, thenEnding: true)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.camera.timesAsked == 1)
        #expect(scenario.sut.pairing == .looking)
    }

    @Test
    func `given the reader says no to the alert when it closes then the six words are what is offered`() async {
        // given — nothing has gone wrong. The refusal screen's primary action is the other
        // credential, and Settings is demoted beneath it.
        let scenario = Scenario(cameraSaying: .notAsked, answering: .refused)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .cameraRefused)
    }

    @Test
    func `given the reader said no before when the scanner opens then the alert is not raised again`() async {
        // given
        let scenario = Scenario(cameraSaying: .refused, answering: .granted)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then — asking again returns the standing answer and shows nothing, so the only thing a
        // second ask could do is make the screen look like it is waiting for a reader who already
        // decided.
        #expect(scenario.sut.pairing == .cameraRefused)
        #expect(scenario.camera.timesAsked == 0)
    }

    @Test
    func `given a policy holds the camera shut when the scanner opens then the switch is not offered`() async {
        // given — the same screen as a refusal, minus the one control that cannot work: under a
        // restriction there is no switch behind Turn the Camera On in Settings.
        let scenario = Scenario(cameraSaying: .restricted, answering: .restricted)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .cameraRestricted)
        #expect(scenario.camera.timesAsked == 0)
    }

    @Test
    func `given the system still says nobody answered when the alert closes then the six words are offered`() async {
        // given — not reachable through AVFoundation, which answers with what it left behind. It is
        // expressible, and the alternative to answering it is a screen that waits for a prompt this
        // app has already spent.
        let scenario = Scenario(cameraSaying: .notAsked, answering: .notAsked)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .cameraRefused)
    }

    // MARK: - The viewfinder

    @Test
    func `given the camera may be opened when the scanner opens then it is looking`() async {
        // given
        let scenario = Scenario(cameraSaying: .granted, answering: .granted, thenEnding: true)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .looking)
    }

    @Test
    func `given a stranger's code when it is read then the hint is replaced`() async {
        // given — a QR on a poster, or a sticker on a laptop lid. An alert would stop the camera and
        // demand a tap for something that happens every time the phone drifts.
        let scenario = Scenario(reading: [.somethingElse], thenEnding: true)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .sawSomethingElse)
    }

    @Test
    func `given one of ours that is broken when it is read then it is not told apart from a stranger's`() async {
        // given — design §5 writes one sentence for both, and it deliberately does not say which
        // code it found: nothing on this phone reads a foreign QR back to the reader.
        let scenario = Scenario(
            reading: [.damagedPairingLink(.missingField(named: "spki"))],
            thenEnding: true
        )

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .sawSomethingElse)
    }

    @Test
    func `given the hint was replaced when another stranger's code arrives then it is not shown again`() async {
        // given — one appearance every two seconds rather than one per frame, and the capsule's life
        // and the throttle are the same two seconds.
        let scenario = Scenario(reading: [.somethingElse, .somethingElse], thenEnding: true)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .sawSomethingElse)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given the hint was replaced when two seconds pass then it comes back`() async {
        // given — two seconds expressed as none of them, so the capsule's whole life fits inside a
        // test rather than inside a wait.
        let scenario = Scenario(reading: [.somethingElse], thenEnding: true, hintReturnsAfter: .zero)

        // when
        await scenario.sut.readCode(as: anIphone)
        await scenario.settling(from: .sawSomethingElse)

        // then — and the camera was never stopped, so what comes back is a viewfinder rather than a
        // screen the reader has to leave.
        #expect(scenario.sut.pairing == .looking)
    }

    @Test
    func `given a stranger's code before ours when both are read then the pairing still happens`() async {
        // given — the proof that the capsule does not stop the camera: the second code was read at
        // all, which a stopped session could not have delivered.
        let scenario = Scenario(reading: [.somethingElse, .pairingLink(aLink)])

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.paired(aPairedMac)))
    }

    @Test
    func `given ours is found when it is read then the frame freezes`() async {
        // given — the session stops the instant a code is found, and the frozen frame is the only
        // acknowledgement the reader gets that the phone saw anything at all.
        let scenario = Scenario(reading: [.pairingLink(aLink)])

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.scanner.isStopped)
        #expect(scenario.sut.pairing == .finished(.paired(aPairedMac)))
    }

    @Test
    func `given ours was found when a later frame arrives then the frozen frame is not talked over`() async {
        // given — the camera reads several times a second, so a frame that was already in flight
        // lands after the code was spent. Putting the hint back then would unfreeze a screen whose
        // whole job is to say the phone is busy.
        let scenario = Scenario(reading: [.pairingLink(aLink), .somethingElse], thenEnding: true)

        // when
        await scenario.sut.readCode(as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.paired(aPairedMac)))
    }

    @Test(.timeLimit(.minutes(1)))
    func `given the reader leaves the scanner when the run is cancelled then the camera is stopped`() async {
        // given — a session nobody is watching is the green dot lit over the list they went back to.
        let scenario = Scenario(reading: [.somethingElse])
        let reading = Task { await scenario.sut.readCode(as: anIphone) }
        await scenario.settling(from: .notStarted)

        // when
        reading.cancel()
        await reading.value

        // then
        #expect(scenario.scanner.isStopped)
    }

    // MARK: - Spending a credential

    @Test(.timeLimit(.minutes(1)))
    func `given a Mac that has not answered yet when a code is spent then there is nothing to press`() async {
        // given — the one place in this app a progress view is right: unlike a browse, this request
        // finishes.
        let scenario = Scenario(answeringPairAfter: .seconds(60))
        let joining = Task { await scenario.sut.join(.scanned(aLink), as: anIphone) }

        // when
        await scenario.settling(from: .notStarted)

        // then
        #expect(scenario.sut.pairing == .spending)
        joining.cancel()
        await joining.value
    }

    @Test
    func `given a scanned link when the Mac is joined then that is what the screen reads`() async {
        // given — the ending with no screen of its own: what the entry screen watches for is this
        // value, and the stack it replaces is the whole of the celebration.
        let scenario = Scenario()

        // when
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.paired(aPairedMac)))
    }

    @Test
    func `given the Mac refused the code when it is spent then no pairing is claimed`() async {
        // given
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))

        // when
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.refused(.pairingExpired)))
    }

    @Test
    func `given the two ends disagree when a code is offered then the outcome says which is behind`() async {
        // given — read from health before anything is spent, which is what lets that screen say the
        // code was not used.
        let scenario = Scenario(answeringPair: .wrongContract(.phoneIsBehind(serving: 9)))

        // when
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.wrongContract(.phoneIsBehind(serving: 9))))
    }

    // MARK: - The six words, and the echo that makes them checkable

    @Test
    func `given nothing typed when the field is read then no words are recognised`() {
        // given - when
        let scenario = Scenario()

        // then
        #expect(scenario.sut.spokenWords.isEmpty)
        #expect(scenario.sut.firstUnknownWord == nil)
        #expect(scenario.sut.isCodeComplete == false)
    }

    @Test
    func `given six words typed the way a reader types them when the field is read then the echo is the Mac's line`() {
        // given — a capital on the first word and spaces instead of hyphens, which is what somebody
        // reading a code off a screen across the room produces.
        let scenario = Scenario()

        // when
        scenario.sut.typedWords = "Cabin cactus camera candle harbour lantern"

        // then — the reader compares this against the Mac's line rather than proofreading their own
        // typing, which is a different and far easier task.
        #expect(scenario.sut.spokenWords == ["cabin", "cactus", "camera", "candle", "harbour", "lantern"])
        #expect(scenario.sut.isCodeComplete)
    }

    @Test
    func `given a word no code can contain when the field is read then it is the one that is named`() {
        // given — five failures a minute lock this phone out, so a round trip spent on a word that
        // was never in the list costs more than it looks.
        let scenario = Scenario()

        // when
        scenario.sut.typedWords = "cabin branch camera candle harbour lantern"

        // then
        #expect(scenario.sut.firstUnknownWord == "branch")
    }

    @Test
    func `given five words when the field is read then the button stays dark`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.typedWords = "cabin cactus camera candle harbour"

        // then — six words entered lights the button and nothing else announces it.
        #expect(scenario.sut.isCodeComplete == false)
    }

    @Test
    func `given five words when they are offered then nothing is sent`() async {
        // given — the button is dark, and the keyboard's Go key is not: it submits whatever is in
        // the field, so the refusal has to live here rather than only in the control.
        let scenario = Scenario()
        scenario.sut.typedWords = "cabin cactus camera candle harbour"

        // when
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .notStarted)
        #expect(scenario.joining.attemptsOffered.isEmpty)
    }

    @Test
    func `given six words when they are offered then what is sent is what the echo showed`() async {
        // given — the echo is the reader's proof that the phone read what they meant, so the request
        // carries exactly that and not the punctuation their keyboard chose.
        let scenario = Scenario()
        scenario.sut.typedWords = "Cabin · cactus · camera · candle · harbour · lantern"

        // when
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(
            scenario.joining.attemptsOffered == [
                .spoken(code: "cabin-cactus-camera-candle-harbour-lantern", at: anAddress)
            ]
        )
        #expect(scenario.sut.pairing == .finished(.paired(aPairedMac)))
    }

    @Test
    func `given the Mac cannot be found when six words are offered then the code is not sent`() async {
        // given — the words carry no address, so a Mac that slept between the browse and the typing
        // ends the attempt before anything is spent.
        let scenario = Scenario(resolving: .failure(.unreachable(diagnostic: "No such record\nNWError -72004")))
        scenario.sut.typedWords = sixWords

        // when
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .notReached(.unreachable(diagnostic: "No such record\nNWError -72004")))
        #expect(scenario.joining.attemptsOffered.isEmpty)
    }

    @Test
    func `given the local network is refused when six words are offered then that is not a fault to retry`() async {
        // given — the refusal survives rather than being flattened into "could not reach it": Try
        // Again in front of a permission that never grants itself is a control that does nothing.
        let scenario = Scenario(resolving: .failure(.localNetworkDenied))
        scenario.sut.typedWords = sixWords

        // when
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .notReached(.localNetworkDenied))
    }

    @Test
    func `given the code was refused when the words screen comes back then what was typed is still there`() async {
        // given — there is no countdown on the phone, so the consequence arrives instead of the
        // clock: the screen keeps the phrase and says the code is stale.
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))
        scenario.sut.typedWords = sixWords

        // when
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.sut.typedWords == sixWords)
    }

    // MARK: - What Try Again spends again

    @Test
    func `given a scanned link when it is tried again then the same link goes back to the same Mac`() async {
        // given — the QR is still on the Mac's screen and the handshake never reached the Mac, so
        // the code it carries is worth exactly what it was.
        let scenario = Scenario(answeringPair: .refused(.unreachable(diagnostic: "NWError -72004")))
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // when
        await scenario.sut.spendAgain(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.joining.attemptsOffered == [.scanned(aLink), .scanned(aLink)])
    }

    @Test
    func `given six words when they are tried again then the address they borrow is looked up afresh`() async {
        // given — the address is precisely the thing that can have gone stale between the two taps,
        // so the phrase resolves again rather than re-sending where it went last time.
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        scenario.sut.typedWords = sixWords
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // when
        await scenario.sut.spendAgain(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.joining.attemptsOffered == [
            .spoken(code: sixWords, at: anAddress),
            .spoken(code: sixWords, at: anAddress)
        ])
    }

    @Test
    func `given the Mac was never found when it is tried again then the phrase resolves before it is spent`() async {
        // given — a phrase that never reached an address spent nothing at all, which is the one
        // ending where trying again has to resolve first rather than re-send what was sent.
        let scenario = Scenario()
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        scenario.sut.typedWords = sixWords

        // when
        await scenario.sut.spendAgain(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.joining.attemptsOffered == [.spoken(code: sixWords, at: anAddress)])
    }

    @Test
    func `given a link was spent on this Mac when its words will not resolve then trying again does not re-send it`() async {
        // given — both credentials, one Mac. The camera read a code, the Mac refused it, and the
        // reader fell back to typing — and that phrase found nowhere to go. Nothing was spent by
        // the second attempt, so what Try Again re-runs is the resolution rather than the code the
        // camera read a screen ago.
        let scenario = Scenario(
            answeringPair: .refused(.pairingExpired),
            resolving: .failure(.localNetworkDenied)
        )
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        await scenario.sut.join(.scanned(aLink), as: anIphone)
        scenario.sut.typedWords = sixWords
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // when
        await scenario.sut.spendAgain(on: aMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.joining.attemptsOffered == [.scanned(aLink)])
        #expect(scenario.sut.pairing == .notReached(.localNetworkDenied))
    }

    @Test
    func `given a credential kept from a Mac the reader has left when another is tried then it stays put`() async {
        // given — the same guarantee without leaning on a screen having reset anything: whatever
        // this model is still holding belongs to the Mac it was offered to, and *Try Again* is
        // handed the Mac whose name is in the title bar.
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        await scenario.sut.join(.scanned(aLink), as: anIphone)
        scenario.sut.typedWords = sixWords

        // when
        await scenario.sut.spendAgain(on: theOtherMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.joining.attemptsOffered == [
            .scanned(aLink),
            .spoken(code: sixWords, at: anAddress)
        ])
    }

    @Test
    func `given one Mac's link was refused when another Mac cannot be found then trying again spends nothing`() async {
        // given — the sequence one app-wide model makes possible, and the worst thing in this
        // flow: a QR refused on one Mac, the reader backs out, opens a second, types its six words
        // and it will not resolve. Try Again reaching for the first Mac's link would pair this
        // phone with a machine whose name is nowhere on the screen.
        let scenario = Scenario(
            answeringPair: .refused(.pairingExpired),
            resolving: .failure(.unreachable(diagnostic: "No such record"))
        )
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        await scenario.sut.join(.scanned(aLink), as: anIphone)
        scenario.sut.beginPairing(with: theOtherMacTheBrowseFound)
        scenario.sut.typedWords = sixWords
        await scenario.sut.spendTypedWords(on: theOtherMacTheBrowseFound, as: anIphone)

        // when
        await scenario.sut.spendAgain(on: theOtherMacTheBrowseFound, as: anIphone)

        // then — the first Mac's link went once, when the reader pointed a camera at it, and never
        // again. The second Mac still cannot be found, which is the honest answer.
        #expect(scenario.joining.attemptsOffered == [.scanned(aLink)])
        #expect(scenario.sut.pairing == .notReached(.unreachable(diagnostic: "No such record")))
    }

    @Test
    func `given one Mac's link was refused when another Mac's words are tried again then the words go`() async {
        // given — the same sequence with a second Mac that answers, so what Try Again did is
        // visible rather than merely absent.
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        await scenario.sut.join(.scanned(aLink), as: anIphone)
        scenario.sut.beginPairing(with: theOtherMacTheBrowseFound)
        scenario.sut.typedWords = sixWords
        await scenario.sut.spendTypedWords(on: theOtherMacTheBrowseFound, as: anIphone)

        // when
        await scenario.sut.spendAgain(on: theOtherMacTheBrowseFound, as: anIphone)

        // then
        #expect(scenario.joining.attemptsOffered == [
            .scanned(aLink),
            .spoken(code: sixWords, at: anAddress),
            .spoken(code: sixWords, at: anAddress)
        ])
    }

    // MARK: - Opening a Mac, which is what starts an attempt

    @Test
    func `given a Mac answered when another is opened then no frozen viewfinder is left over`() async {
        // given — one model serves the whole app, so an ending outlives the screen that produced
        // it. Left there, the next Mac's viewfinder opens on a dimmed frame under "Pairing with…"
        // and hides its back button for a spend that is not happening.
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // when
        scenario.sut.beginPairing(with: theOtherMacTheBrowseFound)

        // then
        #expect(scenario.sut.pairing == .notStarted)
    }

    @Test
    func `given a phrase was typed for one Mac when another is opened then the field is empty`() {
        // given — otherwise the six-word screen arrives with somebody else's phrase already typed
        // and the button lit, one tap from spending it at a Mac that never minted it.
        let scenario = Scenario()
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        scenario.sut.typedWords = sixWords

        // when
        scenario.sut.beginPairing(with: theOtherMacTheBrowseFound)

        // then
        #expect(scenario.sut.typedWords.isEmpty)
        #expect(scenario.sut.isCodeComplete == false)
    }

    @Test
    func `given a Mac answered when it is opened again then the last attempt is not still on screen`() async {
        // given — arriving at a Mac's own screen is what starts an attempt, and a reader who comes
        // back to the Mac they just failed on is starting one too.
        let scenario = Scenario(answeringPair: .refused(.pairingExpired))
        scenario.sut.beginPairing(with: aMacTheBrowseFound)
        scenario.sut.typedWords = sixWords
        await scenario.sut.spendTypedWords(on: aMacTheBrowseFound, as: anIphone)

        // when
        scenario.sut.beginPairing(with: aMacTheBrowseFound)

        // then
        #expect(scenario.sut.pairing == .notStarted)
        #expect(scenario.sut.typedWords.isEmpty)
    }

    // MARK: - The write that failed and can be tried again

    @Test(.timeLimit(.minutes(1)))
    func `given a Keychain that has not answered when the write is retried then the screen says so`() async {
        // given — that screen gained a button, so it also gained the moment between the tap and the
        // answer. Without a state for it a second failure redraws the screen it was already on.
        let scenario = Scenario(
            answeringPair: .tokenNotStored(aPairedMac, .refused(status: -25308)),
            answeringWriteAfter: .seconds(60)
        )
        await scenario.sut.join(.scanned(aLink), as: anIphone)
        let writing = Task { await scenario.sut.saveTokenAgain() }

        // when
        await scenario.settling(from: .finished(.tokenNotStored(aPairedMac, .refused(status: -25308))))

        // then
        #expect(scenario.sut.pairing == .savingToken)
        writing.cancel()
        await writing.value
    }

    @Test
    func `given the Keychain refused when the write is retried then the pairing is kept`() async {
        // given — errSecInteractionNotAllowed is transient far more often than not, and the pairing
        // travelled with the failure precisely so this is possible.
        let scenario = Scenario(
            answeringPair: .tokenNotStored(aPairedMac, .refused(status: -25308)),
            answeringWrite: .paired(aPairedMac)
        )
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // when
        await scenario.sut.saveTokenAgain()

        // then
        #expect(scenario.sut.pairing == .finished(.paired(aPairedMac)))
    }

    @Test
    func `given the Keychain refused when the write is retried then no second code is spent`() async {
        // given — the code that bought this token is gone, so re-running the handshake would ask a
        // Mac to honour a credential that no longer exists.
        let scenario = Scenario(
            answeringPair: .tokenNotStored(aPairedMac, .refused(status: -25308)),
            answeringWrite: .paired(aPairedMac)
        )
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // when
        await scenario.sut.saveTokenAgain()

        // then
        #expect(scenario.joining.attemptsOffered == [.scanned(aLink)])
    }

    @Test
    func `given the Keychain still refuses when the write is retried then it can be tried a third time`() async {
        // given
        let scenario = Scenario(
            answeringPair: .tokenNotStored(aPairedMac, .refused(status: -25308)),
            answeringWrite: .tokenNotStored(aPairedMac, .refused(status: -25308))
        )
        await scenario.sut.join(.scanned(aLink), as: anIphone)

        // when
        await scenario.sut.saveTokenAgain()

        // then — the same outcome carrying the same pairing, so the screen does not become a dead
        // end after one attempt.
        #expect(scenario.sut.pairing == .finished(.tokenNotStored(aPairedMac, .refused(status: -25308))))
    }

    @Test
    func `given nothing was ever paired when the write is retried then nothing happens`() async {
        // given — the pairing comes out of the state rather than from the caller, so there is one
        // place that can be wrong about which Mac is being written down, and it is this guard.
        let scenario = Scenario()

        // when
        await scenario.sut.saveTokenAgain()

        // then
        #expect(scenario.sut.pairing == .notStarted)
    }
}

// MARK: -

private struct Scenario {

    let camera: FakeCameraAuthorization
    let joining: FakeMacJoining
    let scanner: FakeCodeScanner

    let sut: ClientConnectionModel

    /// Every parameter is something a screen differs by, and every default is the ordinary case: a
    /// granted camera, a Mac that agrees at once, and a hint replaced for longer than any test runs
    /// — so a test that cares about the capsule's two seconds has to say so.
    init(
        discovering states: [DiscoveryState] = [],
        cameraSaying current: CameraAccess = .granted,
        answering answer: CameraAccess = .granted,
        answeredAfter alertLife: Duration = .zero,
        reading codes: [ScannedCode] = [],
        thenEnding ends: Bool = false,
        answeringPair pairOutcome: PairingOutcome = .paired(aPairedMac),
        answeringPairAfter pairDelay: Duration = .zero,
        answeringWrite writeOutcome: PairingOutcome = .paired(aPairedMac),
        answeringWriteAfter writeDelay: Duration = .zero,
        resolving address: Result<ServerAddress, ServerAddressResolutionFailure> = .success(anAddress),
        hintReturnsAfter hint: Duration = .seconds(60)
    ) {
        camera = FakeCameraAuthorization(current, answering: answer, answeredAfter: alertLife)
        joining = FakeMacJoining(
            answeringPair: pairOutcome,
            answeringPairAfter: pairDelay,
            answeringWrite: writeOutcome,
            answeringWriteAfter: writeDelay
        )
        scanner = FakeCodeScanner(reading: codes)
        // The real scanner runs until a code is found or the reader walks away, so a test that wants
        // to look at what a foreign QR left behind has to make the run finite. Stopping it before it
        // starts does that and drops nothing: every code is still delivered, and the loop then ends.
        if ends {
            scanner.stop()
        }
        sut = ClientConnectionModel(
            browsing: FakeServerDiscovery(states: states),
            joining: joining,
            camera: camera,
            scanner: scanner,
            addresses: FakeServerAddressResolver(answering: address),
            hintReturnsAfter: hint
        )
    }

    /// Yields until the model has moved off a state, so a test can look at the one after it.
    ///
    /// A condition rather than a duration: the fakes hold their answers open on purpose, and what is
    /// being waited for is the model arriving somewhere rather than any length of time passing.
    func settling(from state: PairingState) async {
        while sut.pairing == state {
            await Task.yield()
        }
    }
}

private let aLink = PairingLink(
    host: "davides-macbook-pro.local",
    port: 59_144,
    code: "9d41e0c7a2b85f36",
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
)

private let anIphone = PairingDevice(name: "Davide's iPhone", platform: "iOS")

private let anAddress = ServerAddress(host: "davides-macbook-pro.local", port: 59_144)

private let aMacTheBrowseFound = DiscoveredServer(
    id: "Davide's MacBook Pro",
    name: "Davide's MacBook Pro"
)

/// A second Mac, for the tests that walk away from the first one.
///
/// Named nothing like it, because what those tests are about is a credential turning up under the
/// wrong name: two Macs called the same thing would let a mix-up read as a match.
private let theOtherMacTheBrowseFound = DiscoveredServer(id: "Mac Studio", name: "Mac Studio")

private let aPairedDevice = PairedDevice(
    token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
    deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
    serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
)

private let aPairedMac = PairedMac(
    device: aPairedDevice,
    address: anAddress,
    fingerprint: aLink.fingerprint
)

private let sixWords = "cabin-cactus-camera-candle-harbour-lantern"
