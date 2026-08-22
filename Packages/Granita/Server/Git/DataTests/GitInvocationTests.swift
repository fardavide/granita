import Foundation
import Testing

import ServerGitDomain
@testable import ServerGitData

/// SPEC §5.1 asks for the argument **array** of each command family to be asserted, rather than for
/// the command merely to be observed succeeding, and `git rev-parse --no-color --show-toplevel` is
/// the reason: it exits 0 and emits `--no-color` as an output line, so a test that reads the exit
/// status passes on a vector that returns garbage.
@Suite("Git invocation")
struct GitInvocationTests {

    // MARK: - The prefix every invocation carries

    @Test
    func `when any command is built then it is hardened against the developer's own configuration`() {
        // given - when
        let vector = arguments(of: .isInsideWorkTree)

        // then
        #expect(vector == [
            "-c", "core.pager=cat",
            "-c", "color.ui=false",
            "-c", "core.quotePath=false",
            "--no-pager",
            "rev-parse", "--is-inside-work-tree"
        ])
    }

    @Test
    func `when git's own version is asked for then it is asked of the binary rather than of a checkout`() {
        // given - when
        let vector = arguments(of: .version)

        // then — the only question here that is about the *installation* rather than about a
        // repository, which is why Advanced can ask it from a folder that is not one.
        #expect(vector.suffix(1) == ["--version"])
    }

    @Test
    func `when rev-parse is built then it carries no diff-family flag`() {
        // given - when
        let vector = arguments(of: .repositoryRoot)

        // then — rev-parse accepts --no-color by printing it as an output line, so the flag would
        // turn the repository root into the string "--no-color" with nothing failing anywhere.
        #expect(vector.contains("--no-color") == false)
        #expect(vector.contains("--no-ext-diff") == false)
        #expect(vector.suffix(2) == ["rev-parse", "--show-toplevel"])
    }

    @Test
    func `when the current branch is asked for then rev-parse abbreviates the ref`() {
        // given - when
        let vector = arguments(of: .currentBranch)

        // then
        #expect(vector.suffix(3) == ["rev-parse", "--abbrev-ref", "HEAD"])
    }

    @Test
    func `when the head commit is asked for then rev-parse is quiet about a repository with no commits`() {
        // given - when
        let vector = arguments(of: .headCommit)

        // then — the quiet form is what turns an unborn HEAD into an empty answer rather than into
        // a message on standard error that a caller would have to read to know it asked too early.
        #expect(vector.suffix(4) == ["rev-parse", "--verify", "--quiet", "HEAD"])
    }

    // MARK: - The subcommands that reject the diff-family flags outright

    @Test
    func `when the worktrees are listed then the records are NUL separated`() {
        // given - when
        let vector = arguments(of: .worktrees)

        // then — `-z` is only offered alongside `--porcelain`, and both are needed: a worktree path
        // is bytes, and a listing split on newlines merges any path containing one.
        #expect(vector.suffix(4) == ["worktree", "list", "--porcelain", "-z"])
        #expect(vector.contains("--no-ext-diff") == false)
    }

    @Test
    func `when untracked paths are listed then ignored files stay out of the answer`() {
        // given - when
        let vector = arguments(of: .untrackedPaths)

        // then
        #expect(vector.suffix(4) == ["ls-files", "--others", "--exclude-standard", "-z"])
        #expect(vector.contains("--no-ext-diff") == false)
    }

    @Test
    func `when the worktree status is asked for then every configurable part of it is pinned`() {
        // given - when
        let vector = arguments(of: .worktreeStatus)

        // then — this output is hashed into the worktree's revision, which is what tells the phone
        // something moved. `status.showUntrackedFiles` alone can empty it; the collapsed default
        // reports an untracked directory as one unchanged line however many files appear inside it.
        #expect(vector.suffix(7) == [
            "status",
            "--porcelain=v2",
            "-z",
            "--renames",
            "--untracked-files=all",
            "--no-branch",
            "--no-show-stash"
        ])
    }

    // MARK: - The diff family

    @Test
    func `when a diff-family command is built then the path prefixes are pinned`() {
        // given - when
        let vector = arguments(of: .trackedChanges(against: .head))

        // then — the parser strips a leading `a/` and `b/` from every path, and both are
        // configurable. `diff.noprefix` is set in Davide's own configuration and would take the
        // first two characters off every path in the product, with nothing failing anywhere;
        // `diff.mnemonicPrefix` would spell them `i/`, `w/` and `c/` instead.
        #expect(vector.suffix(9) == [
            "diff", "--no-ext-diff", "--no-color", "--src-prefix=a/", "--dst-prefix=b/",
            "HEAD", "-z", "-M", "--raw"
        ])
    }

    @Test
    func `when the change set is asked for then its stats come from the same comparison`() {
        // given - when
        let changes = arguments(of: .trackedChanges(against: .head))
        let stats = arguments(of: .trackedStats(against: .head))

        // then — the two differ in their last argument and nowhere else. A change set from one
        // comparison and stats from another detect renames separately and disagree routinely: a
        // staged delete plus an unstaged add is one rename to one of them and two entries to the
        // other, which shows up as files with no stats and totals that do not add up.
        #expect(changes.dropLast() == stats.dropLast())
        #expect(changes.last == "--raw")
        #expect(stats.last == "--numstat")
    }

    @Test
    func `given a repository with no commits when diffing then the empty tree stands in for HEAD`() {
        // given - when
        let vector = arguments(of: .trackedChanges(against: .emptyTree))

        // then — `git diff HEAD` exits 128 in a repository that has none, while every other command
        // carries on. Against this object the same comparison renders the checkout as an addition.
        #expect(vector.contains("HEAD") == false)
        #expect(vector.contains("4b825dc642cb6eb9a060e54bf8d69288fbee4904"))
    }

    @Test
    func `given a file when diffing it then the diff flags stay on the option side of the separator`() {
        // given
        let path = RepositoryRelativePath("src/deep/a file with spaces.txt")

        // when
        let vector = arguments(of: .fileDiff(path: path, against: .head, contextLines: 5))

        // then — everything after `--` is a pathspec, so a flag appended to the end of the vector
        // would be read as the name of a file to diff rather than as an option.
        #expect(vector.suffix(9) == [
            "diff", "--no-ext-diff", "--no-color", "--src-prefix=a/", "--dst-prefix=b/",
            "HEAD", "-U5", "--", "src/deep/a file with spaces.txt"
        ])
    }

    @Test
    func `given an untracked file when diffing it then it is compared against nothing`() {
        // given
        let path = RepositoryRelativePath("src/untracked.txt")

        // when
        let vector = arguments(of: .untrackedFileDiff(path: path, contextLines: 3))

        // then — an untracked file has no side in HEAD, so it is rendered as a full addition
        // against the null device. That comparison exits 1 when the files differ, which is every
        // time, and 1 is success for this family.
        #expect(vector.suffix(5) == ["--no-index", "-U3", "--", "/dev/null", "src/untracked.txt"])
    }

    @Test
    func `given a file when asking for its committed side then the revision and the path are one argument`() {
        // given
        let path = RepositoryRelativePath("src/modified.txt")

        // when
        let vector = arguments(of: .fileContent(path: path, at: .head))

        // then — `show` takes one object name rather than a revision and a pathspec, so the two are
        // joined by a colon into a single argument and there is no `--` to put anything after.
        #expect(vector.suffix(6) == [
            "show", "--no-ext-diff", "--no-color", "--src-prefix=a/", "--dst-prefix=b/",
            "HEAD:src/modified.txt"
        ])
    }

    @Test
    func `given a path git cannot decode when diffing it then its bytes reach the command unchanged`() {
        // given — a lone 0xFF is not valid UTF-8 in any position, and filesystems accept it.
        let bytes = Data([0x73, 0x72, 0x63, 0x2F, 0xFF, 0x2E, 0x74, 0x78, 0x74])
        let path = RepositoryRelativePath(bytes: bytes)

        // when
        let vector = GitInvocation.arguments(for: .fileDiff(path: path, against: .head, contextLines: 3))

        // then — decoding the path to build the vector would substitute a replacement character
        // and address a file that does not exist.
        #expect(vector.last.map { Data($0) } == bytes)
    }

    // MARK: - Hashing the working tree

    @Test
    func `when worktree files are hashed then the paths go in on standard input`() {
        // given
        let paths = [RepositoryRelativePath("src/one.txt"), RepositoryRelativePath("src/two.txt")]

        // when
        let vector = arguments(of: .hashWorktreeFiles(paths: paths))

        // then — one process for the whole change set. A thousand-file worktree refreshing every
        // 400 ms cannot afford a process per file, and reading and hashing the bytes ourselves
        // would be the real I/O the batch exists to avoid.
        #expect(vector.suffix(2) == ["hash-object", "--stdin-paths"])
    }

    @Test
    func `given ordinary paths when hashing then standard input is one path per line`() {
        // given
        let paths = [RepositoryRelativePath("a.txt"), RepositoryRelativePath("dir/b.txt")]

        // when
        let input = GitInvocation.standardInput(for: .hashWorktreeFiles(paths: paths))

        // then
        #expect(input.map { String(decoding: $0, as: UTF8.self) } == "a.txt\ndir/b.txt\n")
    }

    @Test
    func `given a path with a newline in it when hashing then it is quoted rather than split in two`() {
        // given — `--stdin-paths` reads one path per line, so a path containing a newline is two
        // paths to git and the whole batch shifts by one from there on.
        let paths = [RepositoryRelativePath("od\nd.txt"), RepositoryRelativePath("after.txt")]

        // when
        let input = GitInvocation.standardInput(for: .hashWorktreeFiles(paths: paths))

        // then — git unquotes a line that starts with a double quote, using C escapes.
        #expect(input.map { String(decoding: $0, as: UTF8.self) } == "\"od\\nd.txt\"\nafter.txt\n")
    }

    @Test
    func `given a command that reads nothing when asked for its input then there is none`() {
        // given - when - then
        #expect(GitInvocation.standardInput(for: .worktreeStatus) == nil)
    }

    // MARK: - The environment every child process is given

    @Test
    func `when a child process is prepared then it never takes the index lock or asks for a password`() {
        // given - when
        let environment = GitInvocation.environmentOverrides

        // then — an agent is running git in the same worktree at the same time, and a read that
        // takes the lock fights it. A prompt has no terminal to appear on and would hang instead.
        #expect(environment["GIT_OPTIONAL_LOCKS"] == "0")
        #expect(environment["GIT_TERMINAL_PROMPT"] == "0")
    }

    @Test
    func `when a child process is prepared then an inherited repository pointer is cleared`() {
        // given - when
        let environment = GitInvocation.environmentOverrides

        // then — each of these overrides the working directory, so one left in the environment by
        // whatever launched the Mac app would answer every question about a different repository.
        // A key mapped to nil is a variable removed, which is not the same as one set to empty.
        #expect(environment["GIT_DIR"] == .some(nil))
        #expect(environment["GIT_WORK_TREE"] == .some(nil))
        #expect(environment["GIT_INDEX_FILE"] == .some(nil))
    }
}

/// The vector as text.
///
/// Arguments are bytes, because a path on disk is bytes and is not necessarily valid UTF-8. Only
/// the test that passes such a path needs to see them that way; every other assertion reads better
/// against the spelling a person would type.
private func arguments(of command: GitCommand) -> [String] {
    GitInvocation.arguments(for: command).map { String(decoding: $0, as: UTF8.self) }
}
