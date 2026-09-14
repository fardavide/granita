#if canImport(AppKit)
import AppKit
#endif
import Testing

import ClientConnectionData
import ClientConnectionDomain

@Suite("Diagnostic pasteboard")
struct SystemDiagnosticPasteboardTests {

    #if canImport(AppKit)
    /// **Its own pasteboard, never the general one**, which is what makes this assertable at all. The
    /// sibling in the viewer is exempt from coverage because writing the developer's clipboard on
    /// every `make test` is not something a suite may do — naming a pasteboard removes that cost and
    /// the exemption with it, so the question *did Copy Logs put the report where a paste would find
    /// it* has an answer here rather than only on a device.
    @Test
    func `given a Mac when copying diagnostics then the text is on the pasteboard`() async throws {
        let name = NSPasteboard.Name("dev.fardavide.granita.tests.diagnostics")
        defer { NSPasteboard(name: name).releaseGlobally() }

        try await SystemDiagnosticPasteboard(name: name).copy("Granita diagnostics")

        #expect(NSPasteboard(name: name).string(forType: .string) == "Granita diagnostics")
    }
    #endif
}
