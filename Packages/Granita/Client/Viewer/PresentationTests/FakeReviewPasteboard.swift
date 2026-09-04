import ClientViewerDomain

/// A pasteboard that keeps what it was handed, so a test can ask the one question *Copy review* has:
/// did the string the reader is about to paste come out of the model.
///
/// A class rather than a struct because the point of it is what was written, and the model holds its
/// pasteboard by value the way it holds everything else.
// Only ever touched from the main actor: the model that calls it is main-actor isolated and every
// test in this bundle is a `@MainActor` suite. That is the invariant the compiler cannot see.
final class FakeReviewPasteboard: ReviewPasteboard, @unchecked Sendable {

    private(set) var copied: String?

    init() {}

    func copy(_ text: String) {
        copied = text
    }
}
