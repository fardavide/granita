import Foundation

import CoreDiffDomain

/// A review, as the one piece of text the reader hands back to the agent that wrote the code.
///
/// **Plain text, not Markdown, which is design §7's call and a reversal of what was built first.**
/// The destination is a terminal on the Mac the phone is lying next to, and the audience is an agent
/// rather than a renderer: `#` headings and fenced blocks are syntax something has to strip before it
/// can act, and nothing downstream of the pasteboard renders them. What replaces them is the shape
/// the text already had — a path with a line span, the lines, and what the reader said about them.
///
/// Four decisions inside it, each from §7:
///
/// - **Full repository-relative paths**, never the truncated ones the phone draws. The reader is not
///   the audience; a shell is.
/// - **Document order**, matching the diff and matching the review list, so the agent walks the tree
///   once and the reader can check the list against the text line for line.
/// - **The excerpt is quoted with `> `** and is a snapshot taken when the comment was written. That
///   is what makes a stale comment worth sending: the agent gets the text the reader was looking at,
///   plus one line saying it has moved.
/// - **No note, no trace of a note.** *Skip* is one of the two answers the flow offers, and an agent
///   reading a placeholder treats it as an instruction to go and find one.
public enum ReviewFeedback {

    /// The whole review, ready for the pasteboard.
    ///
    /// The heading names the repository, the checkout and the size of the read, because the agent it
    /// is pasted to has one of those in hand and not the other two.
    public static func document(
        project: String,
        worktree: String,
        fileCount: Int,
        note: String?,
        comments: [ReviewedComment]
    ) -> String {
        let files = fileCount == 1 ? "1 file" : "\(fileCount) files"
        var parts = ["Review of uncommitted changes — \(project), worktree \(worktree), \(files)"]
        let written = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if written.isEmpty == false {
            parts.append(written)
        }
        for reviewed in comments {
            parts.append(block(of: reviewed))
        }
        return parts.joined(separator: "\n\n")
    }

    /// One comment: where it is, what it was about, and what was said.
    ///
    /// The excerpt and the reader's words sit against each other with no blank line between them,
    /// because they are one thought — the blank lines in this document separate comments, and a blank
    /// line inside one would make four comments read as eight.
    private static func block(of reviewed: ReviewedComment) -> String {
        let comment = reviewed.comment
        var lines = ["\(comment.path):\(span(of: comment.lines))"]
        if let caveat = caveat(of: reviewed) {
            lines.append(caveat)
        }
        lines.append(contentsOf: comment.quotedLines.map { "> \($0)" })
        lines.append(comment.text)
        return lines.joined(separator: "\n")
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
