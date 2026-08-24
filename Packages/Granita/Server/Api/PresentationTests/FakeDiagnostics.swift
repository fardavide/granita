import Foundation

import CoreDiagnosticsDomain

/// Everything the server said about the requests it answered.
///
/// A class behind a lock rather than an actor, because the protocol it implements is synchronous —
/// a log line is written from wherever the thing happened, and making that an `await` would put a
/// suspension point inside every request and every git invocation.
///
/// Its own copy, because SwiftPM test targets cannot import each other.
final class FakeDiagnostics: Diagnostics, @unchecked Sendable {

    private let lock = NSLock()
    private var recordedNotes: [String] = []
    private var recordedDetails: [String] = []

    var notes: [String] {
        lock.withLock { recordedNotes }
    }

    var details: [String] {
        lock.withLock { recordedDetails }
    }

    func note(_ message: String, about subject: DiagnosticSubject) {
        lock.withLock { recordedNotes.append(message) }
    }

    func detail(_ message: String, about subject: DiagnosticSubject) {
        lock.withLock { recordedDetails.append(message) }
    }
}
