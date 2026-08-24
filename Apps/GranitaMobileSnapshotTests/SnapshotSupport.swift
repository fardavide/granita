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
