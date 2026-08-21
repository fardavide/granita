import Foundation

/// Where the `git` binary is.
///
/// SPEC §5.1 wants `/usr/bin/git`, then `xcrun -f git`, then the path. Only the first and last of
/// those are a filesystem question; the middle step is itself a subprocess and wants its own seam,
/// so it is not here yet. What is here is shared by both composition roots, because a terminal and
/// a menu bar app disagreeing about which git they run is a difference nobody would think to look
/// for.
public enum GitExecutablePath {

    /// The shim every Mac has, then the two places a developer's own git usually lives.
    public static let defaultCandidates = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]

    /// The first candidate that is there and can be run, or nothing.
    ///
    /// Nothing rather than a plausible default: a path with no binary at it fails on the first
    /// diff, several layers away from the machine that has no git on it.
    public static func firstAvailable(among candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
