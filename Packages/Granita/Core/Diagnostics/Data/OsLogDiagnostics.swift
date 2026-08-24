import Foundation
import os

import CoreBrandingDomain
import CoreDiagnosticsDomain

/// The system log, which is where design §7 sends a reader: *Open in Console*, filtered to this
/// subsystem.
///
/// **A shim with no decisions in it.** Whether a line survives the verbose switch is
/// `VerbosityFilteringDiagnostics`, one layer in, for the same reason the Settings pane spellings
/// live apart from the AppKit calls that use them: a pure function stays measured and a call on the
/// running system has nothing in it to be wrong.
///
/// `os.Logger` rather than a file of our own, because the button this exists for opens Console and
/// Console reads the unified log. A file would need writing, rotating, and a second answer to *where
/// is it*.
public struct OsLogDiagnostics: Diagnostics {

    /// One `Logger` per subject, made once. `Logger` is cheap to construct and this is not an
    /// optimisation — it is so that the category a reader filters by is spelled in exactly one place.
    private let loggers: [DiagnosticSubject: Logger]

    public init(subsystem: String = Branding.loggingSubsystem) {
        loggers = Dictionary(
            uniqueKeysWithValues: DiagnosticSubject.allCases.map {
                ($0, Logger(subsystem: subsystem, category: $0.rawValue))
            }
        )
    }

    /// `.notice` rather than `.error`, because a note is not necessarily a fault: it is the level
    /// the unified log persists by default, which is the property that matters when the reason to
    /// look is that something happened an hour ago.
    public func note(_ message: String, about subject: DiagnosticSubject) {
        // Public, deliberately and narrowly. `os.Logger` redacts interpolated values by default,
        // and a log of `<private>` is the failure mode this whole slice exists to prevent. What
        // reaches these two calls is a command name, a path on this Mac, a method and a status —
        // never git's standard output, which the git decorator is explicit about withholding.
        loggers[subject]?.notice("\(message, privacy: .public)")
    }

    public func detail(_ message: String, about subject: DiagnosticSubject) {
        loggers[subject]?.debug("\(message, privacy: .public)")
    }
}
