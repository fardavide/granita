import Foundation
import Testing

import CoreDiffDomain

/// Applying a patch to a worktree without asking the Mac.
///
/// **This is the phone's rename before the Mac has answered it**, so what it resolves has to be what
/// the Mac would resolve — otherwise the row reads one name until the next read and another
/// afterwards. The Mac's own resolution is `alias`, else `suggestedAlias`, else the branch, else the
/// directory, and all four arms are asserted here because only the first two are ever reached by a
/// test that goes through a fake Mac.
@Suite("Applying a worktree patch")
struct WorktreePatchApplicationTests {

    @Test
    func `given an alias when it is set then it is the name and the alias both`() {
        // given
        let worktree = aWorktree(alias: nil, suggestedAlias: "the tls work", branch: "tls-pinning")

        // when
        let updated = worktree.applying(WorktreePatch(alias: .set("Scroll rewrite"), isPinned: nil))

        // then — the alias wins over both derived names, which is the whole of why a reader sets one.
        #expect(updated.alias == "Scroll rewrite")
        #expect(updated.displayName == "Scroll rewrite")
    }

    @Test
    func `given an alias when it is cleared then the session's suggestion is what the row reads`() {
        // given
        let worktree = aWorktree(alias: "Scroll", suggestedAlias: "the tls work", branch: "tls-pinning")

        // when
        let updated = worktree.applying(WorktreePatch(alias: .cleared, isPinned: nil))

        // then — the rename sheet's footer promises exactly this before the reader saves, so anything
        // else here is a sentence that turns out to be untrue one tap later.
        #expect(updated.alias == nil)
        #expect(updated.displayName == "the tls work")
    }

    @Test
    func `given no suggestion when the alias is cleared then the branch is what the row reads`() {
        // given — no Claude Code session Granita could read for this checkout.
        let worktree = aWorktree(alias: "Scroll", suggestedAlias: nil, branch: "tls-pinning")

        // when
        let updated = worktree.applying(WorktreePatch(alias: .cleared, isPinned: nil))

        // then
        #expect(updated.displayName == "tls-pinning")
    }

    @Test
    func `given a detached worktree with no suggestion when the alias is cleared then it is the directory`() {
        // given — detached and unread, which leaves the directory as the only name there is.
        let worktree = aWorktree(alias: "Scroll", suggestedAlias: nil, branch: nil)

        // when
        let updated = worktree.applying(WorktreePatch(alias: .cleared, isPinned: nil))

        // then
        #expect(updated.displayName == "granita-0f2a")
    }

    @Test
    func `given a patch that says nothing about the alias then the name does not move`() {
        // given — what a pin sends. An alias silently dropped by the write that pins a row is a
        // rename undone by an unrelated tap.
        let worktree = aWorktree(alias: "Scroll", suggestedAlias: "the tls work", branch: "tls-pinning")

        // when
        let updated = worktree.applying(WorktreePatch(alias: .unchanged, isPinned: true))

        // then
        #expect(updated.alias == "Scroll")
        #expect(updated.displayName == "Scroll")
        #expect(updated.isPinned)
    }

    @Test
    func `given a patch that says nothing about the pin then the pin does not move`() {
        // given — the other half, and what a rename sends.
        let worktree = aWorktree(alias: nil, suggestedAlias: nil, branch: "tls-pinning", isPinned: true)

        // when
        let updated = worktree.applying(WorktreePatch(alias: .set("Scroll"), isPinned: nil))

        // then
        #expect(updated.isPinned)
    }

    @Test
    func `given a patch when it is applied then nothing the Mac answers for is invented`() {
        // given — **the rule that keeps this honest.** A patch changes an alias and a pin; the stats
        // and the revision are what a *read* is for, and a phone that moved either would be telling
        // itself the worktree changed while it was renaming it.
        let worktree = aWorktree(alias: nil, suggestedAlias: nil, branch: "tls-pinning")

        // when
        let updated = worktree.applying(WorktreePatch(alias: .set("Scroll"), isPinned: true))

        // then
        #expect(updated.id == worktree.id)
        #expect(updated.stats == worktree.stats)
        #expect(updated.revision == worktree.revision)
        #expect(updated.lastModified == worktree.lastModified)
        #expect(updated.isLocked == worktree.isLocked)
        #expect(updated.isPrimary == worktree.isPrimary)
        #expect(updated.isDetached == worktree.isDetached)
        #expect(updated.hasUnbornHead == worktree.hasUnbornHead)
        #expect(updated.projectId == worktree.projectId)
        #expect(updated.projectName == worktree.projectName)
        #expect(updated.suggestedAlias == worktree.suggestedAlias)
        #expect(updated.directoryName == worktree.directoryName)
        #expect(updated.branch == worktree.branch)
    }
}

// MARK: -

private func aWorktree(
    alias: String?,
    suggestedAlias: String?,
    branch: String?,
    isPinned: Bool = false
) -> Worktree {
    Worktree(
        id: WorktreeID(rawValue: "w-1"),
        projectId: ProjectID(rawValue: "p-1"),
        projectName: "granita",
        branch: branch,
        isPrimary: false,
        isDetached: branch == nil,
        isLocked: true,
        hasUnbornHead: false,
        alias: alias,
        suggestedAlias: suggestedAlias,
        displayName: alias ?? suggestedAlias ?? branch ?? "granita-0f2a",
        directoryName: "granita-0f2a",
        isPinned: isPinned,
        stats: ChangeStats(filesChanged: 12, insertions: 248, deletions: 31),
        lastModified: Date(timeIntervalSince1970: 1_800_000_000),
        revision: "r1"
    )
}
