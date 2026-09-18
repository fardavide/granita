import ClientViewerDomain

/// The one sentence the review sheet says about where the review is, and where it is not.
///
/// **One place, directly above the copy button.** Sync state appears nowhere else — not in the
/// gutter, not on the rail, not on a row, not in the composer. The rail is this app's one overloaded
/// object and its whole job is to say *a row here and a mark there are the same thing*; spending it
/// on a fact that changes nothing a reader can do while reading code would cost the review feature
/// its only piece of vocabulary.
///
/// **The copy is where it does change something.** A reader about to paste is deciding whether this
/// document is everything they wrote; a reader about to press *Clear* is deciding whether it is safe
/// to destroy. Those are the two moments and both are in this sheet.
public enum ReviewSyncCopy {

    /// What to say, or nothing at all.
    ///
    /// **The absence of a sentence is the good state.** A settled review says nothing, which is why
    /// this answers with an optional rather than with a reassurance nobody needs to read twice.
    public static func caption(for sync: ReviewSync, macName: String) -> ReviewSyncCaption? {
        switch sync {
        case .settled:
            nil
        case .pending(let count, let total):
            // A count rather than a word: two of five and five of five are different decisions at
            // the moment the reader is about to paste.
            ReviewSyncCaption(
                sentence: "\(count) of \(total) \(count == 1 ? "comment is" : "comments are") "
                    + "only on this phone.",
                reason: nil,
                isUnsettled: true
            )
        case .reconciling:
            // No dot: the amber was reporting a disagreement and there is no longer one to report.
            // The reader is not asked to wait — the button under their thumb does what it did a
            // second ago.
            ReviewSyncCaption(sentence: "Sending to \(macName)…", reason: nil, isUnsettled: false)
        case .refused(let reason):
            // Our sentence, the store's underneath as small print. It takes nothing away: the copy
            // button stays filled and stays enabled, because a review that was never pushed and gets
            // pasted anyway is a complete review in the reader's hand.
            ReviewSyncCaption(
                sentence: "\(macName) cannot store this review.",
                reason: reason,
                isUnsettled: true
            )
        case .notStorable:
            ReviewSyncCaption(
                sentence: "This review is kept on this phone.",
                reason: nil,
                isUnsettled: false
            )
        }
    }

}
