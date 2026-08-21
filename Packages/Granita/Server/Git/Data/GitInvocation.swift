import Foundation

import ServerGitDomain

/// How a ``GitCommand`` is spelled for the git binary.
///
/// Separated from the client that runs it because this is the part worth asserting: SPEC §5.1 asks
/// for the argument array of each command family, not for the command to be seen succeeding. The
/// difference matters because `git rev-parse --no-color --show-toplevel` exits 0 and prints
/// `--no-color` as an output line, so a vector that returns garbage passes any test that reads only
/// the exit status.
enum GitInvocation {

    /// The prefix every invocation carries.
    ///
    /// A developer's global configuration reaches a child process whatever we do, and a pager, a
    /// colour setting or a quoting rule would each rewrite the output we are about to parse.
    private static let globalPrefix = [
        "-c", "core.pager=cat",
        "-c", "color.ui=false",
        "-c", "core.quotePath=false",
        "--no-pager"
    ]

    /// The flags only the diff family accepts, placed immediately after the subcommand.
    ///
    /// Immediately after, rather than at the end, because everything past `--` is a pathspec: a
    /// flag appended to a vector that ends in a path would be read as the name of another file.
    ///
    /// The two prefixes are pinned for a reason that produces no error anywhere when it goes wrong.
    /// The parser strips a leading `a/` and `b/` from every path it reads, and both strings are
    /// configurable — `diff.noprefix` removes them, which takes the first two characters off every
    /// path in the product, and `diff.mnemonicPrefix` spells them `i/`, `w/` and `c/` instead.
    private static let diffFamilySuffix = [
        "--no-ext-diff",
        "--no-color",
        "--src-prefix=a/",
        "--dst-prefix=b/"
    ]

    /// Everything the environment of a git child process must say.
    ///
    /// A `nil` unsets the variable. The three that are unset would each silently redirect the
    /// command at a different repository than the working directory names, and any of them can be
    /// in the environment already when the Mac app is launched from a shell.
    static let environmentOverrides: [String: String?] = [
        // Read operations never take the index lock, so a refresh never fights the agent's own
        // session. The cost is that status cannot write back a refreshed index and so re-stats the
        // worktree each time, which is what the per-worktree rate limit is for.
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_DIR": nil,
        "GIT_WORK_TREE": nil,
        "GIT_INDEX_FILE": nil
    ]

    /// Arguments after the executable, in bytes.
    ///
    /// Bytes rather than strings because a path on disk is bytes and is not necessarily valid
    /// UTF-8. Decoding one to re-invoke on it would substitute a replacement character and address
    /// a file that does not exist.
    static func arguments(for command: GitCommand) -> [[UInt8]] {
        encoded(globalPrefix) + subcommandArguments(for: command)
    }

    /// Which exit codes this command counts as having answered.
    ///
    /// Two families answer by failing. `git diff` exits 1 when it found differences, which is the
    /// normal case and the only case for an untracked file rendered as a full addition; and
    /// `rev-parse --verify --quiet HEAD` exits 1 in a repository that has no commits yet, where an
    /// empty answer is the answer. Everything else means git refused.
    static func accepts(exitCode: Int32, from command: GitCommand) -> Bool {
        switch command {
        case .trackedChanges, .trackedStats, .fileDiff, .untrackedFileDiff, .fileContent:
            exitCode == 0 || exitCode == 1
        case .headCommit:
            exitCode == 0 || exitCode == 1
        case .isInsideWorkTree, .repositoryRoot, .currentBranch, .worktrees, .untrackedPaths,
             .worktreeStatus, .hashWorktreeFiles:
            exitCode == 0
        }
    }

    private static func subcommandArguments(for command: GitCommand) -> [[UInt8]] {
        switch command {
        case .isInsideWorkTree:
            encoded(["rev-parse", "--is-inside-work-tree"])

        case .repositoryRoot:
            encoded(["rev-parse", "--show-toplevel"])

        case .currentBranch:
            encoded(["rev-parse", "--abbrev-ref", "HEAD"])

        case .headCommit:
            encoded(["rev-parse", "--verify", "--quiet", "HEAD"])

        case .worktrees:
            encoded(["worktree", "list", "--porcelain", "-z"])

        case .untrackedPaths:
            encoded(["ls-files", "--others", "--exclude-standard", "-z"])

        case .worktreeStatus:
            // Everything after `-z` is git's own default, pinned because each has a configuration
            // key that changes it and this output is hashed into the revision the phone polls.
            // The untracked mode is the one that matters most: `no` empties it, and the collapsed
            // default reports an untracked directory as a single line that does not move when a
            // second file appears inside it.
            encoded([
                "status",
                "--porcelain=v2",
                "-z",
                "--renames",
                "--untracked-files=all",
                "--no-branch",
                "--no-show-stash"
            ])

        case .trackedChanges(let revision):
            encoded(["diff"] + diffFamilySuffix + [spelling(of: revision), "-z", "-M", "--raw"])

        case .trackedStats(let revision):
            encoded(["diff"] + diffFamilySuffix + [spelling(of: revision), "-z", "-M", "--numstat"])

        case .fileDiff(let path, let revision, let contextLines):
            encoded(["diff"] + diffFamilySuffix + [spelling(of: revision), "-U\(contextLines)", "--"])
                + [Array(path.bytes)]

        case .untrackedFileDiff(let path, let contextLines):
            encoded(["diff"] + diffFamilySuffix + ["--no-index", "-U\(contextLines)", "--", "/dev/null"])
                + [Array(path.bytes)]

        case .fileContent(let path, let revision):
            encoded(["show"] + diffFamilySuffix)
                + [Array("\(spelling(of: revision)):".utf8) + Array(path.bytes)]

        case .hashWorktreeFiles:
            encoded(["hash-object", "--stdin-paths"])
        }
    }
}

extension GitInvocation {

    /// What this command reads on standard input, if anything.
    ///
    /// Only one command does. `--stdin-paths` takes **one path per line**, so a path containing a
    /// newline would arrive as two paths and shift every object id after it by one — which is a
    /// wrong content hash for every remaining file, and a wrong content hash silently un-marks a
    /// file the reader had marked viewed. Git unquotes a line beginning with a double quote using
    /// C escapes, so such a path is quoted on the way in.
    static func standardInput(for command: GitCommand) -> Data? {
        guard case .hashWorktreeFiles(let paths) = command else { return nil }
        var input = Data()
        for path in paths {
            input.append(contentsOf: quotedIfNeeded(path.bytes))
            input.append(UInt8(ascii: "\n"))
        }
        return input
    }

    private static func quotedIfNeeded(_ bytes: Data) -> Data {
        let needsQuoting = bytes.contains { byte in
            byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\\")
        } || bytes.first == UInt8(ascii: "\"")
        guard needsQuoting else { return bytes }

        var quoted = Data([UInt8(ascii: "\"")])
        for byte in bytes {
            switch byte {
            case UInt8(ascii: "\n"): quoted.append(contentsOf: Data("\\n".utf8))
            case UInt8(ascii: "\r"): quoted.append(contentsOf: Data("\\r".utf8))
            case UInt8(ascii: "\\"): quoted.append(contentsOf: Data("\\\\".utf8))
            case UInt8(ascii: "\""): quoted.append(contentsOf: Data("\\\"".utf8))
            default: quoted.append(byte)
            }
        }
        quoted.append(UInt8(ascii: "\""))
        return quoted
    }
}

private func encoded(_ arguments: [String]) -> [[UInt8]] {
    arguments.map { Array($0.utf8) }
}

private func spelling(of revision: GitRevision) -> String {
    switch revision {
    case .head:
        "HEAD"
    // Git's empty tree, which every repository has whether or not anything was ever written to it.
    // It is a constant of the object format rather than a value read from this repository.
    case .emptyTree:
        "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    }
}
