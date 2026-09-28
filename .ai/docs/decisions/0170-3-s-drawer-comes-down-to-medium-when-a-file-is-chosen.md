# §3's drawer comes down to medium when a file is chosen

*(1 September 2026, 0.6.1)*

`presentationBackgroundInteraction(.enabled(upThrough: .medium))` is what makes §3's sheet a drawer
rather than a modal, and *up through medium* is the modifier's own boundary. At the large detent the
sheet covers the phone: the diff is neither visible nor scrollable behind it, so a tap on a row jumps
a scroll nobody can see. The row did something and the reader has no way to know, which is the one
failure this repository treats as unshippable.

Choosing a file now writes the detent back to medium. **Reduced rather than dismissed** — Davide's own
preference, and the weaker intervention: shutting the drawer would cost the reader the list they are
working down, and §3 keeps the list up precisely so it need not be reopened between files.

The height lives on `ClientViewerModel` rather than in the screen's `@State`, which is the rule this
repository wrote down for `isShowingSelector` and for the Mac's Devices tab: a control whose only
effect is a `@State` two layers up is a control nothing can be asked about. `FileSelectorDrawer` is a
domain enum with two cases, and the model carries a `drawerDetent` beside it that translates one to
the other — so the screen hands the sheet `$model.drawerDetent` and holds no rule of its own.

**The translation is on the model because the alternative is untestable, and the coverage gate is
what said so.** Written at the call site it is a `Binding(get:set:)` — two closures inside a `.sheet`
builder that no rendered baseline invokes and no host test reaches, which is *which height means
what* living in the one place nothing here can ask about it. That is five uncovered regions and a
failing Snapshot row, and the row was right: the rule really was unreachable. Moved onto the model it
is two accessors a unit test drives in four lines, and the screen is left with the framework's own
projection and no code at all.

The `swift-testing` skill's standing answer to a falling Snapshot row is *do not restructure the
screen, read the export and say so* — and that still holds for an action closure, which is a control
being pressed and genuinely undrivable. This was not one. It was a decision hiding in a binding, and
taking decisions out of view code is a rule this repository already had.

Rejected: dismissing the sheet, which is the modal §3 rejected arriving by another door. Rejected:
offering only the medium detent, which takes away a reader's ability to read a long file list.
Rejected: exempting the screen from the Snapshot row — `UNREACHABLE_FILES`'s bar is "unrunnable by
construction" and a file-level exemption would have removed the fifty regions a baseline *does* cover
in that screen along with the five it does not, which lowers the row rather than correcting it. That
is the arithmetic the existing entries warn about.

