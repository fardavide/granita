/// How much of the review in front of the reader has reached the Mac.
///
/// **Per review rather than per comment.** The reader's question is whether this document is
/// everything they wrote, which is a fact about the set — and a mark per row would spend the review
/// feature's one piece of vocabulary, the indigo rail, on something that changes nothing they can do
/// while reading code.
///
/// **A count rather than a word**, because two of five and five of five are different decisions at
/// the moment that matters.
public enum ReviewSync: Hashable, Sendable {

    /// The Mac has everything. Drawn as nothing at all: the absence of a sentence is the good state.
    case settled

    /// Written here and not yet accepted there, with how many of the review's comments that is.
    case pending(count: Int, of: Int)

    /// A push is in flight. The reader is not asked to wait — the button under their thumb does what
    /// it did a second ago.
    case reconciling

    /// The Mac answered and refused, carrying whatever it said so the reader is not left guessing.
    case refused(reason: String?)

    /// There is no Mac to reach, or the one this phone is reading from is too old to store a review.
    /// Nothing is queued, because queueing needs an addressee.
    case notStorable
}
