import Testing

import ClientConnectionDomain
import ClientViewerData
import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

@Suite("Local review shares the server document")
struct LocalReviewCommentStoreTests {

    @Test
    func `given no cached review when read then the local review is empty`() {
        // given
        let scenario = Scenario()

        // when
        let comments = scenario.sut.comments(in: scenario.worktree)

        // then
        #expect(comments.isEmpty)
    }

    @Test
    func `given a comment removed on the server when reconciled then a cached local comment is not resurrected`() async {
        // given
        let scenario = Scenario()
        scenario.sut.save([scenario.comment], in: scenario.worktree)

        // when
        let comments = await scenario.sut.reconcile(in: scenario.worktree)

        // then
        #expect(comments.isEmpty)
        #expect(scenario.sut.comments(in: scenario.worktree).isEmpty)
    }

    @Test
    func `when a local review is pushed then the server document receives it`() async {
        // given
        let scenario = Scenario()

        // when
        let sync = await scenario.sut.push([scenario.comment], in: scenario.worktree)

        // then
        #expect(sync == .settled)
        #expect(scenario.repository.stored == [scenario.comment])
    }

    @Test
    func `given a cached review when clearing it is refused then the cached comments remain`() async {
        // given
        let scenario = Scenario(failing: .badRequest(message: "The review document is read-only."))
        scenario.sut.save([scenario.comment], in: scenario.worktree)
        scenario.repository.stored = [scenario.comment]

        // when
        let sync = await scenario.sut.push([], in: scenario.worktree)

        // then
        #expect(sync == .refused(reason: "The review document is read-only."))
        #expect(scenario.sut.comments(in: scenario.worktree) == [scenario.comment])
        #expect(scenario.repository.stored == [scenario.comment])
        #expect(scenario.repository.received.isEmpty)
    }

    @Test
    func `given a cached review when reconciliation is refused then cached comments are retained`() async {
        // given
        let scenario = Scenario(failing: .badRequest(message: "The review document could not be read."))
        scenario.sut.save([scenario.comment], in: scenario.worktree)

        // when
        let comments = await scenario.sut.reconcile(in: scenario.worktree)

        // then
        #expect(comments == [scenario.comment])
        #expect(scenario.sut.comments(in: scenario.worktree) == [scenario.comment])
    }

    private struct Scenario {
        let repository: FakeReviewRepository
        let sut: LocalReviewCommentStore
        let worktree = WorktreeID(canonicalPath: "/repo/local-review")
        let comment = ReviewComment(
            anchor: CommentAnchor(
                file: FileID(repositoryRelativePath: "reader.swift"),
                first: DiffLinePosition(oldNumber: nil, newNumber: 8),
                last: DiffLinePosition(oldNumber: nil, newNumber: 8)
            ),
            path: "reader.swift",
            lines: CommentedLines(side: .new, first: 8, last: 8),
            language: "swift",
            quotedLines: ["+let reader = LocalReader()"],
            text: "Keep one stored review."
        )

        init(failing failure: ApiFailure? = nil) {
            repository = FakeReviewRepository(failing: failure)
            sut = LocalReviewCommentStore(repository: repository)
        }
    }
}
