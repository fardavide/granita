import Testing

@testable import CoreDiffDomain

/// The tab stop is a number both ends have to agree on, and this is the suite that makes it one
/// number rather than two that happen to match.
@Suite("Monospaced grid")
struct MonospacedGridTests {

    @Test
    func `given a leading tab when it is expanded then it reaches the first stop`() {
        // given - when - then
        #expect(MonospacedGrid.expandingTabs(in: "\tlet x = 1") == "    let x = 1")
    }

    @Test
    func `given a tab after two characters when it is expanded then it fills only what is left`() {
        // given — a tab advances to the next stop rather than inserting a fixed run, which is the
        // whole difference between expanding one and replacing one.
        // when - then
        #expect(MonospacedGrid.expandingTabs(in: "if\ttrue") == "if  true")
    }

    @Test
    func `given a tab exactly on a stop when it is expanded then it advances a whole stop`() {
        // given — the case a naive `columns % 4` gets wrong by inserting nothing at all.
        // when - then
        #expect(MonospacedGrid.expandingTabs(in: "func\tname") == "func    name")
    }

    @Test
    func `given two tabs in a row when they are expanded then the second measures from the first`() {
        // given - when - then
        #expect(MonospacedGrid.expandingTabs(in: "a\t\tb") == "a       b")
    }

    @Test
    func `given no tab at all when it is expanded then nothing is copied`() {
        // given — the common case by far, and the one where allocating a second string per line of
        // a 12,000-line file would be the cost of nothing.
        // when
        let line = "    let trust = try await verify(certificate)"

        // then
        #expect(MonospacedGrid.expandingTabs(in: line) == line)
    }

    @Test
    func `given a wide character before a tab when it is expanded then the stop counts columns`() {
        // given — a CJK ideograph occupies two columns of the grid, so a tab after one lands two
        // columns along rather than one. Counting characters instead of columns is the version of
        // this that looks right in English and misaligns everything else.
        // when - then
        #expect(MonospacedGrid.expandingTabs(in: "図\tx") == "図  x")
    }

    // MARK: - Continuing from a column already reached

    @Test
    func `given a piece of a line when it is expanded from the column before it then its tab measures from there`() {
        // given — **the case expanding each piece from zero gets wrong.** A line's changed runs are
        // expanded one at a time so each can be drawn differently, and a tab in the second piece
        // advances from where the first one left off. `if` then `\ttrue` is `if  true`; expanded
        // independently the second piece would reach a whole stop and draw `if    true`.
        // when
        let piece = MonospacedGrid.expandingTabs(in: "\ttrue", startingAtColumn: 2)

        // then — two spaces to reach the stop at four, then four letters, so the line stands at
        // column eight. **The returned column is not the piece's length**: it is where the line has
        // reached, which is what the next piece has to be expanded from.
        #expect(piece.text == "  true")
        #expect(piece.columns == 8)
    }

    @Test
    func `given pieces of one line when each is expanded from the last then together they are the whole line`() {
        // given — the property that makes drawing a line piece by piece safe: the pieces joined are
        // what expanding the line whole would have produced.
        let whole = "if\ttrue {\tx()"

        // when — split where a word diff would split it, and expanded in sequence.
        var joined = ""
        var columns = 0
        for piece in ["if\ttrue", " {\tx()"] {
            let expanded = MonospacedGrid.expandingTabs(in: piece, startingAtColumn: columns)
            joined += expanded.text
            columns = expanded.columns
        }

        // then
        #expect(joined == MonospacedGrid.expandingTabs(in: whole))
    }

    @Test
    func `given a piece with no tab when it is expanded then the column still advances by its width`() {
        // given — a piece carrying no tab still moves the grid along for whatever follows it, and a
        // wide character moves it two.
        // when
        let piece = MonospacedGrid.expandingTabs(in: "図x", startingAtColumn: 1)

        // then
        #expect(piece.text == "図x")
        #expect(piece.columns == 4)
    }

    @Test
    func `given a tab when a line is measured and expanded then the two agree on its width`() {
        // given — the reason this lives beside `DisplayWidth` rather than in the view: the client
        // reserves scroll space from the measured column count and then draws the expanded string,
        // and the two disagreeing is a row-count error in a scroll that must never reflow.
        let line = "if\ttrue {\n"

        // when
        let expanded = MonospacedGrid.expandingTabs(in: line)

        // then
        #expect(DisplayWidth(of: line).columns == DisplayWidth(of: expanded).columns)
    }
}
