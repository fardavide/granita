/// How much of the phone design §3's drawer takes.
///
/// **It exists because the jump is only worth making if the reader can see where it landed.** §3
/// keeps the list up after a tap on purpose — the reader walks a change set file by file without a
/// dismiss-present cycle between each one — and that argument holds only at the half height, where
/// background interaction is enabled and the diff is still on screen behind the sheet. Pulled to the
/// whole screen the same tap scrolls a diff nobody can see, which is the drawer doing its job
/// invisibly and reading as a row that did nothing.
///
/// Two heights rather than a fraction, because they are the two detents the sheet is offered and a
/// third value here would be one the presentation cannot honour.
///
/// Only the phone has one. In a regular width §3's list is a column and this is never read.
public enum FileSelectorDrawer: Hashable, Sendable, CaseIterable {

    /// Half the screen, which is the only height that leaves the diff visible behind the sheet.
    case half

    /// The whole screen, which is the reader asking to read the list rather than the diff.
    case whole
}
