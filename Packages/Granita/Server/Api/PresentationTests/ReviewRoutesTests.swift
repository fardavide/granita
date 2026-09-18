import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import CoreApiDomain
import CoreDiffDomain
import CoreReviewDomain
import ServerStoreDomain

/// The four routes the review and its settings travel over.
///
/// **What these hold that a store test cannot**: that the worktree in the path is the worktree the
/// review is filed under, and that a patch changes only the field it names. Both are the difference
/// between a reader's notes landing where they meant and landing on somebody else's checkout.
@Suite("Review routes")
struct ReviewRoutesTests {

    @Test
    func `given a review put for a worktree when it is read back then it is what was sent`(
    ) async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = WorktreeID(canonicalPath: repository.worktree.path)

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/worktrees/\(worktree.rawValue)/review",
                method: .put,
                body: ByteBuffer(data: try JSONEncoder().encode(ReviewRequest(comments: [aComment])))
            ) { response in
                #expect(response.status == .noContent)
            }

            // then
            try await client.execute(
                uri: "/v1/worktrees/\(worktree.rawValue)/review",
                method: .get
            ) { response in
                let review = try JSONDecoder().decode(ReviewRequest.self, from: response.body)
                #expect(review.comments == [aComment])
            }
        }
    }

    @Test
    func `given an empty review put when it is read back then the worktree has none`() async throws {
        // given — this is how a review is cleared, and the reader pressed Clear expecting it gone
        // from the Mac as well as from the phone.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = WorktreeID(canonicalPath: repository.worktree.path)

        // when
        try await scenario.application.test(.router) { client in
            for comments in [[aComment], []] {
                try await client.execute(
                    uri: "/v1/worktrees/\(worktree.rawValue)/review",
                    method: .put,
                    body: ByteBuffer(data: try JSONEncoder().encode(ReviewRequest(comments: comments)))
                ) { _ in }
            }

            // then
            try await client.execute(
                uri: "/v1/worktrees/\(worktree.rawValue)/review",
                method: .get
            ) { response in
                let review = try JSONDecoder().decode(ReviewRequest.self, from: response.body)
                #expect(review.comments.isEmpty)
            }
        }
    }

    @Test
    func `given a worktree this Mac does not serve when its review is asked for then it refuses`(
    ) async throws {
        // given — the same resolution every other worktree route does, so an identifier naming
        // nothing is answered the same way wherever it arrives.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/worktrees/\(WorktreeID(canonicalPath: "/nowhere").rawValue)/review",
                method: .get
            ) { response in
                #expect(response.status != .ok)
            }
        }
    }

    @Test
    func `given settings never set when they are asked for then the defaults come back`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }

        // when - then — absent rather than the built-in string, so a later release may change what
        // the default is without every Mac having written the old one down.
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/review-settings", method: .get) { response in
                let settings = try JSONDecoder().decode(
                    ReviewSettingsResponse.self,
                    from: response.body
                )
                #expect(settings.openingLine == nil)
                #expect(settings.identifier == .letters)
            }
        }
    }

    @Test
    func `given a patch naming one setting when it is sent then the other is left alone`() async throws {
        // given — the rule that makes editing safe from a phone that never read this Mac: a queued
        // opening line must not carry a label style it has never seen.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }

        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/review-settings",
                method: .patch,
                body: ByteBuffer(data: Data(#"{"identifier": "numbers"}"#.utf8))
            ) { _ in }

            // when
            try await client.execute(
                uri: "/v1/review-settings",
                method: .patch,
                body: ByteBuffer(data: Data(#"{"openingLine": "Mine."}"#.utf8))
            ) { response in
                // then
                let settings = try JSONDecoder().decode(
                    ReviewSettingsResponse.self,
                    from: response.body
                )
                #expect(settings.openingLine == "Mine.")
                #expect(settings.identifier == .numbers)
            }
        }
    }

    @Test
    func `given a patch with a null line when it is sent then the setting goes back to the default`(
    ) async throws {
        // given — Reset, which has to reach the Mac as an instruction rather than as an omission.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }

        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/review-settings",
                method: .patch,
                body: ByteBuffer(data: Data(#"{"openingLine": "Mine."}"#.utf8))
            ) { _ in }

            // when
            try await client.execute(
                uri: "/v1/review-settings",
                method: .patch,
                body: ByteBuffer(data: Data(#"{"openingLine": null}"#.utf8))
            ) { response in
                // then
                let settings = try JSONDecoder().decode(
                    ReviewSettingsResponse.self,
                    from: response.body
                )
                #expect(settings.openingLine == nil)
            }
        }
    }
}

// MARK: -

private let aComment = ReviewComment(
    anchor: CommentAnchor(
        file: FileID(repositoryRelativePath: "src/a.swift"),
        first: DiffLinePosition(oldNumber: nil, newNumber: 12),
        last: DiffLinePosition(oldNumber: nil, newNumber: 14)
    ),
    path: "src/a.swift",
    lines: CommentedLines(side: .new, first: 12, last: 14),
    language: "swift",
    quotedLines: ["+    let a = 1"],
    text: "This should be a constant."
)
