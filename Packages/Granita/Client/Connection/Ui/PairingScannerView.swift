import SwiftUI

import ClientConnectionDomain

/// The viewfinder, and the five things it can be doing.
///
/// Stateless, and **the camera arrives from outside** — the preview is whatever view the composition
/// root hands over, because `Ui` may not see the capture session that produces one and because a
/// baseline has to be able to photograph this screen on a machine with no camera and no permission.
/// Pass a still and every state below renders exactly as it ships.
///
/// **Dark, and the camera decides that rather than the app.** This is the one screen in Granita that
/// is dark in light mode, and only where the preview fills the screen: on the phone the camera is the
/// screen and the app disappears behind it, while on the iPad it is a card in a 420pt column and
/// blacking out 1194pt to host it would make a modal out of a pushed screen. The refusal is not dark
/// either — there is no camera image behind it, so there is nothing to be dark for.
///
/// **The navigation bar stays over the preview.** It is translucent, and once the camera fills the
/// screen the title is the only place *which Mac this is* appears.
public struct PairingScannerView<CameraPreview: View>: View {

    private let macName: String
    private let state: PairingState
    private let cameraPreview: CameraPreview
    private let onEnterWords: () -> Void
    private let onOpenSettings: () -> Void

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(
        macName: String,
        state: PairingState,
        onEnterWords: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        @ViewBuilder cameraPreview: () -> CameraPreview
    ) {
        self.macName = macName
        self.state = state
        self.onEnterWords = onEnterWords
        self.onOpenSettings = onOpenSettings
        self.cameraPreview = cameraPreview()
    }

    public var body: some View {
        Group {
            switch state {
            // Before the task that asks for the camera has run, waiting for access is exactly what
            // this screen is doing — so the pre-alert state is also the state it is pushed in,
            // rather than a blank frame the reader sees first.
            case .notStarted, .waitingForCameraAccess:
                waitingForAccess
            case .cameraRefused:
                cameraOff(offeringSettings: true)
            // Nothing the reader did, and nothing a trip to Settings can undo: under a policy there
            // is no switch behind that button, so it is absent rather than dead.
            case .cameraRestricted:
                cameraOff(offeringSettings: false)
            case .looking:
                looking
            case .sawSomethingElse:
                sawSomethingElse
            // The four states that mean a credential has left the phone all keep the frozen frame,
            // because that is what is *underneath* the outcome this screen pushed. The reader is
            // looking at the screen in front, and what shows through behind it is never a screen
            // claiming something finished when it has not.
            case .spending, .savingToken, .finished, .notReached:
                spending
            }
        }
        .navigationTitle(macName)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Whether the camera is the screen or one element on it, which is the only question the two
    /// layouts of this screen differ by — and the one that decides whether it goes dark.
    private var previewFillsTheScreen: Bool {
        #if os(macOS)
        // No size classes here, and no camera either: the package compiles for the host so that
        // `make test` can run on it, and the Mac app does not link this module.
        false
        #else
        horizontalSizeClass == .compact
        #endif
    }

    /// The screen the permission alert lands on, and the reader reads it while deciding.
    ///
    /// One line and the six-word button, already: whichever way they answer, the answer was behind
    /// the alert. The alert's own words are `NSCameraUsageDescription`, which is copy we write.
    private var waitingForAccess: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("Waiting for camera access.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) { sixWordsButton }
        .preferredColorScheme(previewFillsTheScreen ? .dark : nil)
    }

    /// A refusal is a preference, so it is not treated as a fault.
    ///
    /// The primary action is the other credential and the description does not mention Settings at
    /// all — nothing has gone wrong. *Turn the Camera On in Settings* is named for what it does
    /// rather than where it goes, and it is demoted because leaving the app to fix a state with an
    /// in-app remedy is the wrong first suggestion.
    private func cameraOff(offeringSettings: Bool) -> some View {
        ContentUnavailableView {
            Label("Camera access is off", systemImage: "video.slash")
        } description: {
            Text(
                """
                You do not need it. Your Mac shows six words under the QR code, \
                and typing them pairs this iPhone just as well.
                """
            )
        } actions: {
            Button("Enter the Six Words", action: onEnterWords)
                .buttonStyle(.borderedProminent)
            if offeringSettings {
                Button("Turn the Camera On in Settings", action: onOpenSettings)
            }
        }
    }

    private var looking: some View {
        camera(stillReading: true) {
            Text("Point this at the QR code on your Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// A QR that is not ours is a line, not an interruption.
    ///
    /// It **replaces the hint** and the camera keeps running: an alert would stop the session and
    /// demand a tap for something that recurs every time the phone drifts over a sticker on a laptop
    /// lid. It does not say *which* code it found — nothing on this phone reads a stranger's QR back
    /// to them.
    private var sawSomethingElse: some View {
        camera(stillReading: true) {
            Label("That is not a Granita pairing code.", systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.thinMaterial, in: .capsule)
        }
    }

    /// Finding one freezes the frame.
    ///
    /// The six-word button goes, because there is nothing left to choose, and the progress view is
    /// honest here where it would not be over a Bonjour browse: this request finishes.
    private var spending: some View {
        camera(stillReading: false) {
            VStack(spacing: 12) {
                ProgressView()
                VStack(spacing: 4) {
                    Text("Pairing with \(macName)")
                        .font(.headline)
                        .lineLimit(1)
                        // Middle, as everywhere a Bonjour name is on one line: two Macs differ at
                        // the end of their names.
                        .truncationMode(.middle)
                    Text("Checking the Mac, then spending the code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
        }
        #if !os(macOS)
        // A code that works once must not be abandonable halfway by an edge swipe. Hidden rather
        // than dimmed, which is what the frame draws: a navigation bar has no disabled back button,
        // and drawing our own would be hand-building the one piece of chrome the system owns.
        .navigationBarBackButtonHidden(true)
        #endif
    }

    /// The three states with a preview behind them, which differ only in what sits under it.
    @ViewBuilder private func camera(
        stillReading: Bool,
        @ViewBuilder saying line: () -> some View
    ) -> some View {
        Group {
            if previewFillsTheScreen {
                preview(stillReading: stillReading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 28) {
                            if stillReading {
                                reticle.padding(.horizontal, 56)
                            }
                            line()
                                .padding(.horizontal, 32)
                        }
                    }
            } else {
                VStack(spacing: 20) {
                    preview(stillReading: stillReading)
                        // 4:3 inside the measure, because detection reads the whole capture frame
                        // rather than the preview: a smaller card costs the reader aim and nothing
                        // else, and nobody lifts an 11-inch iPad to point it at a Mac.
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay {
                            if stillReading {
                                reticle.padding(30)
                            }
                        }
                    line()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if stillReading {
                sixWordsButton
            }
        }
        .preferredColorScheme(previewFillsTheScreen ? .dark : nil)
    }

    private func preview(stillReading: Bool) -> some View {
        cameraPreview
            .overlay {
                if stillReading == false {
                    // The frozen frame is the only acknowledgement the reader gets that the phone
                    // saw anything at all, so it dims rather than disappearing. A material rather
                    // than black at an opacity: it frosts dark behind the phone's full-screen
                    // preview and light over the iPad's card, so the copy over it reads in both.
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
    }

    /// Where to aim, and the one place in this app a fixed colour is right: what is behind it is a
    /// camera image, so the palette is the room's rather than the app's.
    private var reticle: some View {
        RoundedRectangle(cornerRadius: 22)
            .strokeBorder(.white, lineWidth: 3)
            .aspectRatio(1.4, contentMode: .fit)
    }

    /// The way out, in the bottom safe area of every state the camera is still reading in —
    /// including the one the permission alert is drawn over.
    private var sixWordsButton: some View {
        Button(action: onEnterWords) {
            Label("Enter the Six Words", systemImage: "keyboard")
                .frame(maxWidth: .infinity, minHeight: PairingEntryView.credentialButtonHeight)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
