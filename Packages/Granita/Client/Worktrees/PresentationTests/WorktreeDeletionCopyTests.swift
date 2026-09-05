import Testing

import ClientWorktreesDomain
import CoreDiffDomain
@testable import ClientWorktreesPresentation

/// The three sentences the reader agrees to before a worktree is destroyed.
///
/// Asserted here rather than left in the alert's body because **an alert presents into a window of
/// its own and no raster in this repository includes it**, so a sentence written in the view is a
/// sentence nothing holds to its words. This is the one control in Granita that destroys work that
/// was never committed, and what it promises has to be true.
@Suite("Worktree deletion copy")
struct WorktreeDeletionCopyTests {

    @Test
    func `given several changed files when the cost is read then it names them and what survives`() {
        // given
        let subject = aSubject(stats: .changed(filesChanged: 12, insertions: 340, deletions: 96))

        // given - when - then — the row's own `+n −m` spelling, so the alert reads as being about
        // the row that was pressed rather than about worktrees in general.
        #expect(subject.cost == """
            12 files here have changes that were never committed: +340 −96. Deleting the worktree \
            deletes them, and nothing can bring them back. The branch stays on your Mac.
            """)
    }

    @Test
    func `given exactly one changed file when the cost is read then it is not pluralised`() {
        // given — one file is the ordinary case for a small fix, and "1 files here have" is the
        // sentence a reader remembers instead of the warning.
        let subject = aSubject(stats: .changed(filesChanged: 1, insertions: 12, deletions: 3))

        // given - when - then
        #expect(subject.cost.hasPrefix("1 file here has changes that were never committed: +12 −3."))
    }

    @Test
    func `given a worktree with nothing to review when the cost is read then it says the folder still goes`() {
        // given — reachable, because the quiet worktrees are shown when the toggle is on. Granita
        // only sees what git reports as changed, and the removal takes the whole directory.
        let subject = aSubject(stats: .noChanges)

        // given - when - then
        #expect(subject.cost == """
            Granita sees no uncommitted changes here, but the whole folder goes — including the \
            files git ignores, like local settings and build output. The branch stays on your Mac.
            """)
    }

    @Test
    func `given a worktree with no commits yet when the cost is read then it promises no branch`() {
        // given — an unborn head takes the stats slot rather than reporting the whole repository.
        let subject = aSubject(stats: .noCommitsYet)

        // given - when - then — and it must NOT say the branch stays, because there are no commits
        // for a branch to keep. A sentence that is false in the one case a reader checks it is
        // worse than no sentence.
        #expect(subject.cost == """
            Nothing in this worktree has ever been committed, so all of it goes when the folder \
            does. Nothing can bring it back.
            """)
        #expect(subject.cost.contains("branch") == false)
    }

    @Test
    func `given a locked worktree when the cost is read then it says the lock is being overridden`() {
        // given — **the row this is nearly every row.** Claude Code locks every worktree it creates,
        // and the deletion sends `--force --force`, so the reader is the one overriding the lock. A
        // reader cannot override something nobody told them about.
        let subject = aSubject(stats: .noChanges, isLocked: true)

        // given - when - then — the cost first, because that is what is being decided; the lock after
        // it, because it is what the deletion has to get past to do it.
        #expect(subject.cost == """
            Granita sees no uncommitted changes here, but the whole folder goes — including the \
            files git ignores, like local settings and build output. The branch stays on your Mac.

            Your Mac has this worktree locked — Claude Code locks the ones it makes. Deleting it \
            here goes ahead anyway.
            """)
    }

    @Test
    func `given an unlocked worktree when the cost is read then no lock is mentioned`() {
        // given - when - then — a sentence about a lock on a worktree that has none is the alert
        // inventing a reason to hesitate at the moment hesitation is most expensive.
        #expect(aSubject(stats: .noChanges).cost.contains("locked") == false)
    }
}

// MARK: - What the one alert says, and about what

@Suite("Worktree alert prompt")
struct WorktreeAlertPromptTests {

    @Test
    func `given a deletion being confirmed when the title is read then it names the worktree in full`() {
        // given — the mistake this defends against is destroying the *wrong* row, so the
        // identifying string is the load-bearing part and must never be shortened.
        let prompt: WorktreeAlertPrompt? = .confirmDeletion(aSubject(stats: .noChanges))

        // given - when - then
        #expect(prompt.title == "Delete “tls-pinning”?")
    }

    @Test
    func `given no prompt at all when the title is read then there is still a sentence`() {
        // given — a real case rather than a defensive one: the title is read once more as the alert
        // cross-fades away, and without this it fades to an empty bar.
        let prompt: WorktreeAlertPrompt? = nil

        // given - when - then
        #expect(prompt.title == "Delete this worktree?")
    }

    @Test(arguments: [
        (WorktreeWriteRefusal.edit(.unauthorized), "Your Mac would not make that change"),
        (.deletion(.worktreeNotDeletable(message: "locked")), "Your Mac would not delete it"),
        (.deletion(.unreachable(diagnostic: "NWError -65563")), "Granita could not tell whether it was deleted")
    ])
    func `given a refused write when the title is read then it says which write and how sure it is`(
        refusal: WorktreeWriteRefusal,
        expected: String
    ) {
        // given
        let prompt: WorktreeAlertPrompt? = .refusal(refusal)

        // when - then — the same `ApiFailure` means two different things depending on which write it
        // refused, which is the whole reason the operation travels beside it.
        #expect(prompt.title == expected)
    }

    @Test
    func `given a refused edit when the message is read then it says the row did not move`() {
        // given - when - then — renaming and pinning both leave the row exactly where it was, so
        // without this the swipe is a control that appears to have done nothing.
        #expect(
            WorktreeAlertPrompt.refusal(.edit(.unauthorized)).message
                == "The row is still as it was. Trying again usually works."
        )
    }

    @Test
    func `given a deletion the Mac refused when the message is read then it says nothing was deleted`() {
        // given - when - then — the row said this one was deletable and the Mac disagreed, so the
        // reader is told plainly that the worktree is still there.
        let prompt = WorktreeAlertPrompt.refusal(.deletion(.worktreeNotDeletable(message: "primary")))
        #expect(prompt.message == """
            Nothing was deleted and the worktree is still there. Your Mac will not remove this one: \
            it is the project’s own checkout rather than one of its worktrees.
            """)
    }

    @Test
    func `given a deletion that never finished when the message is read then it admits it cannot tell`() {
        // given - when - then — **the honest sentence rather than the reassuring one.** The request
        // may have arrived and this phone cannot know. It is only useful because the advice that
        // follows is true: `confirmDeletion(of:)` treats a worktree that has already gone as
        // success, so a second attempt does drop the row rather than failing again.
        let prompt = WorktreeAlertPrompt.refusal(.deletion(.unreachable(diagnostic: "NWError -65563")))
        #expect(prompt.message == """
            The request did not finish, so the worktree may or may not still be on your Mac. \
            Deleting it again is safe: if it has already gone, the row simply goes.
            """)
    }

    @Test
    func `given a deletion being confirmed when the message is read then it is what the row will lose`() {
        // given - when - then — the confirmation's message *is* the cost, resolved once on the row
        // so the dialog and the row cannot spell what is at stake two different ways.
        let subject = aSubject(stats: .changed(filesChanged: 12, insertions: 340, deletions: 96))
        #expect(WorktreeAlertPrompt.confirmDeletion(subject).message == subject.cost)
    }
}

// MARK: -

private func aSubject(stats: WorktreeRowStats, isLocked: Bool = false) -> WorktreeDeletionSubject {
    WorktreeDeletionSubject(
        worktree: WorktreeID(rawValue: "w-tls-pinning"),
        displayName: "tls-pinning",
        stats: stats,
        isLocked: isLocked
    )
}
