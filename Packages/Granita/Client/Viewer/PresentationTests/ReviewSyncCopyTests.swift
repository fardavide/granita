import Testing

import ClientViewerDomain
@testable import ClientViewerPresentation

/// The one sentence the review sheet says about where the review is.
///
/// The load-bearing case is the first one: a settled review says nothing at all, because the absence
/// of a sentence is how this feature reports the good state everywhere.
@Suite("Review sync copy")
struct ReviewSyncCopyTests {

    @Test
    func `given a review the Mac has when a caption is asked for then there is nothing to say`() {
        // given - when
        let caption = ReviewSyncCopy.caption(for: .settled, macName: "MacBook Pro")

        // then
        #expect(caption == nil)
    }

    @Test
    func `given some comments unsent when a caption is asked for then it counts them`() {
        // given — a count rather than a word: two of five and five of five are different decisions
        // at the moment the reader is about to paste.
        let caption = ReviewSyncCopy.caption(
            for: .pending(count: 2, of: 5),
            macName: "MacBook Pro"
        )

        // then
        #expect(caption?.sentence == "2 of 5 comments are only on this phone.")
        #expect(caption?.isUnsettled == true)
    }

    @Test
    func `given one comment unsent when a caption is asked for then the sentence agrees with itself`(
    ) {
        // given — "1 of 3 comments are" is the kind of thing a reader notices and nobody meant.
        let caption = ReviewSyncCopy.caption(
            for: .pending(count: 1, of: 3),
            macName: "MacBook Pro"
        )

        // then
        #expect(caption?.sentence == "1 of 3 comment is only on this phone.")
    }

    @Test
    func `given a push in flight when a caption is asked for then it reports no disagreement`() {
        // given — the amber was reporting a disagreement, and while the push is running there is no
        // longer one to report. The reader is not asked to wait either.
        let caption = ReviewSyncCopy.caption(for: .reconciling, macName: "MacBook Pro")

        // then
        #expect(caption?.sentence == "Sending to MacBook Pro…")
        #expect(caption?.isUnsettled == false)
    }

    @Test
    func `given the Mac refused when a caption is asked for then its own words are underneath`() {
        // given — our sentence, the store's as small print. The copy button is untouched by this.
        let caption = ReviewSyncCopy.caption(
            for: .refused(reason: "the document on disk could not be read"),
            macName: "MacBook Pro"
        )

        // then
        #expect(caption?.sentence == "MacBook Pro cannot store this review.")
        #expect(caption?.reason == "the document on disk could not be read")
        #expect(caption?.isUnsettled == true)
    }

    @Test
    func `given a Mac that cannot hold a review when a caption is asked for then nothing is wrong`(
    ) {
        // given — an older Mac, or none at all. Nothing is queued and nothing failed, so the
        // sentence states where the review lives rather than reporting a fault.
        let caption = ReviewSyncCopy.caption(for: .notStorable, macName: "MacBook Pro")

        // then
        #expect(caption?.sentence == "This review is kept on this phone.")
        #expect(caption?.isUnsettled == false)
        #expect(caption?.reason == nil)
    }
}
