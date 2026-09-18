/// What the review sheet says about where the review is, ready to draw.
///
/// **A value rather than a sentence built in the view**, because the wording is a decision and the
/// view layer is where decisions stop: `Ui` renders what it is handed and reports what happened. The
/// wording lives with the rest of this unit's copy, one layer out.
///
/// `nil` in place of one of these is how a settled review is drawn — the absence of a sentence is
/// the good state, so there is no "everything is fine" case here to render.
public struct ReviewSyncCaption: Hashable, Sendable {

    public let sentence: String

    /// The store's own words, where there are any. Never advice, and never in place of the sentence
    /// above it.
    public let reason: String?

    /// Whether the two copies of this review disagree, which is the only thing the amber dot ever
    /// means — the same figure, for the same reason, as the stale comment row.
    public let isUnsettled: Bool

    public init(sentence: String, reason: String?, isUnsettled: Bool) {
        self.sentence = sentence
        self.reason = reason
        self.isUnsettled = isUnsettled
    }
}
