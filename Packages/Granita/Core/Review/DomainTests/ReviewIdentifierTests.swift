import Testing

@testable import CoreReviewDomain

/// The short name each comment answers to, which is the whole reason it exists: the reader pastes
/// the document, clears the review, and from then on the only handle either side has on a comment is
/// the label the document gave it.
@Suite("Review identifier")
struct ReviewIdentifierTests {

    // MARK: - Letters

    @Test
    func `given letters when the first comments are labelled then they run from A`() {
        // given - when - then
        #expect(ReviewIdentifier.letters.label(at: 0) == "A")
        #expect(ReviewIdentifier.letters.label(at: 1) == "B")
        #expect(ReviewIdentifier.letters.label(at: 25) == "Z")
    }

    @Test
    func `given letters when there are more comments than letters then the labels grow a place`() {
        // given — a review of a long afternoon runs past Z, and the one thing a label must never do
        // is repeat: two comments called A is worse than no labels at all, because the agent's reply
        // then names one of them and the reader cannot tell which.
        // when - then
        #expect(ReviewIdentifier.letters.label(at: 26) == "AA")
        #expect(ReviewIdentifier.letters.label(at: 27) == "AB")
        #expect(ReviewIdentifier.letters.label(at: 51) == "AZ")
        #expect(ReviewIdentifier.letters.label(at: 52) == "BA")
        #expect(ReviewIdentifier.letters.label(at: 701) == "ZZ")
        #expect(ReviewIdentifier.letters.label(at: 702) == "AAA")
    }

    // MARK: - Numbers

    @Test
    func `given numbers when the comments are labelled then they count from one`() {
        // given — the position is an index and the label is a count, which is the one place these two
        // spellings of the same thing are allowed to differ by one.
        // when - then
        #expect(ReviewIdentifier.numbers.label(at: 0) == "1")
        #expect(ReviewIdentifier.numbers.label(at: 9) == "10")
        #expect(ReviewIdentifier.numbers.label(at: 701) == "702")
    }

    // MARK: - Both

    @Test
    func `given every style when a review is labelled then no two comments share a label`() {
        // given — the property the whole type exists for, asserted over a run long enough to reach
        // the second place.
        for style in ReviewIdentifier.allCases {
            // when
            let labels = (0..<200).map(style.label(at:))

            // then
            #expect(Set(labels).count == labels.count)
        }
    }
}
