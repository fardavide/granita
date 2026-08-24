import CoreDiagnosticsDomain

/// Everything that was said, kept apart by whether the verbose switch can suppress it.
///
/// A second copy of the one in `Core/Diagnostics/DomainTests`, because SwiftPM test targets cannot
/// import each other.
final class FakeDiagnostics: Diagnostics, @unchecked Sendable {

    private(set) var notes: [String] = []
    private(set) var details: [String] = []

    func note(_ message: String, about subject: DiagnosticSubject) {
        notes.append(message)
    }

    func detail(_ message: String, about subject: DiagnosticSubject) {
        details.append(message)
    }
}
