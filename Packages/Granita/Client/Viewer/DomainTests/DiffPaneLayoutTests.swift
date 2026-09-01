import Testing

@testable import ClientViewerDomain

/// What the diff screen shows at a given width, and what the reader has folded away.
///
/// **These four answers used to be computed properties inside the screen**, where the only thing
/// that could check them was a photograph of one layout at a time — and one of them decides whether
/// a control exists at all, which is the class of question this project has shipped wrong before.
///
/// The iPad's column is Davide's amendment to the design review, 1 September 2026: the tree is
/// furniture rather than a modal, and a reader who wants the window for code folds it away and gets
/// the phone's *Files* button back in its place.
@Suite("Diff pane layout")
struct DiffPaneLayoutTests {

    @Test
    func `given a width that fits the column when it is open then the column shows`() {
        // given - when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: true, hasFilesToSelect: true)

        // then
        #expect(layout.showsSelectorColumn)
    }

    @Test
    func `given a width that fits the column when the reader folded it then the column goes`() {
        // given - when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: false, hasFilesToSelect: true)

        // then
        #expect(layout.showsSelectorColumn == false)
    }

    @Test
    func `given a phone width when the column is nominally open then it still does not show`() {
        // given — the fold state is remembered across a rotation, so a phone must not be asked to
        // draw a 320pt column taken out of 390 because an iPad was folded open earlier.
        // when
        let layout = DiffPaneLayout(fitsSelectorColumn: false, isSelectorColumnOpen: true, hasFilesToSelect: true)

        // then
        #expect(layout.showsSelectorColumn == false)
    }

    @Test
    func `given the column is folded away when the toolbar is built then the files button comes back`() {
        // given — **the fold must not be a one-way door.** A width that could show the tree but is
        // not showing it is the phone's situation exactly, and leaving no way to the list would make
        // the toggle a control that takes something away and cannot give it back.
        // when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: false, hasFilesToSelect: true)

        // then
        #expect(layout.showsFilesButton)
    }

    @Test
    func `given the column is showing when the toolbar is built then the files button is absent`() {
        // given — the list is already on screen; a button that opens what is open is a control with
        // nothing to do.
        // when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: true, hasFilesToSelect: true)

        // then
        #expect(layout.showsFilesButton == false)
    }

    @Test
    func `given a phone when the toolbar is built then the files button is the only way to the list`() {
        // given - when
        let layout = DiffPaneLayout(fitsSelectorColumn: false, isSelectorColumnOpen: false, hasFilesToSelect: true)

        // then
        #expect(layout.showsFilesButton)
        #expect(layout.showsSelectorColumnToggle == false)
    }

    @Test
    func `given nothing to select when the toolbar is built then neither control is offered`() {
        // given — **a worktree that failed to load, or has nothing changed in it.** A button opening
        // an empty drawer says nothing about why it is empty, and a toggle folding a column that has
        // no rows in it is the dead control this project refuses to ship.
        // when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: true, hasFilesToSelect: false)

        // then
        #expect(layout.showsFilesButton == false)
        #expect(layout.showsSelectorColumnToggle == false)
    }

    @Test
    func `given a width that fits the column and files to select when the toolbar is built then the fold is offered`() {
        // given - when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: true, hasFilesToSelect: true)

        // then
        #expect(layout.showsSelectorColumnToggle)
    }

    @Test
    func `given a phone when the code is measured then it is the smaller size`() {
        // given - when - then — 11pt is what makes the review's 54 characters fit at 402pt with one
        // number column and a marker.
        let layout = DiffPaneLayout(fitsSelectorColumn: false, isSelectorColumnOpen: false, hasFilesToSelect: true)
        #expect(layout.codePointSize == DiffPaneLayout.codePointSize)
    }

    @Test
    func `given a pane beside the column when the code is measured then it is one point larger`() {
        // given — the review's iPad measurement: an 846pt pane holds about 110 characters at 12pt,
        // so nothing in an ordinary change set is cut at all.
        // when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: true, hasFilesToSelect: true)

        // then
        #expect(layout.codePointSize == DiffPaneLayout.codePointSizeBesideTheSelector)
        #expect(DiffPaneLayout.codePointSizeBesideTheSelector > DiffPaneLayout.codePointSize)
    }

    @Test
    func `given the column is folded when the code is measured then it keeps the wider pane's size`() {
        // given — **folding the tree gives the code more room, not less.** Taking the point size
        // down with the column would reflow every row of the file the reader is looking at, in
        // exchange for nothing.
        // when
        let layout = DiffPaneLayout(fitsSelectorColumn: true, isSelectorColumnOpen: false, hasFilesToSelect: true)

        // then
        #expect(layout.codePointSize == DiffPaneLayout.codePointSizeBesideTheSelector)
    }
}
