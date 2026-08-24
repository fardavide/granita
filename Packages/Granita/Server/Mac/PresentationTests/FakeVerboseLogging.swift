import CoreDiagnosticsDomain

/// The verbose switch as somebody left it, and a record of the switch being moved.
///
/// Its own copy rather than the one `CoreDiagnosticsDomain`'s tests use, which is the convention
/// every fake here follows: a test target owns its doubles, so a module's tests never depend on
/// another module's test target.
///
/// Synchronous, because the protocol is. A `Toggle`'s `Binding` has nowhere to put an `await`, and
/// the real conformer is `UserDefaults`, which answers from memory.
final class FakeVerboseLogging: VerboseLogging, @unchecked Sendable {

    private(set) var isVerbose: Bool

    init(isVerbose: Bool) {
        self.isVerbose = isVerbose
    }

    func setVerbose(_ isVerbose: Bool) {
        self.isVerbose = isVerbose
    }
}
