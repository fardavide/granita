import AppKit
import SnapshotTesting
import SwiftUI
import Testing

// Temporary runner experiment: compare the compatible AppKit bitmap and controller hosting
// without changing a production control.
@Suite("Reader bitmap diagnostics", .serialized)
@MainActor
struct MacReaderBitmapProbeTests {
    @Test(arguments: Capture.allCases, MacAppearance.all)
    func probe(capture: Capture, appearance: MacAppearance) async throws {
        let scenario = MacReaderScreenSnapshotTests.Scenario(subject: .tree)
        defer { scenario.sidebar.cancelLoading() }
        let root = scenario.view
            .frame(width: 1260, height: 800)
            .environment(\.colorScheme, appearance.name == "dark" ? .dark : .light)
            .background(Color(nsColor: .windowBackgroundColor))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1260, height: 800),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        let previousAppearance = NSApp.appearance
        NSApp.appearance = NSAppearance(named: appearance.appearance)
        defer {
            window.orderOut(nil)
            NSApp.appearance = previousAppearance
        }
        window.appearance = NSAppearance(named: appearance.appearance)
        let view: NSView
        switch capture {
        case .nativeBitmap:
            view = NSHostingView(rootView: root)
            window.contentView = view
        case .hostingController:
            let controller = NSHostingController(rootView: root)
            window.contentViewController = controller
            view = controller.view
        }
        view.appearance = window.appearance
        view.frame = CGRect(x: 0, y: 0, width: 1260, height: 800)
        window.orderFrontRegardless()
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .seconds(1))
        _ = try await scenario.prepare(appearance: appearance)
        try await Task.sleep(for: .seconds(1))
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            assertSnapshot(
                of: view,
                as: .image(precision: 0.999, perceptualPrecision: 0.87),
                named: "\(capture.rawValue)-\(appearance.name)"
            )
        }
    }

    enum Capture: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case nativeBitmap = "compatible-bitmap"
        case hostingController = "hosting-controller"

        var testDescription: String { rawValue }
    }
}
