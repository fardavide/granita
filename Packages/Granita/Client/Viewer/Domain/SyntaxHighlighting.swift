import CoreDiffDomain

/// Which appearance a highlighted side was lexed for.
///
/// The colours are baked into what the highlighter returns rather than applied over it, so an
/// appearance is part of the question and not a restyling of one answer. A domain spelling of it
/// rather than SwiftUI's, because deciding what invalidates a cached side is not view work.
public enum HighlightAppearance: String, Hashable, Sendable, CaseIterable {
    case light
    case dark
}

/// Why one side of a file is being rendered as plain monospaced text.
///
/// Every case is `SPEC.md` §10's, and each is a real state rather than a failure: a side that is
/// refused renders exactly as every side renders before its highlighting arrives.
public enum HighlightRefusal: Hashable, Sendable {

    /// Nothing was claimed for the extension, so there is no lexer to choose.
    case noLanguage

    /// The side has no lines at all — the old side of a wholly added file, or the new side of a
    /// wholly deleted one.
    case nothingOnThisSide

    case tooLong(lines: Int)
    case tooLarge(bytes: Int)
}

/// One side of a file as the lexer reads it, and the way back to the lines it came from.
public struct HighlightSource: Hashable, Sendable {

    public let side: DiffSide

    /// Every line of this side of the file that the diff carries, newline-joined, in file order.
    ///
    /// **It is not the file.** Hunks have gaps between them, and what is here is their union — so a
    /// construct opened in a gap and closed in a hunk is lexed without its opening. That is the
    /// approximation `SPEC.md` §10 chooses knowingly, and it is a far smaller one than lexing a
    /// hunk at a time, which gives the lexer no opening context at all.
    public let text: String

    /// The file line number each line of `text` came from, in the same order.
    public let lineNumbers: [Int]

    public init(side: DiffSide, text: String, lineNumbers: [Int]) {
        self.side = side
        self.text = text
        self.lineNumbers = lineNumbers
    }

    /// The highlighter's answer, filed under the numbers the gutter draws.
    ///
    /// Generic so that what a highlighted line *is* stays the view layer's business: this type
    /// decides which line each result belongs to and nothing about what it looks like.
    ///
    /// **A result of the wrong length is discarded whole.** The lexer is a JavaScript engine behind
    /// a bridge and the string it is handed has been through two splits; a result one line short
    /// would otherwise shift every colour after it onto the wrong line, which reads as a highlighter
    /// that is subtly wrong rather than one that did not run.
    public func indexed<T>(_ highlighted: [T]) -> [Int: T] {
        guard highlighted.count == lineNumbers.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(lineNumbers, highlighted))
    }
}

/// What the highlighter is given for one side of one file, or the reason it is given nothing.
public enum HighlightPlan: Hashable, Sendable {

    case highlight(HighlightSource)
    case refuse(HighlightRefusal)

    /// The side to lex, where there is one.
    public var source: HighlightSource? {
        switch self {
        case .highlight(let source): source
        case .refuse: nil
        }
    }
}

/// What identifies one highlighted side, so a second render reuses it and a changed one does not.
public struct HighlightKey: Hashable, Sendable {

    public let fileId: FileID
    public let contentHash: String
    public let side: DiffSide
    public let language: String
    public let appearance: HighlightAppearance
    public let pointSize: Double

    /// Which of the file's lines this side was assembled from.
    ///
    /// **`SPEC.md` §10's key is six parts and this is a seventh, because 0.4.0 made the sixth
    /// insufficient.** `contentHash` is a fact about the *file* — status and three object ids — and
    /// what gets lexed is a *subset* of the file that the reader can widen at will: expanding a
    /// hunk splices context the parser never sent, so the string grows while the hash does not.
    /// Keyed on the hash alone, the entry made before an expansion would be handed back after it and
    /// indexed against lines that are no longer where it thinks they are. The numbers are the
    /// smallest thing that tells the two questions apart. Recorded in `.claude/docs/decisions.md`.
    public let lineNumbers: [Int]

    public init(
        fileId: FileID,
        contentHash: String,
        side: DiffSide,
        language: String,
        appearance: HighlightAppearance,
        pointSize: Double,
        lineNumbers: [Int]
    ) {
        self.fileId = fileId
        self.contentHash = contentHash
        self.side = side
        self.language = language
        self.appearance = appearance
        self.pointSize = pointSize
        self.lineNumbers = lineNumbers
    }
}

/// Per file, per side, never per hunk — and which lines that is.
///
/// **The rule is `SPEC.md` §10's and so is the reason for it.** A hunk starting inside a class body,
/// a multi-line string or a heredoc gives the lexer no opening context and mis-lexes the whole
/// block, which is the same failure highlighting line-at-a-time produces. So one side of a file
/// becomes one string, is lexed once, and is split back by newline and indexed into the hunks.
///
/// **Which side a line is on is read off the numbers the parser wrote.** `UnifiedDiffParser` has
/// already decided that a context line occupies both sides, a deletion only the old and an addition
/// only the new — and that a conflict marker and git's no-newline annotation occupy neither. Asking
/// the numbers rather than re-deciding from the kind is what keeps one judgement in one place, and
/// it is what keeps `<<<<<<<` out of the string the lexer reads: a marker is not source, and a lexer
/// handed one mis-lexes everything after it.
public enum SyntaxHighlighting {

    /// `SPEC.md` §10's caps, above which a side renders plain.
    ///
    /// They are two questions rather than one: four thousand short lines and forty enormous ones are
    /// both beyond what a JavaScript lexer should be handed on a phone, and neither limit catches
    /// the other's case. The minified file is the one the line count alone misses.
    public static let lineLimit = 4_000
    public static let byteLimit = 100 * 1024

    /// What to lex for one side of a file, or why nothing.
    public static func plan(for diff: FileDiff, side: DiffSide) -> HighlightPlan {
        guard let language = diff.file.language, language.isEmpty == false else {
            return .refuse(.noLanguage)
        }
        let lines = self.lines(of: diff, side: side)
        guard lines.isEmpty == false else { return .refuse(.nothingOnThisSide) }
        guard lines.count <= lineLimit else { return .refuse(.tooLong(lines: lines.count)) }

        let text = lines.map(\.text).joined(separator: "\n")
        let bytes = text.utf8.count
        guard bytes <= byteLimit else { return .refuse(.tooLarge(bytes: bytes)) }

        return .highlight(HighlightSource(side: side, text: text, lineNumbers: lines.map(\.number)))
    }

    /// What identifies this side's highlighting, or nothing when there is none to identify.
    public static func key(
        for diff: FileDiff,
        side: DiffSide,
        appearance: HighlightAppearance,
        pointSize: Double
    ) -> HighlightKey? {
        guard let language = diff.file.language, let source = plan(for: diff, side: side).source else {
            return nil
        }
        return HighlightKey(
            fileId: diff.file.id,
            contentHash: diff.file.contentHash,
            side: side,
            language: language,
            appearance: appearance,
            pointSize: pointSize,
            lineNumbers: source.lineNumbers
        )
    }

    // MARK: -

    /// Every line of the diff that sits on one side, in file order, with the number it sits at.
    ///
    /// Document order rather than sorted: the hunks arrive in order and their lines with them, so
    /// sorting here would hide a diff that did not — and a diff whose lines are out of order is a
    /// defect worth seeing rather than one worth tidying.
    private static func lines(of diff: FileDiff, side: DiffSide) -> [(number: Int, text: String)] {
        diff.hunks.flatMap(\.lines).compactMap { line in
            let number = switch side {
            case .old: line.oldNumber
            case .new: line.newNumber
            }
            return number.map { (number: $0, text: line.text) }
        }
    }
}
