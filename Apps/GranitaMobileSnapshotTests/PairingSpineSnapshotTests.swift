import ClientConnectionDomain
import ClientConnectionPresentation
import ClientConnectionUi
import SwiftUI
import Testing

/// The four screens as a reader walks them: values put on the stack the composition root owns, and
/// whatever comes back.
///
/// **The other four suites photograph views; this one photographs the pushes.** A view suite hands a
/// screen its state directly, so it can say what every state looks like and nothing at all about
/// whether anything leads there — and this app has shipped a link whose destination no module
/// declared, drawn beautifully in four layouts, for eight releases. Here the only thing handed over
/// is a `PairingStep`, which is why that enumeration is public: what is asserted is that a step put
/// on the path comes back as a screen rather than as the system's missing-destination placeholder.
///
/// It is also the only kind of test that reaches the model behind those screens — the bindings, the
/// two `.task`s, and the state each screen reads — and the only one that draws a real
/// `AVCaptureVideoPreviewLayer`, which is as close to a camera as a machine with none gets.
///
/// **Every model is settled before the shutter**, never left to the screen's own task, because a
/// raster taken while a task is still running is a picture of whichever of the two won. The tasks
/// re-run and answer the same way, so what is photographed is settled rather than merely likely.
///
/// **Serialised**, for the reason the worktree screen suites are: these await before they draw, and a
/// suspension on the main actor is where another rendering test can take the key window this one is
/// about to photograph.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Pairing spine", .serialized)
@MainActor
struct PairingSpineSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a Mac was chosen when the spine is rendered then its own screen is reached`(
        layout: SnapshotLayout
    ) async {
        // given — the browse settled, and a Mac that will not resolve. **The address line is absent
        // on purpose**: the entry screen asks for it from a `.task`, so a run that answered would
        // leave the raster racing the shutter for a caption. What the line looks like when it does
        // arrive is the view suite's `address-known` baseline, taken from a value rather than a task.
        let model = aModel(camera: .granted, joining: .refused(.pairingExpired), resolving: .failure(.localNetworkDenied))
        await model.start()

        // when - then
        assertScreenSnapshot(
            theSpine(model, showing: [], on: aPhone()),
            layout: layout,
            named: "the-mac"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given the scan step when the spine is rendered then the viewfinder is reached`(
        layout: SnapshotLayout
    ) async {
        // given — the camera opened and found nothing, which is where a viewfinder rests. The preview
        // is a real one over an empty session, so what it draws is what a phone draws in the instant
        // before the first frame arrives.
        let phone = aPhone()
        let model = aModel(camera: .granted, joining: .refused(.pairingExpired), resolving: .failure(.localNetworkDenied))
        await model.readCode(as: phone.device)

        // when - then
        assertScreenSnapshot(
            theSpine(model, showing: [.scanTheCode], on: phone),
            layout: layout,
            named: "the-viewfinder"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given the words step when the spine is rendered then the field is reached`(
        layout: SnapshotLayout
    ) async {
        // given — a phrase the model has read, which is the binding this screen exists for: the field
        // shows what was typed and the echo shows what the phone made of it.
        let model = aModel(camera: .granted, joining: .refused(.pairingExpired), resolving: .success(aMacAddress))
        model.typedWords = aSpokenCode.joined(separator: " ")

        // when - then
        assertScreenSnapshot(
            theSpine(model, showing: [.typeTheWords], on: aPhone()),
            layout: layout,
            named: "the-six-words"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given the outcome step when the spine is rendered then the receipt is reached`(
        layout: SnapshotLayout
    ) async {
        // given — a phrase actually spent, so the ending on the screen is one the model produced
        // rather than one handed to a view. A code that is no longer valid is the ending the words
        // path reaches most, and the one with no action on it at all.
        let phone = aPhone()
        let model = aModel(camera: .granted, joining: .refused(.pairingExpired), resolving: .success(aMacAddress))
        model.typedWords = aSpokenCode.joined(separator: " ")
        await model.spendTypedWords(on: aDiscoveredMac, as: phone.device)

        // when - then
        assertScreenSnapshot(
            theSpine(model, showing: [.theOutcome], on: phone),
            layout: layout,
            named: "the-receipt"
        )
    }
}

// MARK: -

/// The stack the composition root owns, holding a Mac and whichever steps follow it.
///
/// Clamped the way the root clamps it and on the same side of the container: §5 puts everything
/// before a paired Mac in a 420pt column, title included, and iOS draws a title in the bar rather
/// than in the content — so a measure applied inside would assert an alignment the app does not have.
@MainActor
private func theSpine(
    _ model: ClientConnectionModel,
    showing steps: [PairingStep],
    on phone: ThisPhone
) -> some View {
    var path = NavigationPath()
    path.append(aDiscoveredMac)
    for step in steps {
        path.append(step)
    }
    return NavigationStack(path: .constant(path)) {
        ServerDiscoveryScreen(model: model, phone: phone, path: .constant(path), onPaired: { _ in })
    }
    .frame(maxWidth: ServerDiscoveryView.contentWidth)
    .frame(maxWidth: .infinity)
}

/// Every collaborator spelled out at each call site rather than defaulted, because which of them a
/// baseline is about is the whole of what one of these tests says.
@MainActor
private func aModel(
    camera: CameraAccess,
    joining: PairingOutcome,
    resolving: Result<ServerAddress, ServerAddressResolutionFailure>
) -> ClientConnectionModel {
    ClientConnectionModel(
        browsing: FakeServerDiscovery(states: [.found([aDiscoveredMac])]),
        joining: FakeMacJoining(answering: joining),
        camera: FakeCameraAuthorization(current: camera),
        scanner: FakeCodeScanner(),
        addresses: FakeServerAddressResolver(answering: resolving)
    )
}
