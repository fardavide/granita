import Foundation

import ServerGitDomain
import ServerMacDomain

/// Which git is installed, answered by running it.
///
/// Through the same `GitClient` the rest of the product asks its questions through, so this row
/// reports the binary that actually serves the phone rather than a second guess at which one that
/// is. `GitExecutablePath` chose it; this runs it.
public struct ProcessGitInstallations: GitInstallations {

    private let git: any GitClient
    private let executablePath: String
    private let probeLocation: RepositoryLocation

    /// The location is a working directory for the child process and nothing more. `git --version`
    /// is the one question here that is not about a repository, so any readable directory does —
    /// and the home directory is the one that is certain to exist.
    public init(git: any GitClient, executablePath: String) {
        self.git = git
        self.executablePath = executablePath
        probeLocation = RepositoryLocation(path: NSHomeDirectory())
    }

    public func current() async -> GitInstallation {
        do {
            let output = try await git.run(.version, in: probeLocation)
            return GitInstallation.reading(
                String(decoding: output.standardOutput, as: UTF8.self),
                at: executablePath
            )
        } catch {
            return .unavailable(reason: sentence(for: error))
        }
    }

    /// git's own words wherever git got far enough to write any, and the system's where it did not.
    ///
    /// The distinction is the whole value of the row. `xcrun: error: invalid active developer path`
    /// comes from the shim at `/usr/bin/git` and is what tells a reader to install the command line
    /// tools; "No such file or directory" for the same situation would not.
    private func sentence(for error: GitError) -> String {
        switch error {
        case .gitUnavailable(let reason): reason
        case .workingDirectoryUnreadable(_, let reason): reason
        case .commandFailed(_, _, let standardError): standardError
        case .terminatedBySignal(_, let signal, let standardError):
            standardError.isEmpty ? "git was killed by signal \(signal)." : standardError
        case .timedOut: "git did not answer in time."
        }
    }
}
