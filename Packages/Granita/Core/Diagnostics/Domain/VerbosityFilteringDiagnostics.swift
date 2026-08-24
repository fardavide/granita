/// Drops the detail when nobody has asked for it, and passes everything else through.
///
/// **The decision lives here rather than in the thing that writes to the system log**, which is the
/// same split `SystemSettingsPane` and `AppKitSystemGestures` already make: the spelling is a pure
/// function and stays measured, while the call on the running system is a shim with nothing in it to
/// be wrong. A gate buried in the writer would be a decision no test could put a question to.
///
/// The verbosity is read per line rather than captured, because the switch that moves it is on a
/// Settings pane and the server reading it has been running since launch. A copy taken at
/// composition time would mean the switch did nothing until the app was restarted.
public struct VerbosityFilteringDiagnostics: Diagnostics {

    private let wrapped: any Diagnostics
    private let verbosity: any VerboseLogging

    public init(wrapped: any Diagnostics, verbosity: any VerboseLogging) {
        self.wrapped = wrapped
        self.verbosity = verbosity
    }

    /// Never dropped. What this records is what went wrong, and a reader who has to turn something
    /// on before a failure is written down finds out too late by definition.
    public func note(_ message: String, about subject: DiagnosticSubject) {
        wrapped.note(message, about: subject)
    }

    public func detail(_ message: String, about subject: DiagnosticSubject) {
        guard verbosity.isVerbose else { return }
        wrapped.detail(message, about: subject)
    }
}
