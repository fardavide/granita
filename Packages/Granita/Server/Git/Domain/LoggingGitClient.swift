import CoreDiagnosticsDomain

/// Says what git was asked and how it answered, around whichever client actually runs it.
///
/// **A decorator rather than a dependency threaded through `ProcessGitClient`**, and that is the
/// shape `RebindingOnWake` already uses on the host: the thing that runs a subprocess keeps having
/// exactly one job, this has the other, and both are asserted on their own. It also means a libgit2
/// client — the reason `GitClient` is a protocol at all — arrives logged without knowing it.
///
/// It lives in `Domain` beside the protocol it wraps because there is no I/O in it. Everything here
/// is two calls on seams, which is what makes "did a failed invocation say so" a question with an
/// answer rather than something read off a screen.
public struct LoggingGitClient: GitClient {

    private let client: any GitClient
    private let diagnostics: any Diagnostics

    public init(client: any GitClient, diagnostics: any Diagnostics) {
        self.client = client
        self.diagnostics = diagnostics
    }

    /// **The command and where it ran, never what it said back.** Git's standard output here is the
    /// contents of a private repository, and the whole product exists to keep that on one machine —
    /// writing it into the system log would put it somewhere with a different lifetime and different
    /// readers than the thing it was taken from. A failure carries git's own standard error, which
    /// is the one exception and the rule the rest of this layer already follows: it is a sentence
    /// written for a person.
    public func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        diagnostics.detail("\(command) in \(location.path)", about: .git)
        do {
            let output = try await client.run(command, in: location)
            diagnostics.detail("\(command) answered", about: .git)
            return output
        } catch {
            // A note rather than detail: a git invocation that failed is why somebody is reading
            // this at all, and it must not be behind a switch they had to think of first.
            //
            // **Git's own words come first, and the command trails.** The unified log truncates at
            // about a kilobyte, and a command carrying a batch of paths is easily longer than that
            // — so a line that led with the command spent its whole budget on the paths and cut off
            // before the one sentence written for a person. Measured rather than reasoned: a
            // failing `hash-object` had to be reproduced by hand because its stderr never reached
            // the log.
            diagnostics.note("git failed: \(sentence(for: error)) — running \(command) in \(location.path)", about: .git)
            throw error
        }
    }

    /// What git said, or what stopped it saying anything.
    private func sentence(for error: GitError) -> String {
        switch error {
        case .commandFailed(_, let exitCode, let standardError):
            "exit \(exitCode): \(standardError)"
        case .terminatedBySignal(_, let signal, let standardError):
            "killed by signal \(signal): \(standardError)"
        case .timedOut:
            "timed out"
        case .gitUnavailable(let reason):
            reason
        case .workingDirectoryUnreadable(_, let reason):
            reason
        }
    }
}
