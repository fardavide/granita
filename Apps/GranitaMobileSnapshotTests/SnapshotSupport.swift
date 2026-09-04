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
/// Reports the safe area the subject was actually laid out against, for every render.
///
/// **Three repairs were attempted ahead of this and all three were guesses**, so it measures the one
/// quantity the failure is a function of instead of a proxy for it. `.ignoresSafeArea(.keyboard)` on
/// the subject produced a byte-identical failure — the subject is wrapped in a `NavigationStack`, so
/// the modifier lands on the wrapper and never reaches the scroll view inside it. Resigning first
/// responder and spinning the run loop took 22 *other* baselines down, because spinning the main run
/// loop invites another suite's case to take the shared window mid-assertion. And a probe for an
/// inherited responder or keyboard window printed nothing at all for the failing render, which is
/// what ruled the keyboard out rather than confirming it.
///
/// What is established: with `drawHierarchyInKeyWindow: false` — a synthetic window carrying the
/// config's declared 47/34 — the subject renders correctly. So the difference is entirely in what the
/// **live** window reports, and this is the number that says what.
///
/// `Color.clear` in a `.background` takes no layout part and draws nothing, so the raster is
/// unchanged; the 86 baselines passing with this in place is the check on that.
private func probingSafeArea(of view: some View, named subject: String) -> some View {
    view.onGeometryChange(for: Reading.self) { proxy in
        Reading(height: proxy.size.height, bottom: proxy.safeAreaInsets.bottom)
    } action: { reading in
        // **Only a reading no safe area explains.** The device's own bottom inset is 4 on the phone
        // and 34 on the iPad; anything past 40 is a keyboard, and a keyboard is the only thing this
        // has ever needed to report. Logging every layout pass instead — which is what found the bug
        // — put twelve hundred `::warning::` annotations on every CI run, and a diagnostic nobody can
        // read past is not a diagnostic.
        guard reading.bottom > 40 else { return }
        record(
            "[snapshot]"
                + " subject=\(subject)"
                + " height=\(Int(reading.height))"
                + " safeBottom=\(Int(reading.bottom))"
                + " — a keyboard is up while this render is being laid out"
        )
    }
}

/// One layout pass's answer to "how tall am I, and how much is spoken for at the bottom".
private struct Reading: Equatable {

    let height: CGFloat
    let bottom: CGFloat
}

/// Where the probe's readings go.
///
/// **Printed *and* written to a file, because neither alone covers both machines.** CI runs
/// `xcodebuild` without `-quiet` so it gets the log; `make snapshots` passes `-quiet` and swallows
/// test stdout, so the only reading this machine can produce is a file. Comparing the two is the
/// whole point of the probe, and a diagnostic that can only be read on one of them answers half the
/// question.
///
/// Beside the failure artefacts, for the same reason they are there: a test runner's working
/// directory is the simulator's, not the repository's.
private let probeLog = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "__SnapshotFailures__/safe-area-probe.txt")

private func record(_ line: String) {
    print("::warning::\(line)")
    let text = line + "\n"
    guard let data = text.data(using: .utf8) else { return }
    try? FileManager.default.createDirectory(
        at: probeLog.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    if let handle = try? FileHandle(forWritingTo: probeLog) {
        defer { try? handle.close() }
        try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: probeLog)
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
    // **Both sides of the render, and the one before it is the one that matters.** Draining after a
    // render cannot catch a rise that happens later, and the rise is late by nature: focus queues it
    // and it arrives whenever the keyboard process gets to it. `the-review-is-open-iPad-light` failed
    // exactly that way — the phone sheet rendered before it raised a keyboard that was still coming
    // up when the iPad column was photographed.
    //
    // Draining here is only safe because every suite is `.serialized` now. The version that did this
    // while sixteen suites were unserialised took 22 unrelated baselines down.
    drainTheKeyboard()

    assertSnapshot(
        // **Pinned, and it has to be.** A grouping separator is a locale's decision, and the first
        // screen here to draw a four-digit figure rendered `+1.204` on the machine that recorded it
        // — which is a baseline the runner cannot reproduce and a red suite nothing in the diff
        // explains. The environment's locale is the right source for what a reader sees and the
        // wrong one for a golden image, so this asserts one layout deliberately rather than
        // whichever the simulator happened to be set to.
        of: probingSafeArea(
            of: view.environment(\.locale, Locale(identifier: "en_US")),
            named: "\(name)-\(layout.name)"
        ),
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

    drainTheKeyboard()
}

/// Waits out the keyboard a render may have raised, so the next render does not inherit its geometry.
///
/// **The race, measured rather than reasoned about.** `ReviewSheetView` focuses its note field
/// `.onAppear` (`ReviewSheetView.swift:125`), which raises the software keyboard **asynchronously**.
/// It does not land on the next render — it lands on whichever render is laying out when it arrives,
/// and `drawHierarchyInKeyWindow` means that render is laid out against the live window's safe area.
/// Both machines catch it exactly once per run and only the victim differs: on CI it was
/// `a-comment-adrift-iPhone-light` at a 261pt bottom inset, which is a phone-light render and shows
/// the damage; here it was `a-suggestion-exists-iPad-dark`, where the capsule does not exist at
/// regular width and the page artefact is black on black. That is the whole reason this was green
/// locally and red on the runner for three consecutive runs.
///
/// **`endEditing` alone does not do it, and neither does `.ignoresSafeArea(.keyboard)`.** Dismissing
/// once leaves a rise that was already queued; the modifier, applied to the subject, moved the inset
/// from 261 to 319 and onto a different render rather than removing it. Both were measured, and both
/// are why this loop dismisses on *every* turn rather than once: whenever the queued rise
/// materialises, it is put back down.
///
/// **Spinning the run loop is only safe because every suite is now `.serialized`.** An earlier
/// version spun it *before* the render while sixteen suites were unserialised, and another suite's
/// case took the window mid-assertion — 22 unrelated baselines went red. Spinning after the render,
/// with nothing else able to run, is the same tool with the hazard removed.
@MainActor
private func drainTheKeyboard() {
    var quiet = 0
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline, quiet < 3 {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        windows.forEach { $0.endEditing(true) }
        let settled = windows.contains {
            "\(type(of: $0))".contains("Keyboard") && $0.isHidden == false
        } == false
        // Three consecutive quiet turns rather than one, because one turn cannot tell a keyboard that
        // has gone from a keyboard that has not arrived yet — and the arrival is the case that costs a
        // baseline.
        quiet = settled ? quiet + 1 : 0
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
}
