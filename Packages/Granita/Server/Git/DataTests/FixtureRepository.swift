import Foundation

import ServerGitDomain

/// One of the repositories `make fixtures` builds under `.fixtures/`.
///
/// They are gitignored and disposable, so a fresh checkout has none of them and the failure has to
/// say what to run rather than reading as a broken test.
enum FixtureRepository: String {

    /// Every parser case at once, plus two linked worktrees.
    case main

    /// No commits at all, where `git diff HEAD` fails and everything else carries on.
    case unborn

    /// A merge left in conflict, which is what an agent running a rebase leaves behind.
    case conflicted

    /// A rename, whose paths the two `-z` formats report in opposite orders.
    case renames

    /// Configured the way a developer configures a repository — an external diff tool, forced
    /// colour, no path prefixes, octal-escaped paths, hidden untracked files. Nothing here is
    /// asserted for its own sake: it exists so the invocation hardening can be proven to work
    /// rather than assumed, which no other fixture can do.
    case hostile

    func location() throws -> RepositoryLocation {
        let root = try Self.fixtureRoot()
        // No directory hint, so the path carries no trailing separator: git reports a checkout's
        // root without one, and a location that compares unequal to git's own answer is a location
        // no test could assert against.
        let path = root.appending(path: rawValue, directoryHint: .notDirectory)
        guard FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) else {
            throw MissingFixtures()
        }
        // Resolved, because git reports a worktree's location with symlinks resolved and on macOS
        // the temporary directories these are sometimes built under live below a symlinked /var.
        // An unresolved path here compares unequal to the one git hands back.
        return RepositoryLocation(path: path.resolvingSymlinksInPath().path(percentEncoded: false))
    }

    private static func fixtureRoot() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
        while directory.path(percentEncoded: false) != "/" {
            let candidate = directory.appending(path: ".fixtures", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
            directory = directory.deletingLastPathComponent()
        }
        throw MissingFixtures()
    }
}

struct MissingFixtures: Error, CustomStringConvertible {
    var description: String {
        "the git fixture repositories are absent from this checkout — run `make fixtures`"
    }
}
