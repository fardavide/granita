import AppKit
import Foundation
import Testing

import ServerAppMain

@Suite("Live reader window", .serialized)
@MainActor
struct ReaderWindowTests {

    @Test
    func `when the host opens its reader then its content minimum fits the designed window`() async throws {
        // given
        let readerWasVisible = NSApp.windows.contains {
            ($0.identifier?.rawValue == "granita.reader" || $0.title == "Granita") && $0.isVisible
        }

        // when — the same notification the application delegate publishes on Dock reopen.
        NotificationCenter.default.post(name: GranitaApplicationDelegate.readerRequested, object: nil)
        var opened: NSWindow?
        for _ in 0..<100 {
            opened = NSApp.windows.first {
                ($0.identifier?.rawValue == "granita.reader" || $0.title == "Granita") && $0.isVisible
            }
            if opened != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let window = try #require(
            opened,
            "The host did not open its reader. Windows: \(NSApp.windows.map { ($0.identifier?.rawValue, $0.title, $0.isVisible) })"
        )
        defer {
            if readerWasVisible == false { window.close() }
        }
        window.contentView?.layoutSubtreeIfNeeded()
        // SwiftUI applies scene sizing after the window has appeared.
        for _ in 0..<100 {
            if window.contentMinSize.width > 0 && window.contentMinSize.height > 0 { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        // then — contentMinSize excludes the window's title bar and other chrome.
        #expect(window.contentMinSize == CGSize(width: 640, height: 480))
    }
}
