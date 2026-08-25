/// The three screens the pairing spine pushes, as one type with one destination.
///
/// **A total switch is what makes "declare the destination beside the link" hold when the link is a
/// screen further on.** The rule exists because this app once offered a link nothing declared a
/// destination for — a chevron that compiled, drew and did nothing when tapped. Same file is the
/// rule; one route type is what keeps it true here, because the entry screen's switch covers every
/// case of this and a case added without a destination is a compile error rather than a silent tap.
///
/// **Public, while the three screens it reaches stay internal.** The baselines photograph this spine
/// the way a reader walks it — a value put on the stack the composition root owns — so something has
/// to be handed over for them to push, and this is the smallest thing there is: one route rather
/// than three screen types, and the module keeps the single entry point the root already composes.
/// A baseline that built each screen directly would be a picture of four views rather than of the
/// four pushes, which is the half of this flow no unit test can reach.
public enum PairingStep: Hashable {

    /// The viewfinder.
    case scanTheCode

    /// The field, at the same depth as the viewfinder rather than beneath it: moving between them
    /// replaces the top of the stack, so neither is ever behind the other.
    case typeTheWords

    /// What a spent credential came to.
    ///
    /// It carries nothing. What the screen draws is the model's state, and what *Try Again* would
    /// spend again is the credential the model kept — so a payload here would be a second copy of
    /// both, able to disagree with the first.
    case theOutcome
}
