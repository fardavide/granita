import Foundation
import Testing

@testable import ServerSessionsData

/// Matching is decided over **all** the worktrees at once rather than one at a time, and the second
/// test is why: every worktree an agent makes lives under the checkout it branched from, so asking
/// "does this session's directory sit inside this worktree" in isolation answers yes for the outer
/// one every single time.
@Suite("Session matching")
struct SessionMatchingTests {

    @Test
    func `given a session started in a subdirectory when matched then it still belongs to the worktree`() {
        // given — an agent invoked inside `Packages/` records that directory, not the checkout's
        // root, so exact equality finds nothing at all.
        let sessions = [session(directory: "/repo/slice/Packages/Granita", label: "Fix the manifest")]

        // when
        let labels = SessionMatching.labels(for: [worktree("/repo/slice")], among: sessions)

        // then
        #expect(labels["/repo/slice"] == "Fix the manifest")
    }

    @Test
    func `given a worktree nested inside another when matched then only the closest one is named`() {
        // given
        let sessions = [session(directory: "/repo/.claude/worktrees/slice", label: "The slice")]

        // when
        let labels = SessionMatching.labels(
            for: [worktree("/repo"), worktree("/repo/.claude/worktrees/slice")],
            among: sessions
        )

        // then — the primary checkout would otherwise take the name of whatever an agent last did
        // in any worktree under it, which is every worktree.
        #expect(labels["/repo/.claude/worktrees/slice"] == "The slice")
        #expect(labels["/repo"] == nil)
    }

    @Test
    func `given a sibling directory with a shared prefix when matched then it is not a match`() {
        // given
        let sessions = [session(directory: "/repo/slice-two", label: "Somewhere else")]

        // when
        let labels = SessionMatching.labels(for: [worktree("/repo/slice")], among: sessions)

        // then — `/repo/slice` is a textual prefix of `/repo/slice-two` and not a parent of it, so
        // containment has to stop on a separator.
        #expect(labels.isEmpty)
    }

    @Test
    func `given several sessions in one worktree when matched then the most recent one wins`() {
        // given
        let sessions = [
            session(directory: "/repo/slice", label: "Older", secondsAgo: 900),
            session(directory: "/repo/slice", label: "Newer", secondsAgo: 10)
        ]

        // when
        let labels = SessionMatching.labels(for: [worktree("/repo/slice")], among: sessions)

        // then
        #expect(labels["/repo/slice"] == "Newer")
    }

    @Test
    func `given sessions on two branches in one directory when matched then the branch decides`() {
        // given — a directory reused across branches, where the newest session is not the one that
        // belongs to what is checked out now.
        let sessions = [
            session(directory: "/repo", branch: "main", label: "On main", secondsAgo: 10),
            session(directory: "/repo", branch: "feature", label: "On the feature", secondsAgo: 900)
        ]

        // when
        let labels = SessionMatching.labels(for: [worktree("/repo", branch: "feature")], among: sessions)

        // then
        #expect(labels["/repo"] == "On the feature")
    }

    @Test
    func `given a session above a worktree and one inside it when matched then each names its own`() {
        // given
        let sessions = [
            session(directory: "/repo", label: "The whole repository", secondsAgo: 10),
            session(directory: "/repo/slice", label: "Just the slice", secondsAgo: 900)
        ]

        // when
        let labels = SessionMatching.labels(for: [worktree("/repo"), worktree("/repo/slice")], among: sessions)

        // then — recency never carries a session past a worktree that contains it more closely.
        #expect(labels["/repo"] == "The whole repository")
        #expect(labels["/repo/slice"] == "Just the slice")
    }

    @Test
    func `given a session with nothing to say when matched then the worktree keeps its own name`() {
        // given — a transcript whose opening turn was a tool result and which was never titled.
        let sessions = [session(directory: "/repo/slice", label: nil)]

        // when
        let labels = SessionMatching.labels(for: [worktree("/repo/slice")], among: sessions)

        // then
        #expect(labels.isEmpty)
    }
}

private func worktree(_ path: String, branch: String? = nil) -> MatchableWorktree {
    MatchableWorktree(path: path, branch: branch)
}

private func session(
    directory: String,
    branch: String? = nil,
    label: String?,
    secondsAgo: TimeInterval = 0
) -> IndexedSession {
    IndexedSession(
        workingDirectory: directory,
        branch: branch,
        label: label,
        modifiedAt: Date(timeIntervalSince1970: 1_800_000_000 - secondsAgo)
    )
}
