#if canImport(AppKit)
import AppKit
#endif
import Testing

import ClientViewerData

@Suite("Review pasteboard")
struct SystemReviewPasteboardTests {

    #if canImport(AppKit)
    /// The question the old empty `#if` could not be asked: *did pressing Copy review put the review
    /// where a paste would find it*. A named board is what makes it askable without writing the
    /// developer's own clipboard on every `make test`.
    @Test
    func `given a Mac when copying a review then the text is on the pasteboard`() {
        let name = NSPasteboard.Name("dev.fardavide.granita.tests.review")
        defer { NSPasteboard(name: name).releaseGlobally() }

        SystemReviewPasteboard(name: name).copy("src/App.swift:12 — this allocates per row")

        #expect(NSPasteboard(name: name).string(forType: .string) == "src/App.swift:12 — this allocates per row")
    }

    /// A second copy replaces the first rather than being refused, which is the whole reason
    /// `clearContents()` is there — a board still holding an older declaration rejects the write, and
    /// what a reader would paste is the review they copied before the one they meant.
    @Test
    func `given a review already copied when copying a second one then the second replaces it`() {
        let name = NSPasteboard.Name("dev.fardavide.granita.tests.review.twice")
        defer { NSPasteboard(name: name).releaseGlobally() }
        let pasteboard = SystemReviewPasteboard(name: name)

        pasteboard.copy("the first review")
        pasteboard.copy("the second review")

        #expect(NSPasteboard(name: name).string(forType: .string) == "the second review")
    }
    #endif
}
