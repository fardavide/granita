import Foundation
import Testing

import ClientViewerData
import ClientViewerDomain
import CoreDiffDomain

/// Where a review lives between the reader writing it and the reader copying it.
///
/// **On the phone, and persisted, because the alternative loses the afternoon.** A review is written
/// over as long as it takes to read a change set, and iOS ends a backgrounded app whenever it likes
/// — comments held only in a model would go with a phone call. The Mac is where they belong
/// eventually, which is [issue #64](https://github.com/fardavide/granita/issues/64) and a contract
/// change; nothing here is on the wire, so nothing here has to wait for it.
///
/// **Keyed per worktree**, because a worktree is what a review is of: two agents working in two
/// checkouts of one project are two reviews, and a shared key would hand each the other's notes.
@Suite("Remembered review comments")
struct UserDefaultsReviewCommentStoreTests {

    @Test
    func `given nothing was ever written when the comments are read then there are none`() {
        // given
        let scenario = Scenario()

        // when - then
        #expect(scenario.sut.comments(in: aWorktree) == [])
    }

    @Test
    func `given comments were saved when they are read then they come back whole`() {
        // given — a span rather than a single line, and an excerpt with a marker on it, so a field
        // dropped in the encoding fails loudly rather than looking plausible.
        let scenario = Scenario()
        let comment = aComment(
            lines: CommentedLines(side: .old, first: 40, last: 44),
            saying: "Why did this go?"
        )

        // when
        scenario.sut.save([comment], in: aWorktree)

        // then
        #expect(scenario.sut.comments(in: aWorktree) == [comment])
    }

    @Test
    func `given comments on one worktree when another is read then it has none of them`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.save([aComment(lines: CommentedLines(side: .new, first: 12, last: 12), saying: "Mine.")], in: aWorktree)

        // then — two checkouts of one project are two reviews.
        #expect(scenario.sut.comments(in: anotherWorktree) == [])
    }

    @Test
    func `given a review was saved when it is replaced by an empty one then nothing is left`() {
        // given — this is *Clear*, which the screen offers once the review has been copied.
        let scenario = Scenario()
        scenario.sut.save([aComment(lines: CommentedLines(side: .new, first: 12, last: 12), saying: "Gone soon.")], in: aWorktree)

        // when
        scenario.sut.save([], in: aWorktree)

        // then
        #expect(scenario.sut.comments(in: aWorktree) == [])
    }

    @Test
    func `given stored bytes no release ever wrote when they are read then there are no comments`() {
        // given — a defaults file edited by hand, or written by a version that spelled a comment
        // differently. A review that cannot be read is a review the reader has to write again, and
        // that is better than a screen that cannot open.
        let scenario = Scenario()
        scenario.defaults.set(Data("not a review".utf8), forKey: UserDefaultsReviewCommentStore.key(for: aWorktree))

        // when - then
        #expect(scenario.sut.comments(in: aWorktree) == [])
    }
}

// MARK: -

private let aWorktree = WorktreeID(rawValue: "the-one-being-read")
private let anotherWorktree = WorktreeID(rawValue: "the-other-checkout")

private func aComment(lines: CommentedLines, saying text: String) -> ReviewComment {
    ReviewComment(
        anchor: CommentAnchor(
            file: FileID(rawValue: "the-file"),
            first: DiffLinePosition(oldNumber: lines.first, newNumber: nil),
            last: DiffLinePosition(oldNumber: nil, newNumber: lines.last)
        ),
        path: "Packages/Granita/Core/Diff/Domain/WordDiff.swift",
        lines: lines,
        quotedLines: ["-    let legacy = true", "+    let legacy = false"],
        text: text
    )
}

private struct Scenario {

    let sut: UserDefaultsReviewCommentStore
    let defaults: UserDefaults

    init() {
        // A suite per subject, named for it, so two tests running at once cannot read each other's
        // answer — and removed first, because a suite outlives the process that made it.
        let name = "granita.tests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: name)
        defaults = UserDefaults(suiteName: name) ?? .standard
        sut = UserDefaultsReviewCommentStore(defaults: defaults)
    }
}
