import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

import ServerMacPresentation

/// Shared configuration for the Mac's snapshot tests.
///
/// The iOS suite's equivalent lives in `Apps/GranitaMobileSnapshotTests/SnapshotSupport.swift`, and
/// the two differ in exactly one structural way: **`swift-snapshot-testing` has no SwiftUI strategy
/// on macOS.** `Snapshotting where Value: SwiftUI.View` is declared for iOS and tvOS only, so there
/// is no `drawHierarchyInKeyWindow` and no `ViewImageConfig` here. A view is hosted in an
/// `NSHostingView` and snapshotted through the `NSView` strategy instead.

// MARK: - Where failures are written

/// Sends freshly-rendered mismatches next to the baselines they failed against, so a red CI run
/// uploads something a person can look at. `#filePath` rather than a working directory, because a
/// test runner's cwd is not the repository's.
private let redirectFailureArtifacts: Void = {
    guard ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] == nil else { return }
    let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "__SnapshotFailures__")
    setenv("SNAPSHOT_ARTIFACTS", directory.path, 1)
}()

// MARK: - The appearances every surface is checked in

/// Light and dark, and nothing else.
///
/// The phone renders four — two devices by two appearances — because a layout bug and a colour bug
/// look identical in a single baseline and iPhone and iPad lay out differently. The Mac has one
/// window at one fixed size, so the device axis has one value and is not worth a name.
struct MacAppearance: Sendable, CustomTestStringConvertible {

    let name: String
    let appearance: NSAppearance.Name

    var testDescription: String { name }

    static let all: [MacAppearance] = [
        MacAppearance(name: "light", appearance: .aqua),
        MacAppearance(name: "dark", appearance: .darkAqua)
    ]
}

// MARK: - The assertion

/// Renders a Settings pane at the real window size and compares it against its committed baseline.
///
/// The window is not decoration. A grouped `Form`'s background, a `.borderedProminent` button's
/// tint and every material in the pane resolve against a window's appearance and backdrop; hosted
/// with no window they render flat or clear, and the baseline then stops covering the thing a
/// reader actually sees. This is the macOS shape of the same rule that makes the iOS suite
/// app-hosted.
///
/// The tolerances are the iOS suite's, and they were calibrated there: `perceptualPrecision` at
/// 0.87 absorbs a GPU-less runner scoring a higher colour distance than this Mac, and `precision`
/// at 0.999 is tight because the area budget is what hides a whole changed sentence on a sparse
/// screen. Do not loosen either without repeating the mutation check the `swift-testing` skill
/// describes.
@MainActor
func assertSettingsSnapshot(
    _ view: some View,
    appearance: MacAppearance,
    named name: String,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    _ = redirectFailureArtifacts

    let hosted = hostedInWindow(view, appearance: appearance)
    defer { hosted.window?.orderOut(nil) }

    assertSnapshot(
        of: hosted,
        as: .fixedScaleImage(precision: 0.999, perceptualPrecision: 0.87),
        named: "\(name)-\(appearance.name)",
        fileID: fileID,
        file: file,
        testName: testName,
        line: line,
        column: column
    )
}

/// The status item, at its real 22pt height.
///
/// Its own entry point rather than a parameter on the one above, because a `MenuBarExtra` label is
/// not a Settings pane and sizing it to the window would be a picture of a symbol in the middle of
/// a lot of nothing. The width is what a status item takes: as much as its content, and no more.
@MainActor
func assertStatusItemSnapshot(
    _ view: some View,
    appearance: MacAppearance,
    named name: String,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    _ = redirectFailureArtifacts

    let hosted = hosted(view, appearance: appearance, size: CGSize(width: 44, height: 22))
    defer { hosted.window?.orderOut(nil) }

    assertSnapshot(
        of: hosted,
        as: .fixedScaleImage(precision: 0.999, perceptualPrecision: 0.87),
        named: "\(name)-\(appearance.name)",
        fileID: fileID,
        file: file,
        testName: testName,
        line: line,
        column: column
    )
}

/// The same hosting the assertion uses, at the Settings window's size, exposed so that a test can
/// measure the result instead of comparing a picture of it. Window geometry is not observable from
/// outside the process while Stage Manager is on, which is why the window's own size is asserted
/// from in here.
@MainActor
func hostedInWindow(_ view: some View, appearance: MacAppearance) -> NSView {
    hosted(view, appearance: appearance, size: GranitaSettingsScreen.windowSize)
}

@MainActor
private func hosted(_ view: some View, appearance: MacAppearance, size: CGSize) -> NSView {
    // Pinned, and not a detail. General renders a clock time, so a runner in UTC and a laptop in
    // CEST would draw different pixels from identical code — a baseline that fails for the reason
    // the suite is least able to explain. Fixed here rather than per test, so every Mac baseline
    // is taken in the same environment whatever it happens to render.
    let hosting = NSHostingView(
        rootView: view
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .environment(\.timeZone, .gmt)
    )
    hosting.frame = CGRect(origin: .zero, size: size)
    hosting.appearance = NSAppearance(named: appearance.appearance)

    let window = NSWindow(
        contentRect: hosting.frame,
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: appearance.appearance)
    window.contentView = hosting

    // **These baselines render an INACTIVE window, and that cannot be fixed from here.**
    //
    // macOS draws accent-tinted controls grey when their window is not key, so a
    // `.borderedProminent` button renders as an ordinary one and a switched-on `Toggle` shows a
    // grey track with the knob to the right. A window cannot become key while its application is
    // not active, and a test runner is never the frontmost app — `activate()`, `makeKeyAndOrderFront`
    // and even switching the accessory host to `.regular` were each tried and none of them changes
    // a pixel. Left as the simple call it can honestly be.
    //
    // What that costs is exactly one thing: the accent tint. Layout, copy, symbols, control shapes,
    // a toggle's knob position and every non-accent semantic colour render correctly — the orange on
    // "Not serving" is in these baselines. What a baseline here can never catch is a
    // `.borderedProminent` losing its prominence, so that call is made by reading the code rather
    // than by looking at a picture.
    window.orderFrontRegardless()
    hosting.layoutSubtreeIfNeeded()

    return hosting
}
