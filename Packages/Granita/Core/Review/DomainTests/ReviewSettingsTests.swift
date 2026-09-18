import Foundation
import Testing

@testable import CoreReviewDomain

/// The two settings that shape every exported review. The whole of the interesting behaviour is that
/// "never chosen" and "chosen to be nothing" are different answers, because one restores the default
/// and the other is a review that begins at its first comment.
@Suite("Review settings")
struct ReviewSettingsTests {

    @Test
    func `given nothing chosen when the opening line is resolved then it is the built-in one`() {
        // given - when
        let resolved = ReviewSettings.unset.resolvedOpeningLine

        // then
        #expect(resolved == "Review of uncommitted changes")
    }

    @Test
    func `given a line the reader wrote when it is resolved then it is theirs rather than the default`(
    ) {
        // given
        let settings = ReviewSettings(
            openingLine: "Review the uncommitted work in this worktree.",
            identifier: .letters
        )

        // when
        let resolved = settings.resolvedOpeningLine

        // then
        #expect(resolved == "Review the uncommitted work in this worktree.")
    }

    @Test
    func `given a line cleared to nothing when it is resolved then the review has no opening line`() {
        // given — a legal answer rather than a mistake: the document then begins at its first
        // comment. Restoring the default here would make clearing the field do the opposite of what
        // it says, and leave Reset with nothing to do.
        let settings = ReviewSettings(openingLine: "", identifier: .numbers)

        // when
        let resolved = settings.resolvedOpeningLine

        // then
        #expect(resolved == nil)
    }

    @Test
    func `given settings when they are encoded and read back then both fields survive`() throws {
        // given — the Mac stores these and two devices read them, so a field that does not survive a
        // round trip is a setting one of them silently disagrees about.
        let settings = ReviewSettings(openingLine: "", identifier: .numbers)

        // when
        let decoded = try JSONDecoder().decode(
            ReviewSettings.self,
            from: try JSONEncoder().encode(settings)
        )

        // then
        #expect(decoded == settings)
        #expect(decoded.openingLine == "")
        #expect(decoded.identifier == .numbers)
    }
}
