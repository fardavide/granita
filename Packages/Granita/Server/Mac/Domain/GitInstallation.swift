/// Which git this Mac would run, and whether running it works.
///
/// Design §7 asks the Advanced row for a version rather than a path, and the reason is that the path
/// is never the interesting half. `GitExecutablePath` picks the first of three candidates that is
/// executable; a path that is executable and broken — the Xcode command line tools pointing at a
/// developer directory that has been deleted is the ordinary way — looks exactly like a working one
/// until something runs it. So the row runs it, reads the version first and the path second, and in
/// failure carries git's own standard error, which is the rule the whole git API already follows.
public enum GitInstallation: Hashable, Sendable {

    /// Nothing has asked yet. Drawn rather than hidden, because this row is always present and a
    /// row that appears a moment after the pane does reads as a glitch.
    case checking

    case available(version: String, path: String)

    /// Whatever was found could not answer, in its own words.
    case unavailable(reason: String)

    /// Reads `git --version`.
    ///
    /// git answers `git version 2.52.0`, and Apple's answers `git version 2.39.5 (Apple Git-154)`
    /// — where the build suffix is longer than the number and is not what the row is asking. The
    /// third whitespace-separated word is the version in both.
    ///
    /// **Exiting 0 is not enough to call this working**, which is why the shape is checked rather
    /// than trusted: the candidates are paths, and a path that is executable and is not git exits 0
    /// and prints something. A row reading `Python 3.14.7` under the word `git` would be worse than
    /// the failure it is hiding.
    public static func reading(_ versionOutput: String, at path: String) -> GitInstallation {
        let words = versionOutput.split(whereSeparator: \.isWhitespace)
        guard words.isEmpty == false else {
            return .unavailable(reason: "git printed no version.")
        }
        guard words.count >= 3, words[0] == "git", words[1] == "version" else {
            return .unavailable(reason: words.joined(separator: " "))
        }
        return .available(version: String(words[2]), path: path)
    }
}

/// Which git is installed, behind a protocol like every other edge that leaves this process.
///
/// A read rather than a stored value: the answer changes when Xcode's command line tools are
/// installed, moved or removed, none of which Granita is running for.
public protocol GitInstallations: Sendable {

    func current() async -> GitInstallation
}
