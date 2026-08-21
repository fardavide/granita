import Foundation

// SPEC §7 asks for one real transcript to be read before this is written, and for what was found to
// be recorded here. Read on 2026-08-21 against ~/.claude/projects on this machine — 117 session
// transcripts, the largest 74 MB. Three things differ from what §7 describes:
//
//   * **`cwd` is not on every record.** It is on `user`, `assistant`, `attachment` and `system`,
//     and absent from `queue-operation`, `last-prompt`, `pr-link`, `custom-title`, `atis-latch` and
//     `bridge-session` — one of which is frequently the *first* line of the file. A reader that
//     takes the first record's `cwd` gets nothing on a real transcript. Some files carry none at
//     all, and those simply cannot be attached to a worktree.
//   * **There is no `summary` record.** §7 says to prefer "the most recent `summary` typed record";
//     across 400 files there are zero of them, against 4,468 `custom-title` records and 10,023
//     `last-prompt` records. `custom-title` is the analogue — the one piece of text a person wrote
//     to describe the session — and it is what is preferred here. `last-prompt` is deliberately not
//     used: it holds the most recent instruction, which names whatever the session has got down to
//     rather than what it is about.
//   * **`projects/*/*.jsonl` is exactly right, and `rglob` is not.** Sessions sit one level down;
//     below them are `<id>/subagents/…` transcripts — 1,237 of them against 117 real sessions here.
//     They share the session's `cwd` and their first turn is a subagent's brief, so pulling them in
//     would bury every real session under labels nobody wrote.
//
// Two things §7 gets exactly right and are kept verbatim: the head-and-tail read, without which a
// 74 MB file is loaded to name a worktree; and never reconstructing the directory name under
// `projects/`, which is a slugified path with no documented encoding.

/// What one session transcript says about the worktree it ran in.
struct SessionTranscript: Hashable, Sendable {

    let workingDirectory: String
    let branch: String?
    let label: String?

    /// Reads the two ends of a transcript.
    ///
    /// Both chunks are scanned for the same things, because which end a record falls in depends on
    /// how long the session ran rather than on what the record is.
    static func read(head: Data, tail: Data) -> SessionTranscript? {
        var workingDirectory: String?
        var branch: String?
        var title: String?
        var firstRequest: String?

        for record in records(in: head) + records(in: tail) {
            if workingDirectory == nil, let cwd = record["cwd"] as? String {
                workingDirectory = cwd
                branch = record["gitBranch"] as? String
            }
            if let customTitle = record["customTitle"] as? String, customTitle.isEmpty == false {
                title = customTitle
            }
            if firstRequest == nil, let request = typedRequest(in: record) {
                firstRequest = request
            }
        }

        guard let workingDirectory else { return nil }
        return SessionTranscript(
            workingDirectory: workingDirectory,
            branch: branch,
            label: (title ?? firstRequest).map(oneShortPlainLine)
        )
    }

    /// The text of a turn a person actually typed, or nothing.
    ///
    /// Three kinds of record look like one and are not: a subagent's own brief (`isSidechain`), the
    /// harness's own preamble (`isMeta`), and a tool's output coming back (`toolUseResult`). A
    /// fourth is harder — a task notification or a system reminder is injected as an ordinary user
    /// turn, and the only thing distinguishing it is that its text is a single wrapped block.
    private static func typedRequest(in record: [String: Any]) -> String? {
        guard record["type"] as? String == "user",
              record["isMeta"] as? Bool != true,
              record["isSidechain"] as? Bool != true,
              record["toolUseResult"] == nil,
              let message = record["message"] as? [String: Any]
        else { return nil }

        let text: String?
        switch message["content"] {
        case let string as String:
            text = string
        case let blocks as [[String: Any]]:
            text = blocks
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
        default:
            text = nil
        }

        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false,
              trimmed.hasPrefix("<") == false
        else { return nil }
        return trimmed
    }

    /// One line, no markup, at most sixty characters, ending on a word.
    ///
    /// The length is a privacy decision rather than a layout one: this text is conversation from a
    /// private repository and it goes over the network as a worktree's name.
    private static func oneShortPlainLine(_ text: String) -> String {
        var collapsed = text
            .replacingOccurrences(of: "```", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .filter { $0 != "#" && $0 != "*" && $0 != "`" && $0 != "_" }
        while collapsed.contains("  ") {
            collapsed = collapsed.replacingOccurrences(of: "  ", with: " ")
        }
        collapsed = collapsed.trimmingCharacters(in: .whitespaces)

        guard collapsed.count > 60 else { return collapsed }
        let clipped = collapsed.prefix(60)
        // On a word, so a name never ends mid-syllable. If the first sixty characters hold no
        // space at all there is no word boundary to find and the clip stands.
        guard let lastSpace = clipped.lastIndex(of: " ") else { return String(clipped) }
        return String(clipped[..<lastSpace])
    }

    /// Whole JSON records, one per line, with anything that does not parse dropped.
    ///
    /// A chunk taken from the middle of a file begins and ends mid-record, and handing a decoder
    /// half a record is the failure §7 warns about. Dropping what does not parse covers both ends
    /// without having to know which end this chunk came from.
    private static func records(in chunk: Data) -> [[String: Any]] {
        chunk.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).compactMap {
            try? JSONSerialization.jsonObject(with: Data($0)) as? [String: Any]
        }
    }
}
