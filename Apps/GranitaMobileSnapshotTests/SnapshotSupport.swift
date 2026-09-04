import ClientViewerDomain
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

/// Shared configuration for every snapshot test.
///
/// Three things are settled here rather than at each call site, because getting any of them wrong
/// produces a test that passes while asserting nothing.

// MARK: - Where failures are written

/// Sends freshly-rendered mismatches next to the baselines they failed against.
///
/// Without this they land in a temporary directory the CI job cannot find, so a red run uploads
/// nothing and the only way to see what changed is to reproduce it locally. `#filePath` is used
/// rather than a working directory because a test runner's cwd is the simulator's, not the
/// repository's.
///
/// Runs once, from the first snapshot assertion. An existing `SNAPSHOT_ARTIFACTS` wins, so the
/// environment can still override it.
private let redirectFailureArtifacts: Void = {
    guard ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] == nil else { return }
    let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "__SnapshotFailures__")
    setenv("SNAPSHOT_ARTIFACTS", directory.path, 1)
}()

// MARK: - The layouts every screen is checked in

/// A device and appearance pair.
///
/// These are the compositions a screen has to survive, and they are checked together rather than
/// separately because a layout bug and a colour bug look identical in a single baseline.
struct SnapshotLayout: Sendable, CustomTestStringConvertible {

    let name: String
    let configuration: ViewImageConfig
    let style: UIUserInterfaceStyle

    var testDescription: String { name }

    /// Whether iOS calls this width regular, which is the question every screen in this app that
    /// lays out twice actually asks — never the device, because an iPad in a narrow multitasking
    /// width is the phone's layout too.
    ///
    /// It is here rather than in the one suite that reads it because it is a fact about the layout
    /// and not about the screen: a suite that wants to know which of its four renderings is the one
    /// with a sidebar beside it is asking this, and asking it of `traits` spelled out at the call
    /// site reads as plumbing rather than as the distinction it is.
    var isRegularWidth: Bool {
        configuration.traits.horizontalSizeClass == .regular
    }

    /// The code size this layout draws at — 11pt on the phone, 12pt beside the selector column.
    ///
    /// The same question `WorktreeDiffScreen` asks, answered the same way, so a baseline photographs
    /// the grid the app builds rather than one the suite chose.
    var codePointSize: CGFloat {
        DiffPaneLayout(
            fitsSelectorColumn: isRegularWidth,
            isSelectorColumnOpen: true,
            hasFilesToSelect: true,
            // The code size is taken from the room rather than from what is folded into it, so
            // neither of these moves it — stated rather than defaulted, because a default here would
            // be a second answer to a question this type exists to answer once.
            isReviewOpen: false,
            hasComments: false
        ).codePointSize
    }

    /// iPhone and iPad, light and dark. Four renderings per state.
    ///
    /// The device configurations describe size and safe-area traits, not a specific simulator — the
    /// tests run on whatever simulator CI pins, and the layout is what is being asserted.
    static let all: [SnapshotLayout] = [
        SnapshotLayout(name: "iPhone-light", configuration: .iPhone13Pro, style: .light),
        SnapshotLayout(name: "iPhone-dark", configuration: .iPhone13Pro, style: .dark),
        SnapshotLayout(name: "iPad-light", configuration: .iPadPro11, style: .light),
        SnapshotLayout(name: "iPad-dark", configuration: .iPadPro11, style: .dark)
    ]
}

// MARK: - What the previous case left behind

/// Puts the shared window back to a state this render can be photographed in, and says so when it
/// had to.
///
/// **`drawHierarchyInKeyWindow` renders through the host app's one real window**, and in that mode
/// swift-snapshot-testing ignores the layout config's declared safe area entirely: it resizes the
/// live window and lays out against whatever safe area that window reports. So a keyboard raised by
/// whatever rendered *before* this call is still in the geometry. It never appears in the raster,
/// because a keyboard lives in its own window — **it appears as a shorter screen.**
///
/// It cost a baseline. On 4 September 2026 `a-comment-adrift-iPhone-light` failed on CI, byte for
/// byte across three runs and green on this machine every time. The case before it in the same
/// serialised suite opens `ReviewSheetView`, which focuses its note field `.onAppear` and carries a
/// `placement: .keyboard` toolbar. The next render came out with a 387pt bottom inset, and one short
/// frame produced two symptoms that read as unrelated defects: the review capsule is an `.overlay`
/// on `ContinuousDiffView`'s frame so it drew 387pt up its own screen, and the page colour is one
/// `.background` on that same frame so it stopped before the 10pt gap between two files, which then
/// showed the window's white. **No row moved**, because a scroll view absorbs a bottom safe area as a
/// content inset rather than by clipping.
///
/// **This reports and changes nothing, deliberately.** Two repairs were tried ahead of it and both
/// were guesses. Asking the subject to `.ignoresSafeArea(.keyboard)` produced a byte-identical
/// failure — the subject is wrapped in a `NavigationStack`, so the modifier lands on the wrapper and
/// never reaches the scroll view inside it. Resigning first responder here and spinning the run loop
/// until the keyboard withdrew took 22 *other* baselines down with it, because spinning the main run
/// loop is an invitation for another suite's case to take the window mid-assertion — the very hazard
/// this file is trying to close.
///
/// So: measure first. The leak is invisible in the failure it causes, because the keyboard is never
/// in the picture, and a run that cannot say whether a keyboard window was even present cannot tell a
/// wrong fix from a wrong diagnosis. This prints what each render inherited and leaves it there.
///
/// What it has already established, on this machine: a first responder **does** survive between
/// cases here. There is simply no software keyboard behind it locally, so it costs nothing — which is
/// exactly why every local run is green while CI is not.
@MainActor
private func reportInheritedState(before subject: String) {
    let windows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)

    let responder = windows.first { $0.findFirstResponder() != nil }
    let keyboards = windows.filter { "\(type(of: $0))".contains("Keyboard") && $0.isHidden == false }
    guard responder != nil || keyboards.isEmpty == false else { return }

    let insets = windows.first { $0.isKeyWindow }?.safeAreaInsets ?? .zero
    print(
        "::warning::[snapshot] \(subject) inherited"
            + " responder=\(responder != nil)"
            + " keyboards=\(keyboards.count)\(keyboards.map { Int($0.frame.height) })"
            + " keyWindowSafeAreaBottom=\(Int(insets.bottom))"
    )
}

private extension UIView {

    /// The first responder in this view's tree, if the tree holds one.
    func findFirstResponder() -> UIView? {
        if isFirstResponder {
            return self
        }
        for subview in subviews {
            if let found = subview.findFirstResponder() {
                return found
            }
        }
        return nil
    }
}

// MARK: - The assertion

/// Renders a view in one layout and compares it against its committed baseline.
///
/// `drawHierarchyInKeyWindow` is what makes this an app-hosted test rather than a hostless one: it
/// renders through the real window, so materials, blur and `ContentUnavailableView` resolve the way
/// they do on a device. Without a host the same call returns a blank image and every test passes.
///
/// The two tolerances do different jobs and are calibrated separately.
///
/// `perceptualPrecision` is the **per-pixel colour** threshold. It has to be loose enough to absorb
/// what is not a regression: iOS re-drawing a translucent panel a shade differently between runs,
/// and a GPU-less CI runner scoring a higher colour distance than this Mac. Setting it to 1 asks for
/// byte equality, which nothing with a material in it can deliver. Aura's 0.87 is inherited, tuned
/// against the same OS and runner image.
///
/// `precision` is the **area** budget: the share of pixels allowed to differ *after* the colour
/// threshold has already forgiven near-misses. Aura's 0.98 is wrong here and was caught by mutating
/// the view: changing "Local network access is off" to "…is disabled" altered roughly 1.6% of a
/// 1170×2532 screen and the suite stayed green, because 2% was allowed to move. Aura's screens are
/// dense; this one is mostly empty, so the same budget hides a whole sentence.
///
/// 0.999 instead. Drift that is merely a shade is already absorbed by `perceptualPrecision`, so what
/// remains here should be close to nothing — and a change big enough to read is far larger than a
/// tenth of a percent. Verified by the same mutation: at 0.999 it fails, and reverting makes it pass.
@MainActor
func assertScreenSnapshot(
    _ view: some View,
    layout: SnapshotLayout,
    named name: String,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    _ = redirectFailureArtifacts
    reportInheritedState(before: "\(name)-\(layout.name)")

    assertSnapshot(
        // **Pinned, and it has to be.** A grouping separator is a locale's decision, and the first
        // screen here to draw a four-digit figure rendered `+1.204` on the machine that recorded it
        // — which is a baseline the runner cannot reproduce and a red suite nothing in the diff
        // explains. The environment's locale is the right source for what a reader sees and the
        // wrong one for a golden image, so this asserts one layout deliberately rather than
        // whichever the simulator happened to be set to.
        of: view.environment(\.locale, Locale(identifier: "en_US")),
        as: .image(
            drawHierarchyInKeyWindow: true,
            precision: 0.999,
            perceptualPrecision: 0.87,
            layout: .device(config: layout.configuration),
            traits: UITraitCollection(userInterfaceStyle: layout.style)
        ),
        named: "\(name)-\(layout.name)",
        fileID: fileID,
        file: file,
        testName: testName,
        line: line,
        column: column
    )
}
