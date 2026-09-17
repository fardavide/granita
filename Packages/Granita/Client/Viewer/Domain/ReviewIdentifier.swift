/// How the exported review names each comment, so the reader and the agent can talk about one.
///
/// **The label is the handle that outlives the review.** The flow the reader actually runs is: write
/// the comments, copy the document, clear them. From that moment the comments exist only in the text
/// that was pasted, and an agent replying *"done, except C"* is understood only if the document
/// called something C. Without a label the reply has to quote a path and a span back, which is the
/// thing the reader was holding a phone to avoid reading.
///
/// **Two styles rather than one**, because the reader is writing the instruction that goes with it —
/// *reply to each point by its letter* and *reply to each numbered point* are both idioms an agent
/// follows, and which one reads naturally depends on the sentence around it.
public enum ReviewIdentifier: String, Hashable, Sendable, CaseIterable {

    case letters
    case numbers

    /// What the comment at this position in document order is called.
    ///
    /// **Bijective base 26 rather than a letter that runs out.** A review of an afternoon can pass
    /// twenty-six comments, and a scheme that wraps produces two comments called A — which is worse
    /// than no labels, because the agent's reply then names one of them and the reader cannot tell
    /// which. After Z the labels take a second place: AA, AB, and so on.
    public func label(at position: Int) -> String {
        switch self {
        case .letters: Self.letters(at: position)
        case .numbers: "\(position + 1)"
        }
    }

    // MARK: -

    private static func letters(at position: Int) -> String {
        var remaining = position
        var label = ""
        repeat {
            label = String(UnicodeScalar(UInt8(65 + remaining % 26))) + label
            remaining = remaining / 26 - 1
        } while remaining >= 0
        return label
    }
}
