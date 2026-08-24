/// Where Granita says what it is doing.
///
/// **Nothing in this product wrote a log until now** — no `Logger`, no `os.log`, not a print, the
/// whole package searched. Design §7 draws a verbose switch and an *Open in Console* button over a
/// subsystem that emitted nothing, and both were held back for that reason: a control over an absent
/// subsystem reads as a feature, gets pressed, and answers with a silence that looks like *nothing is
/// wrong*.
///
/// Two methods rather than five syslog levels, because design §7 settled that too: five levels are a
/// vocabulary for reading someone else's logs, and there is one reader here who wants either the
/// normal amount or all of it.
public protocol Diagnostics: Sendable {

    /// Worth a line whatever the setting — a refusal, a failure, a server that could not bind.
    func note(_ message: String, about subject: DiagnosticSubject)

    /// Only for a reader who has asked for it: every request and every git invocation, which is
    /// what design §7's footnote promises the switch turns on.
    func detail(_ message: String, about subject: DiagnosticSubject)
}

/// What a line is about, which becomes the category a reader filters Console by.
///
/// The two the footnote names and no more. A subject nothing writes to is a filter that answers
/// empty, and this list is meant to be short enough to read rather than complete enough to cover
/// every file.
public enum DiagnosticSubject: String, Hashable, Sendable, CaseIterable {

    /// Every request the server answered, and what it answered with.
    case requests

    /// Every invocation of the git binary, and whether it worked.
    case git
}

/// Whether the reader has asked for everything.
///
/// A seam rather than a `Bool` handed in at launch, because the switch that moves it is on a
/// Settings pane and the thing that reads it is a server already running: a value copied at
/// composition time would mean the switch did nothing until the app was restarted, which is a
/// control that appears to do nothing.
public protocol VerboseLogging: Sendable {

    var isVerbose: Bool { get }

    func setVerbose(_ isVerbose: Bool)
}
