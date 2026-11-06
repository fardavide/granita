import Testing

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

@testable import ClientViewerPresentation

@Suite("Client viewer viewed mark generation")
@MainActor
struct ClientViewerViewedGenerationTests {

    @Test
    func `given a viewed write is suspended when live authorization is revoked then its late refusal cannot restore the review`() async {
        // given
        let file = FileChange(
            id: FileID(rawValue: "reviewed-file"),
            path: "Sources/Review.swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 1),
            contentHash: String(repeating: "a", count: 64),
            estimatedLineCount: 20,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        )
        let scenario = Scenario(file: file)
        await scenario.sut.load()
        let mark = Task { await scenario.sut.setViewed(true, on: file.id) }
        while scenario.repository.viewedWrites.isEmpty { await Task.yield() }

        // when
        await scenario.sut.receive(.failed(.unauthorized))
        let countsAfterRevocation = scenario.counts.values
        scenario.repository.releaseViewedWrites()
        await mark.value

        // then
        #expect(scenario.sut.state == .failed(.unauthorized))
        #expect(scenario.sut.viewedFailure == nil)
        #expect(scenario.counts.values == countsAfterRevocation)
    }

    private struct Scenario {

        let sut: ClientViewerModel
        let repository: FakeGranitaRepository
        let counts: ViewedCounts

        init(file: FileChange) {
            repository = FakeGranitaRepository(
                changeSet: .success(WorktreeChanges(
                    revision: "review-before-revocation",
                    stats: file.stats,
                    files: [file],
                    isTruncated: false
                )),
                viewedFailure: .gitFailure(message: "viewed write refused after authorization was revoked"),
                holdingViewedWrites: true
            )
            counts = ViewedCounts()
            sut = ClientViewerModel(
                worktree: WorktreeID(rawValue: "reviewed-worktree"),
                macName: "Review Mac",
                repository: repository,
                commentStore: FakeReviewCommentStore(),
                pasteboard: FakeReviewPasteboard(),
                highlighter: FakeSyntaxHighlighter(),
                copyingLogs: FakeDiagnosticLogsCopying(answering: .success(())),
                announcing: FakeDiffReadAnnouncing(),
                onViewedCountChanged: { [counts] _, count in counts.values.append(count) },
                longWait: DiffFileWait.longWait
            )
        }
    }
}

private final class ViewedCounts {
    var values: [Int] = []
}
