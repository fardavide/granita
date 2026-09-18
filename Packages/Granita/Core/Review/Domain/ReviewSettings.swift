/// What the reader decided about the shape of every review they export.
///
/// **A Core type because both halves hold it.** The Mac stores it and the phone and the Mac each
/// draw a control for it, so a disagreement about its shape is two surfaces claiming different
/// things about one document. The Mac owns what a review *says*; whatever a device decides about
/// how it *looks* on that device stays on the device and is not here.
public struct ReviewSettings: Hashable, Codable, Sendable {

    /// The line every exported review begins with, or nothing when the reader has not chosen one.
    ///
    /// **Three states rather than two, and the distinction is load-bearing.** Absent is the default
    /// — the reader has never touched it, and the built-in line is used. A string is theirs. An
    /// *empty* string is also theirs and is a legal answer: a review with no opening line, whose
    /// document begins at its first comment. Collapsing absent and empty would make clearing the
    /// field silently restore the default, which is the one thing the screen's *Reset* row exists to
    /// do deliberately.
    public let openingLine: String?

    public let identifier: ReviewIdentifier

    public init(openingLine: String?, identifier: ReviewIdentifier) {
        self.openingLine = openingLine
        self.identifier = identifier
    }

    /// What a Mac that has never been asked answers, and what a phone draws before it has asked.
    public static let unset = ReviewSettings(openingLine: nil, identifier: .letters)

    /// The line a review begins with when the reader has not replaced it.
    ///
    /// Here rather than at the one call site that used to state it, because two surfaces now show it
    /// as editable text before any review exists — a field pre-filled with it is the whole of what
    /// *"you will see the default one, and you will be able to edit it"* asks for.
    public static let defaultOpeningLine = "Review of uncommitted changes"

    /// The line this review actually begins with, or nothing when the reader cleared it.
    public var resolvedOpeningLine: String? {
        guard let openingLine else { return Self.defaultOpeningLine }
        return openingLine.isEmpty ? nil : openingLine
    }
}
