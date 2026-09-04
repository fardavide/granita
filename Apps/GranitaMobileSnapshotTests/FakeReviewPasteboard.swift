import ClientViewerDomain

/// A pasteboard that keeps what it was handed, so recording a baseline never writes into the
/// simulator's own.
///
/// The bundle's own copy rather than the package's: a test target's doubles are not a product, so
/// nothing here can import the one `ClientViewerPresentationTests` holds.
final class FakeReviewPasteboard: ReviewPasteboard, @unchecked Sendable {

    private(set) var copied: String?

    init() {}

    func copy(_ text: String) {
        copied = text
    }
}
