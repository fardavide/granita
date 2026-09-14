import Foundation
import Testing

@testable import ClientConnectionData
import ClientConnectionDomain

/// **The spelling is the whole of what can be wrong here, and it fails silently.** A mistyped scheme
/// or extension identifier opens System Settings on its front page, which looks exactly like the app
/// working and leaves the reader hunting for a pane nobody named — and nothing downstream reports it,
/// because `NSWorkspace.open` answers whether the URL was handed over rather than whether a pane
/// appeared.
@Suite("System settings opener")
struct SystemSettingsOpenerTests {

    @Test
    func `given a pane when asked where it lives then it resolves`() {
        #expect(SystemSettingsOpener.url(of: .camera) != nil)
        #expect(SystemSettingsOpener.url(of: .localNetwork) != nil)
    }

    #if canImport(AppKit)
    @Test
    func `given a Mac when asked for the camera pane then it is the privacy pane's camera anchor`() {
        #expect(
            SystemSettingsOpener.url(of: .camera)?.absoluteString
                == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera"
        )
    }

    @Test
    func `given a Mac when asked for the local network pane then it is that pane's own anchor`() {
        #expect(
            SystemSettingsOpener.url(of: .localNetwork)?.absoluteString
                == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork"
        )
    }

    /// The two are different places, which is the fact the whole pane argument exists for.
    @Test
    func `given a Mac when asked for both panes then they are not the same place`() {
        #expect(SystemSettingsOpener.url(of: .camera) != SystemSettingsOpener.url(of: .localNetwork))
    }
    #else
    /// iOS carries every switch this app has asked for on one page, so the argument selects nothing —
    /// asserted rather than left as a comment, because a platform that split them would need this to
    /// fail rather than to keep passing quietly.
    @Test
    func `given a phone when asked for both panes then both are the app's own page`() {
        #expect(SystemSettingsOpener.url(of: .camera) == SystemSettingsOpener.url(of: .localNetwork))
    }
    #endif
}
