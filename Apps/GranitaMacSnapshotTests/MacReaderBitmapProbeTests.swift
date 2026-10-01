import AppKit
import ScreenCaptureKit
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
        case .nativeBitmap, .windowComposite:
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
        if capture == .windowComposite {
            // This API enumerates only content this process may capture without TCC consent.
            // The exact fixture window is required; there is no display or other-app fallback.
            let content = try await SCShareableContent.currentProcess
            let capturedWindow = try #require(content.windows.first {
                $0.windowID == CGWindowID(window.windowNumber)
                    && $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
            })
            let configuration = SCStreamConfiguration()
            configuration.width = 2520
            configuration.height = 1600
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.includeChildWindows = false
            configuration.ignoreShadowsSingleWindow = true
            configuration.colorSpaceName = CGColorSpace.sRGB
            let contentRect = view.convert(view.bounds, to: nil)
            configuration.sourceRect = CGRect(
                x: contentRect.minX,
                y: window.frame.height - contentRect.maxY,
                width: contentRect.width,
                height: contentRect.height
            )
            let raster = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: capturedWindow),
                configuration: configuration
            )
            assertSnapshot(
                of: NSImage(cgImage: raster, size: view.bounds.size),
                as: .image(precision: 0.999, perceptualPrecision: 0.87),
                named: "\(capture.rawValue)-\(appearance.name)"
            )
        } else {
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
    }

    enum Capture: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case nativeBitmap = "compatible-bitmap"
        case hostingController = "hosting-controller"
        case windowComposite = "own-window-composite"

        var testDescription: String { rawValue }
    }
}
