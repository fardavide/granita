import CoreDiagnosticsDomain

/// Everything that was said, kept apart by whether it survives the verbose switch being off.
///
/// Two lists rather than one with a flag, because every question asked of this is "did that reach a
/// log the reader will see" — and answering it from one list means re-deriving the split the subject
/// under test just made.
final class FakeDiagnostics: Diagnostics, @unchecked Sendable {

    private(set) var notes: [String] = []
    private(set) var details: [String] = []
    private(set) var subjects: [DiagnosticSubject] = []

    func note(_ message: String, about subject: DiagnosticSubject) {
        notes.append(message)
        subjects.append(subject)
    }

    func detail(_ message: String, about subject: DiagnosticSubject) {
        details.append(message)
        subjects.append(subject)
    }
}

/// A switch somebody already set, and a record of anyone moving it.
final class FakeVerboseLogging: VerboseLogging, @unchecked Sendable {

    private(set) var isVerbose: Bool

    init(isVerbose: Bool) {
        self.isVerbose = isVerbose
    }

    func setVerbose(_ isVerbose: Bool) {
        self.isVerbose = isVerbose
    }
}
