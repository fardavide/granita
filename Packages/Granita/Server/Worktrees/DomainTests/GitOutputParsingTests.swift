import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
@testable import ServerWorktreesDomain

/// The `-z` formats, asserted against bytes written out here rather than against a fixture file.
///
/// Deliberate: a record's shape is the thing under test, and a test that opens a file says less
/// about it than one that spells it out. What keeps these from encoding a belief about git rather
/// than git's behaviour is that the same records are asserted again in `WorktreeServiceTests`,
/// against the real binary reading the real fixture repositories.
@Suite("Git output parsing")
struct GitOutputParsingTests {

    // MARK: - worktree list --porcelain -z

    @Test
    func `given the primary checkout and two linked worktrees when parsed then each is one record`() {
        // given
        let output = nulSeparated([
            "worktree /repo", "HEAD abc123", "branch refs/heads/main", "",
            "worktree /repo/.claude/worktrees/slice", "HEAD def456",
            "branch refs/heads/worktree-slice", "",
            "worktree /elsewhere/detached", "HEAD 999aaa", "detached", ""
        ])

        // when
        let records = WorktreeListParser.parse(output)

        // then
        #expect(records.map(\.location.path) == ["/repo", "/repo/.claude/worktrees/slice", "/elsewhere/detached"])
        #expect(records[0].branch == "refs/heads/main")
        #expect(records[0].isDetached == false)
        #expect(records[2].branch == nil)
        #expect(records[2].isDetached)
    }

    @Test
    func `given a locked worktree when parsed then it is flagged whether or not it gives a reason`() {
        // given — `locked` appears bare or with a reason after it, and both mean locked.
        let output = nulSeparated([
            "worktree /a", "HEAD aaa", "branch refs/heads/one", "locked", "",
            "worktree /b", "HEAD bbb", "branch refs/heads/two", "locked on a removable disk", "",
            "worktree /c", "HEAD ccc", "branch refs/heads/three", "prunable gitdir file points nowhere", ""
        ])

        // when
        let records = WorktreeListParser.parse(output)

        // then
        #expect(records.map(\.isLocked) == [true, true, false])
        #expect(records.map(\.isPrunable) == [false, false, true])
    }

    @Test
    func `given a trailing record with no terminator when parsed then it is not dropped`() {
        // given — the last record's blank field is the one most likely to be absent, and losing it
        // loses a whole worktree rather than a field of one.
        var output = nulSeparated(["worktree /a", "HEAD aaa", "branch refs/heads/one", ""])
        output.append(contentsOf: Data("worktree /b\u{0}HEAD bbb\u{0}branch refs/heads/two".utf8))

        // when
        let records = WorktreeListParser.parse(output)

        // then
        #expect(records.count == 2)
        #expect(records[1].location.path == "/b")
    }

    // MARK: - diff HEAD -z -M --raw

    @Test
    func `given a rename in raw output when parsed then old and new are not swapped`() {
        // given — the layout git actually writes: the metadata field, then OLD, then NEW. The
        // porcelain-v2 format puts them the other way round, and copying its order here reverses
        // every rename in the product.
        let output = nulSeparated([
            ":100644 100644 600d48a 0102a25 R074", "old.txt", "new.txt",
            ":100644 100644 b9bca01 0000000 M", "plain.txt"
        ])

        // when
        let changes = RawChangeParser.parse(output)

        // then
        #expect(changes.count == 2)
        #expect(changes[0].status == .renamed)
        #expect(changes[0].oldPath?.text == "old.txt")
        #expect(changes[0].path.text == "new.txt")
        #expect(changes[1].status == .modified)
        #expect(changes[1].oldPath == nil)
        #expect(changes[1].path.text == "plain.txt")
    }

    @Test
    func `given a record whose fields count differently when parsed then the stream stays in step`() {
        // given — a rename spans three NUL fields and everything else spans two, so a reader that
        // assumes a fixed width desynchronises for the whole rest of the stream at the first one.
        let output = nulSeparated([
            ":100644 100644 aaa bbb R100", "was.txt", "is.txt",
            ":000000 100644 0000000 ccc A", "added.txt",
            ":100644 000000 ddd 0000000 D", "gone.txt"
        ])

        // when
        let changes = RawChangeParser.parse(output)

        // then
        #expect(changes.map(\.path.text) == ["is.txt", "added.txt", "gone.txt"])
        #expect(changes.map(\.status) == [.renamed, .added, .deleted])
    }

    @Test
    func `given a gitlink when parsed then it is recognised by its mode`() {
        // given
        let output = nulSeparated([":160000 160000 aaa bbb M", "vendor/sub"])

        // when
        let changes = RawChangeParser.parse(output)

        // then — only the mode says this is a submodule; the path looks like any other directory.
        #expect(changes[0].isSubmodule)
    }

    // MARK: - diff HEAD -z -M --numstat

    @Test
    func `given a rename in numstat output when parsed then the trailing tab marks it`() {
        // given — SPEC §5.3 was wrong about this and was corrected against the fixture: there is no
        // empty NUL field, the first field simply ends in a TAB and two more fields follow.
        var output = Data("1\t1\t\u{0}old.txt\u{0}new.txt\u{0}".utf8)
        output.append(contentsOf: Data("3\t4\tplain.txt\u{0}".utf8))

        // when
        let records = NumstatParser.parse(output)

        // then
        #expect(records.count == 2)
        #expect(records[0].path.text == "new.txt")
        #expect(records[0].insertions == 1)
        #expect(records[1].path.text == "plain.txt")
        #expect(records[1].insertions == 3)
        #expect(records[1].deletions == 4)
    }

    @Test
    func `given a binary file when parsed then its counts are absent rather than zero`() {
        // given — git writes a dash rather than a number, and reading it as zero would claim a
        // binary file was unchanged.
        let output = Data("-\t-\tphoto.png\u{0}".utf8)

        // when
        let records = NumstatParser.parse(output)

        // then
        #expect(records[0].insertions == nil)
        #expect(records[0].deletions == nil)
    }

    // MARK: - status --porcelain=v2 -z

    @Test
    func `given an unmerged record when parsed then its ten fields do not swallow the next record`() {
        // given — an unmerged record carries four modes and three object ids where an ordinary one
        // carries three and two, so a reader written for the ordinary shape consumes past its end.
        let output = nulSeparated([
            "u UU N... 100644 100644 100644 100644 86c7983 5374fc8 3b9abaa conflict.txt",
            "1 .M N... 100644 100644 100644 aaa bbb calm.txt",
            "? untracked.txt"
        ])

        // when
        let conflicted = StatusParser.conflictedPaths(output)

        // then
        #expect(conflicted == [RepositoryRelativePath("conflict.txt")])
    }

    @Test
    func `given a renamed record when parsed then its second path field is consumed with it`() {
        // given — a `2` record spans two NUL fields, so the original path must not be read as a
        // record of its own.
        var output = nulSeparated([
            "u UU N... 100644 100644 100644 100644 aaa bbb ccc both.txt"
        ])
        output.append(contentsOf: Data("2 R. N... 100644 100644 100644 ddd eee R100 new.txt\u{0}old.txt\u{0}".utf8))
        output.append(contentsOf: Data("u AA N... 100644 100644 100644 100644 fff ggg hhh second.txt\u{0}".utf8))

        // when
        let conflicted = StatusParser.conflictedPaths(output)

        // then
        #expect(conflicted == [RepositoryRelativePath("both.txt"), RepositoryRelativePath("second.txt")])
    }

    // MARK: - Output that is not what was expected

    @Test
    func `given nothing at all when parsed then every format answers with nothing`() {
        // given — a clean worktree, a repository with no worktrees to list, a merge with no
        // conflicts. Each is the ordinary case rather than an error.
        let empty = Data()

        // when - then
        #expect(WorktreeListParser.parse(empty).isEmpty)
        #expect(RawChangeParser.parse(empty).isEmpty)
        #expect(NumstatParser.parse(empty).isEmpty)
        #expect(StatusParser.conflictedPaths(empty).isEmpty)
        #expect(UntrackedPathParser.parse(empty).isEmpty)
    }

    @Test
    func `given a raw record with no path after it when parsed then it is dropped rather than guessed`() {
        // given — a stream cut short by the output cap ends mid-record, which is what the cap
        // promised rather than corruption.
        let output = nulSeparated([":100644 100644 aaa bbb M", "first.txt", ":100644 100644 ccc ddd M"])

        // when
        let changes = RawChangeParser.parse(output)

        // then
        #expect(changes.map(\.path.text) == ["first.txt"])
    }

    @Test
    func `given a rename with only one of its two paths when parsed then it is dropped`() {
        // given
        let output = nulSeparated([":100644 100644 aaa bbb R100", "only-the-old-one.txt"])

        // when - then — a rename needs both paths, and inventing the missing one puts a file in
        // the list under a name it does not have.
        #expect(RawChangeParser.parse(output).isEmpty)
    }

    @Test
    func `given a metadata field that is too short when parsed then the record is skipped`() {
        // given
        let output = nulSeparated([":100644 100644", ":100644 100644 aaa bbb M", "real.txt"])

        // when
        let changes = RawChangeParser.parse(output)

        // then
        #expect(changes.map(\.path.text) == ["real.txt"])
    }

    @Test
    func `given a numstat field with too few parts when parsed then it is skipped`() {
        // given
        let output = nulSeparated(["garbage", "1\t2\treal.txt"])

        // when
        let records = NumstatParser.parse(output)

        // then
        #expect(records.map(\.path.text) == ["real.txt"])
    }

    @Test
    func `given a worktree attribute this version does not know when parsed then the worktree survives`() {
        // given — git adds attributes over time, and one we do not recognise is not a reason to
        // lose the worktree it belongs to.
        let output = nulSeparated([
            "worktree /a", "HEAD aaa", "branch refs/heads/one", "somethingnew whatever", "",
            "worktree /b", "bare", ""
        ])

        // when
        let records = WorktreeListParser.parse(output)

        // then
        #expect(records.map(\.location.path) == ["/a", "/b"])
        #expect(records[1].isBare)
    }

    @Test
    func `given an unmerged record too short to hold a path when parsed then nothing is invented`() {
        // given
        let output = nulSeparated(["u UU N... 100644"])

        // when - then
        #expect(StatusParser.conflictedPaths(output).isEmpty)
    }

    // MARK: - ls-files --others -z

    @Test
    func `given untracked paths when parsed then each NUL separated path is one file`() {
        // given
        let output = nulSeparated(["src/one.txt", "src/a file with spaces.txt", "caffè.txt"])

        // when
        let paths = UntrackedPathParser.parse(output)

        // then
        #expect(paths.map(\.text) == ["src/one.txt", "src/a file with spaces.txt", "caffè.txt"])
    }
}

/// Fields joined by NUL, with a trailing NUL, which is how git writes every `-z` stream.
private func nulSeparated(_ fields: [String]) -> Data {
    var data = Data()
    for field in fields {
        data.append(contentsOf: Data(field.utf8))
        data.append(0)
    }
    return data
}
