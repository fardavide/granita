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
        await model.readCode(on: aDiscoveredMac, as: phone.device)

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

    @Test(arguments: SnapshotLayout.all)
    func `given a Mac paired with before when the spine is rendered then the pairing screens are skipped`(
        layout: SnapshotLayout
    ) async {
        // given — the same push as `the-mac`, onto a Mac this phone already holds a pairing for. The
        // two baselines are the whole assertion and they have to be read together: identical value on
        // the path, identical model, and one of them must not be the entry screen.
        //
        // **Only a rendered push can say this.** Which of two destinations a value reaches is decided
        // in a `navigationDestination` closure, and a view test hands a screen its state directly — so
        // it can photograph both screens beautifully and nothing at all about which one a tap lands
        // on. That is the defect this suite exists for, and it is the defect this release fixes.
        let model = aModel(
            camera: .granted,
            joining: .refused(.pairingExpired),
            resolving: .failure(.localNetworkDenied),
            remembering: [aDiscoveredMac.id]
        )
        await model.start()

        // when - then
        assertScreenSnapshot(
            theSpine(model, showing: [], on: aPhone()),
            layout: layout,
            named: "a-mac-already-paired-with"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given a Mac just paired with when the spine is rendered then the worktrees are reached`(
        layout: SnapshotLayout
    ) async {
        // given — the other way past the spine, and the only one that had a baseline before this
        // release: a pairing that worked replaces the pairing screens with the Mac it produced.
        //
        // **It is here for the width as much as for the destination.** The two routes are the same
        // arrival and must be given the same measure, and the release that got that wrong got it
        // wrong by treating them as two things. Read this baseline beside `a-mac-already-paired-with`
        // on the same device: the same screen, at the same width, reached by the other route.
        let model = aModel(camera: .granted, joining: .refused(.pairingExpired), resolving: .failure(.localNetworkDenied))
        await model.start()

        // when - then
        assertScreenSnapshot(
            theSpine(model, atTheWorktreesOf: aPairedMac, on: aPhone()),
            layout: layout,
            named: "a-mac-just-paired-with"
        )
    }
}

// MARK: -

/// **The screen the composition root presents, not a copy of it.**
///
/// It used to be a copy — the same stack, rebuilt here, with §5's 420pt measure hardcoded around it.
/// That is why these baselines went on being green through the release that clamped an iPad's
/// worktree list to a phone-shaped slot: the replica applied the measure unconditionally, so it
/// photographed the defect and called it the truth. The measure is gone entirely now, and rendering
/// the real screen is what makes that visible here rather than assumed.
///
/// Everything the root supplies that reaches the network is replaced; what a Mac leads to is not.
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
    return theSpine(model, startingAt: path, on: phone)
}

/// The same stack, opened where a pairing that worked leaves it: the Mac it produced, and none of the
/// screens that produced it.
@MainActor
private func theSpine(
    _ model: ClientConnectionModel,
    atTheWorktreesOf mac: PairedMac,
    on phone: ThisPhone
) -> some View {
    theSpine(model, startingAt: NavigationPath([mac]), on: phone)
}

@MainActor
private func theSpine(
    _ model: ClientConnectionModel,
    startingAt path: NavigationPath,
    on phone: ThisPhone
) -> some View {
    PairingSpineScreen(
        model: model,
        phone: phone,
        startingAt: path,
        // **Where a Mac already paired with goes, standing in for the worktree list.**
        //
        // The composition root puts the real one here, over a session pinned to that Mac. This
        // suite deliberately does not: what it asserts is *which destination a push reaches, and at
        // what width*, and building a worktree list to find that out would make each baseline a
        // second, worse copy of a screen that has four suites of its own — and would put a
        // repository behind a test about navigation.
        //
        // So the destination names itself, the way `PairingStep` is public so a step can be put on
        // the path. It appears in exactly one baseline. In the other four the Mac is not remembered,
        // and this sentence turning up in any of them is the picture saying so.
        readingARememberedMac: { mac in
            Text("The worktrees on \(mac.name), reached without pairing.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .navigationTitle(mac.name)
        },
        // Reached by spending a credential rather than by a push, so no baseline here lands on it —
        // and it is required, which is the point: the two ways out of the spine are declared
        // together, and neither can quietly be given a different measure from the other.
        readingAJustPairedMac: { mac in
            Text("The worktrees on \(mac.name), reached by pairing.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .navigationTitle(mac.name)
        }
    )
}

/// Every collaborator spelled out at each call site rather than defaulted, because which of them a
/// baseline is about is the whole of what one of these tests says.
@MainActor
private func aModel(
    camera: CameraAccess,
    joining: PairingOutcome,
    resolving: Result<ServerAddress, ServerAddressResolutionFailure>,
    remembering: Set<BonjourInstanceName> = []
) -> ClientConnectionModel {
    ClientConnectionModel(
        browsing: FakeServerDiscovery(states: [.found([aDiscoveredMac])]),
        joining: FakeMacJoining(answering: joining, remembering: remembering),
        camera: FakeCameraAuthorization(current: camera),
        scanner: FakeCodeScanner(),
        addresses: FakeServerAddressResolver(answering: resolving)
    )
}
