import Foundation

import CoreDiffDomain

/// A review, as the one piece of text the reader hands back to the agent that wrote the code.
///
/// **A fenced code block, not a quotation — and that is a reversal of design §7's own reversal.**
/// The first build was Markdown, §7 overturned it for plain text on the grounds that the audience is
/// an agent rather than a renderer, and Davide overturned that again on 16 September 2026: *"I want
/// to use a proper code block instead of a quote block"*, tagged with the language the way Markdown
/// tags one. The excerpt **is** code, a fence is the notation that says so, and every agent this is
/// pasted to reads fences natively — a `> ` prefix, by contrast, is a character an agent has to strip
/// off every line before it can search the file for what it was handed. Recorded in
/// `.ai/docs/decisions.md`.
///
/// What survives both reversals is the shape, and §7's decisions about it:
///
/// - **Full repository-relative paths**, never the truncated ones the phone draws. The reader is not
///   the audience; a shell is.
/// - **Document order**, matching the diff and matching the review list, so the agent walks the tree
///   once and the reader can check the list against the text line for line.
/// - **The excerpt is a snapshot taken when the comment was written.** That is what makes a stale
///   comment worth sending: the agent gets the text the reader was looking at, plus one line saying
///   it has moved.
/// - **No note, no trace of a note.** *Skip* is one of the two answers the flow offers, and an agent
///   reading a placeholder treats it as an instruction to go and find one.
///
/// **The caveats stay outside the fence**, because they are this app talking about the code rather
/// than lines of it, and a sentence of English inside a `swift` block is the one thing a fence
/// promises will not be there.
public enum ReviewFeedback {

    /// The whole review, ready for the pasteboard.
    ///
    /// **The heading names nothing, and it used to name three things.** It carried the project, the
    /// worktree and the size of the read on the argument that the agent had one of those in hand and
    /// not the other two. Davide overturned it on 16 September 2026 — *"they are contexts that the
    /// session already has"* — and he is right about where this text lands: a session running in the
    /// checkout knows which checkout it is in, so the line spent three facts telling it what it could
    /// already see. What is left is the one thing the text has to establish, which is what kind of
    /// thing it is.
    ///
    /// **The comments are separated by a rule rather than by a blank line**, which is the same
    /// conversation's other call: *"otherwise it's a little bit difficult to read the prompt"*. A
    /// blank line already separates the parts *inside* a comment from each other elsewhere in the
    /// document, so four comments run together into one wall; `---` is the one separator Markdown has
    /// that cannot be mistaken for a paragraph break. The first one also divides the note from the
    /// comments, which earns its place for the same reason — the note is about the change as a whole
    /// and everything under the rule is about lines.
    public static func document(
        note: String?,
        identifiers: ReviewIdentifier,
        comments: [ReviewedComment]
    ) -> String {
        var parts = ["Review of uncommitted changes"]
        let written = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if written.isEmpty == false {
            parts.append(written)
        }
        for (position, reviewed) in comments.enumerated() {
            parts.append("---")
            parts.append(block(of: reviewed, labelled: identifiers.label(at: position)))
        }
        return parts.joined(separator: "\n\n")
    }

    /// One comment: what it is called, where it is, what it was about, and what was said.
    ///
    /// The fence and the reader's words sit against each other with no blank line between them,
    /// because they are one thought — the blank lines in this document separate comments, and a blank
    /// line inside one would make four comments read as eight.
    private static func block(of reviewed: ReviewedComment, labelled label: String) -> String {
        let comment = reviewed.comment
        var lines = ["\(label). \(comment.path):\(span(of: comment.lines))"]
        if let caveat = caveat(of: reviewed) {
            lines.append(caveat)
        }
        let fence = self.fence(clearing: comment.quotedLines)
        lines.append(fence + (comment.language ?? ""))
        lines.append(contentsOf: comment.quotedLines)
        lines.append(fence)
        lines.append(comment.text)
        return lines.joined(separator: "\n")
    }

    /// A fence long enough that nothing in the excerpt can close it early.
    ///
    /// **The excerpt is arbitrary text and one of the files this app is most often pointed at is
    /// Markdown**, so three backticks are not a safe default: a line of the quoted code that is
    /// itself a fence ends the block where it sits, and everything after it — the closing fence, the
    /// reader's own comment, and every comment below — reads to the agent as prose rather than as the
    /// code it was quoting. CommonMark's answer is the one taken here: an outer fence longer than the
    /// longest run inside cannot be closed by any of them.
    ///
    /// The run is counted wherever it appears on the line rather than only at the start, because the
    /// cost of over-counting is one backtick and the cost of under-counting is the defect above.
    private static func fence(clearing lines: [String]) -> String {
        let longest = lines.reduce(0) { longest, line in
            var longest = longest
            var run = 0
            for character in line {
                run = character == "`" ? run + 1 : 0
                longest = max(longest, run)
            }
            return longest
        }
        return String(repeating: "`", count: max(3, longest + 1))
    }

    /// The one line that says the numbers above it do not mean what they look like.
    ///
    /// **Two cases, and staleness wins when both are true**, because it is the stronger statement:
    /// lines that are not in the diff at all cannot also be usefully described as removed by it.
    ///
    /// **The old-side line is an addition to what §7 drew**, and the reason is the one thing the
    /// frame's own example could not show. It quotes four additions and one deletion whose comment
    /// text happens to say it was deleted; a run named on the old side is lines that exist nowhere in
    /// the working copy, so an agent opening the file at those numbers reads whatever now sits there.
    /// Naming it costs one line in the case that needs it and nothing in the case that does not, and
    /// it borrows the idiom the stale line already established rather than inventing a second one.
    private static func caveat(of reviewed: ReviewedComment) -> String? {
        if reviewed.isStale {
            return "(these lines are no longer in the current diff)"
        }
        switch reviewed.comment.lines.side {
        case .new: return nil
        case .old: return "(these lines were removed — the numbers are from before the change)"
        }
    }

    private static func span(of lines: CommentedLines) -> String {
        lines.first == lines.last ? "\(lines.first)" : "\(lines.first)-\(lines.last)"
    }
}
