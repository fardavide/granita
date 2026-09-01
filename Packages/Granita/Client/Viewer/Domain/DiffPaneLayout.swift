import Foundation

/// What the diff screen shows at a given width, and what the reader has folded away.
///
/// **It is a value rather than four computed properties on the screen**, because one of them decides
/// whether a control exists at all. A `NavigationLink` with no destination shipped in this app for
/// eight releases and every snapshot of it stayed green, so "is this control offered, and can the
/// reader get back what pressing it takes away" is a question that belongs somewhere a test can ask
/// it directly rather than somewhere only a photograph can.
///
/// The width is handed in as a `Bool` rather than a size class: whether a 320pt column fits is a fact
/// about the room available, and an iPad in a narrow multitasking width is the phone's layout too.
public struct DiffPaneLayout: Hashable, Sendable {

    /// 11pt, and every measurement in design §4 is taken at it: it is what makes the review's 54
    /// characters fit at 402pt with one number column and a marker.
    public static let codePointSize: CGFloat = 11

    /// One point larger beside the selector column, which is the review's iPad measurement: an 846pt
    /// pane holds about 110 characters at 12pt, so nothing in an ordinary change set is cut.
    ///
    /// A second constant rather than a scale factor, because `SPEC.md` §10 makes the code size a
    /// setting and these are its two defaults rather than a rule about screens.
    public static let codePointSizeBesideTheSelector: CGFloat = 12

    /// The tree beside the code, at `FileSelectorView.widthBesideTheDiff`.
    public let showsSelectorColumn: Bool

    /// The way to the drawer, which is the phone's only route to the list — and the iPad's route
    /// back once the column is folded.
    public let showsFilesButton: Bool

    /// The fold itself, offered only where a column could exist and there is something to put in it.
    public let showsSelectorColumnToggle: Bool

    public let codePointSize: CGFloat

    public init(fitsSelectorColumn: Bool, isSelectorColumnOpen: Bool, hasFilesToSelect: Bool) {
        let showsColumn = fitsSelectorColumn && isSelectorColumnOpen
        showsSelectorColumn = showsColumn
        // **Never both, and never neither while there are files.** The button opens what the column
        // already shows, so offering both is two controls for one job; and withholding both while a
        // width could show the tree would make the fold a one-way door.
        showsFilesButton = hasFilesToSelect && showsColumn == false
        // A toggle for a layout that cannot exist, or for a list with no rows, is a control that
        // does nothing — which is the one thing this project will not ship.
        showsSelectorColumnToggle = fitsSelectorColumn && hasFilesToSelect
        // **Taken from the room, not from the fold.** Folding the tree gives the code more space;
        // taking the point size down with the column would reflow every row of the file the reader
        // is looking at in exchange for nothing.
        codePointSize = fitsSelectorColumn ? Self.codePointSizeBesideTheSelector : Self.codePointSize
    }
}
