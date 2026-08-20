import Foundation
import Testing

@testable import CoreDiffDomain

/// What turns a one-character edit from "this whole line is red" into something readable on a phone.
@Suite("Word diff")
struct WordDiffTests {

    // MARK: - Pairing

    @Test
    func `given a deletion followed by an addition when segmented then both sides are segmented`() {
        // given
        let lines = [line(.deletion, "let c = 3"), line(.addition, "let c = 30")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[0].segments == [
            WordSegment(text: "let c = ", isChanged: false),
            WordSegment(text: "3", isChanged: true)
        ])
        #expect(segmented[1].segments == [
            WordSegment(text: "let c = ", isChanged: false),
            WordSegment(text: "30", isChanged: true)
        ])
    }

    @Test
    func `given two deletions and two additions when segmented then they pair by position`() {
        // given — the second addition belongs to the second deletion, not to the nearest one.
        let lines = [
            line(.deletion, "alpha one"),
            line(.deletion, "beta two"),
            line(.addition, "alpha ONE"),
            line(.addition, "beta TWO")
        ]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[0].segments?.first == WordSegment(text: "alpha ", isChanged: false))
        #expect(segmented[1].segments?.first == WordSegment(text: "beta ", isChanged: false))
    }

    @Test
    func `given more deletions than additions when segmented then the unpaired one has no segments`() {
        // given
        let lines = [
            line(.deletion, "alpha one"),
            line(.deletion, "beta two"),
            line(.addition, "alpha ONE")
        ]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[0].segments != nil)
        #expect(segmented[1].segments == nil)
    }

    @Test
    func `given a deletion that no addition follows when segmented then it has no segments`() {
        // given
        let lines = [line(.deletion, "alpha one"), line(.context, "beta two")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[0].segments == nil)
    }

    @Test
    func `given an addition that no deletion precedes when segmented then it has no segments`() {
        // given
        let lines = [line(.context, "alpha one"), line(.addition, "alpha two")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[1].segments == nil)
    }

    @Test
    func `given a context line between a deletion and an addition when segmented then they do not pair`() {
        // given
        let lines = [
            line(.deletion, "let c = 3"),
            line(.context, "unchanged"),
            line(.addition, "let c = 30")
        ]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[0].segments == nil)
        #expect(segmented[2].segments == nil)
    }

    @Test
    func `given a no newline marker between a deletion and an addition when segmented then they still pair`() {
        // given — git writes the marker immediately after the line it belongs to, so it lands in the
        // middle of every pair in a file with no trailing newline.
        let lines = [
            line(.deletion, "no trailing newline here"),
            line(.noNewlineMarker, "No newline at end of file"),
            line(.addition, "no trailing newline here, edited"),
            line(.noNewlineMarker, "No newline at end of file")
        ]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[0].segments != nil)
        #expect(segmented[2].segments?.last == WordSegment(text: ", edited", isChanged: true))
        #expect(segmented[1].segments == nil)
    }

    // MARK: - Guards

    @Test
    func `given two lines with nothing in common when segmented then neither is segmented`() {
        // given — below the similarity floor, where segments would be noise rather than a reading aid.
        let lines = [
            line(.deletion, "the quick brown fox jumps"),
            line(.addition, "unrelated content entirely here")
        ]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented.allSatisfy { $0.segments == nil })
    }

    @Test
    func `given two lines sharing only their spacing when segmented then that is not similarity`() {
        // given — the same word count and not a word in common. Counting the whitespace runs between
        // the words as shared tokens would carry this over the floor on shape alone.
        let lines = [line(.deletion, "alpha beta gamma delta"), line(.addition, "one two three four")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented.allSatisfy { $0.segments == nil })
    }

    @Test
    func `given a line longer than a thousand characters when segmented then it is left alone`() {
        // given — the comparison is quadratic, and a minified bundle on one line is where that bites.
        // Similar enough to be worth comparing, so only the length can be what stops it.
        let long = String(repeating: "word ", count: 250)
        let lines = [line(.deletion, long), line(.addition, long + "tail")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(long.count > 1_000)
        #expect(segmented.allSatisfy { $0.segments == nil })
    }

    // MARK: - Tokens

    @Test
    func `given only the indentation changed when segmented then only the whitespace is marked`() {
        // given — whitespace runs are tokens of their own, so this needs no special case.
        let lines = [line(.deletion, "  return value"), line(.addition, "    return value")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[1].segments == [
            WordSegment(text: "    ", isChanged: true),
            WordSegment(text: "return value", isChanged: false)
        ])
    }

    @Test
    func `given a run of punctuation when segmented then it is one token rather than several`() {
        // given
        let lines = [line(.deletion, "value == other"), line(.addition, "value != other")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[1].segments == [
            WordSegment(text: "value ", isChanged: false),
            WordSegment(text: "!=", isChanged: true),
            WordSegment(text: " other", isChanged: false)
        ])
    }

    @Test
    func `given segments when produced then joining them rebuilds the line exactly`() throws {
        // given — the client renders segments instead of the text, so anything lost here is lost.
        let text = "    let name: String? = person.name  // trailing"
        let lines = [line(.deletion, text), line(.addition, "    let name: String = person.name  // trailing")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        let segments = try #require(segmented[0].segments)
        #expect(segments.map(\.text).joined() == text)
    }

    @Test
    func `given a word appearing twice when segmented then the unchanged one is not marked`() {
        // given
        let lines = [line(.deletion, "a = a + 1"), line(.addition, "a = a + 2")]

        // when
        let segmented = WordDiff.segmented(lines)

        // then
        #expect(segmented[1].segments == [
            WordSegment(text: "a = a + ", isChanged: false),
            WordSegment(text: "2", isChanged: true)
        ])
    }

    // MARK: - Through the parser

    @Test
    func `given a diff when parsed then its paired lines already carry segments`() throws {
        // given
        let text = try Fixture.text("case-section-heading.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        let addition = try #require(lines.first { $0.kind == .addition })
        #expect(addition.segments == [
            WordSegment(text: "    let c = ", isChanged: false),
            WordSegment(text: "30", isChanged: true)
        ])
    }

    @Test
    func `given a context line when parsed then it carries no segments`() throws {
        // given
        let text = try Fixture.text("case-modified.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        #expect(lines.filter { $0.kind == .context }.allSatisfy { $0.segments == nil })
    }
}

private func line(_ kind: DiffLineKind, _ text: String) -> DiffLine {
    DiffLine(
        kind: kind,
        oldNumber: nil,
        newNumber: nil,
        text: text,
        displayColumns: DisplayWidth(of: text).columns,
        needsMeasurement: false,
        segments: nil
    )
}
