import Foundation
import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which side's colours a row draws, and what happens when it has none.
///
/// **The rule is the parser's own numbering read backwards.** A deletion exists only on the old side,
/// an addition only on the new, and a context line on both — so a row asks the side it is on, and the
/// two rows of a changed pair are coloured from two different lexes of two different strings. Getting
/// that wrong is invisible in an ordinary file, where both sides agree, and wrong in exactly the rows
/// a reader is looking at.
@Suite("Highlighted file")
struct HighlightedFileTests {

    @Test
    func `given a context line when its text is asked for then it comes from the new side`() {
        // given — a context line is on both sides, and the two carry deliberately different values so
        // the answer says which one was read rather than only that one was.
        let file = HighlightedFile.none
            .replacing(.old, with: [7: AttributedString("old")])
            .replacing(.new, with: [7: AttributedString("new")])

        // when
        let text = file.text(of: aLine(kind: .context, old: 7, new: 7))

        // then — the new side, because that is the file as it stands and the side every other row
        // that has one is read from.
        #expect(text == AttributedString("new"))
    }

    @Test
    func `given a deletion when its text is asked for then it comes from the old side`() {
        // given — a deletion has no new number, so the new side holds nothing for it at all.
        let file = HighlightedFile.none.replacing(.old, with: [41: AttributedString("removed")])

        // when
        let text = file.text(of: aLine(kind: .deletion, old: 41, new: nil))

        // then
        #expect(text == AttributedString("removed"))
    }

    @Test
    func `given an addition when its text is asked for then it comes from the new side`() {
        // given
        let file = HighlightedFile.none.replacing(.new, with: [41: AttributedString("added")])

        // when
        let text = file.text(of: aLine(kind: .addition, old: nil, new: 41))

        // then
        #expect(text == AttributedString("added"))
    }

    @Test
    func `given a row on neither side when its text is asked for then there is none`() {
        // given — git's no-newline annotation is not a line of the file, so it was never lexed and
        // there is nothing filed under it. It renders plain, which is what every row starts as.
        let file = HighlightedFile.none
            .replacing(.old, with: [1: AttributedString("old")])
            .replacing(.new, with: [1: AttributedString("new")])

        // when
        let text = file.text(of: aLine(kind: .noNewlineMarker, old: nil, new: nil))

        // then
        #expect(text == nil)
    }

    @Test
    func `given a line the lexer never reached when its text is asked for then there is none`() {
        // given — the ordinary state while a file is being read: the numbers exist and the colours
        // have not arrived. **Never a fallback to the other side**, which is `DiffGutter`'s rule for
        // the same reason: a row quietly drawing the other side's colours would be the wrong tokens
        // coloured convincingly.
        let file = HighlightedFile.none.replacing(.old, with: [41: AttributedString("removed")])

        // when
        let text = file.text(of: aLine(kind: .addition, old: nil, new: 41))

        // then
        #expect(text == nil)
    }

    @Test
    func `given one side already coloured when the other arrives then both are kept`() {
        // given — the two sides are lexed one after the other, so the second landing must not throw
        // the first away. That is what upgrading in place means with two strings per file.
        let file = HighlightedFile.none.replacing(.new, with: [1: AttributedString("new")])

        // when
        let both = file.replacing(.old, with: [1: AttributedString("old")])

        // then
        #expect(both.text(of: aLine(kind: .addition, old: nil, new: 1)) == AttributedString("new"))
        #expect(both.text(of: aLine(kind: .deletion, old: 1, new: nil)) == AttributedString("old"))
    }

    @Test
    func `given a side lexed again when it is replaced then the newer answer is the one drawn`() {
        // given — a hunk the reader expanded is lexed a second time against the wider string, and
        // what it answers replaces the narrower one rather than merging with it.
        let file = HighlightedFile.none.replacing(.new, with: [1: AttributedString("before")])

        // when
        let after = file.replacing(.new, with: [1: AttributedString("after")])

        // then
        #expect(after.text(of: aLine(kind: .context, old: 1, new: 1)) == AttributedString("after"))
    }

    @Test
    func `given nothing highlighted when a row asks then it has no text`() {
        // given - when
        let text = HighlightedFile.none.text(of: aLine(kind: .context, old: 1, new: 1))

        // then — the state every file is in until its first lex lands, and the one every refused
        // file stays in.
        #expect(text == nil)
    }
}

// MARK: -

private func aLine(kind: DiffLineKind, old: Int?, new: Int?) -> DiffLine {
    DiffLine(kind: kind, oldNumber: old, newNumber: new, text: "x", displayColumns: 1, segments: nil)
}
