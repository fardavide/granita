import Foundation

/// Turns the output of `git diff` into the model the viewer renders.
///
/// **It never fails.** The size guard hands it a diff cut off at a fixed number of lines, so a hunk
/// that stops half way through is an ordinary input rather than a corruption: throwing on it would
/// turn every large file into an error instead of the first two thousand lines the guard promised.
/// Anything unrecognised is skipped, and everything up to it is kept.
///
/// **It assumes the `a/` and `b/` prefixes.** They are not ambiguous with a path that begins with
/// `a/` — git writes `a/a/file` — but they are configurable, and `diff.noprefix` would silently
/// remove the first two characters of every path here. The invocation pins them; see the git layer.
public enum UnifiedDiffParser {

    public static func parse(_ text: String) -> [ParsedFileDiff] {
        let lines = splitPreservingCarriageReturns(text)
        let sectionStarts = lines.indices.filter { lines[$0].hasPrefix(headerPrefix) }
        return sectionStarts.enumerated().map { position, start in
            let end = position + 1 < sectionStarts.count ? sectionStarts[position + 1] : lines.count
            var section = FileSection(lines: lines[start..<end])
            return section.parse()
        }
    }
}

private let headerPrefix = "diff --git "

/// Split on the newline **byte**, because Swift treats a CRLF pair as one `Character` and splitting
/// on `"\n"` as a `Character` therefore does not split a CRLF file at all — it returns the whole
/// diff as a single line. The CR that remains at the end of each line is content: it is what makes
/// the file a CRLF file, and it is preserved verbatim.
private func splitPreservingCarriageReturns(_ text: String) -> [String] {
    var lines = text.utf8
        .split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
        .map { String(decoding: $0, as: UTF8.self) }
    // The final newline terminates the last line rather than starting an empty one.
    if lines.last?.isEmpty == true {
        lines.removeLast()
    }
    return lines
}

/// The lines of one `diff --git` section, and the cursor walking them.
private struct FileSection {

    private let lines: ArraySlice<String>
    private var cursor: Int
    private var oldSidePath: String?
    private var newSidePath: String?
    private var renameFrom: String?
    private var renameTo: String?
    private var isBinary = false
    private var isSubmodule = false
    private var hunks: [Hunk] = []

    /// Whether a `<<<<<<<` has been seen and not yet closed.
    ///
    /// Held across the whole file rather than reset per hunk: a conflict region longer than twice
    /// the context breaks into two hunks, and the closing marker then arrives in the second one.
    private var isInsideConflict = false

    init(lines: ArraySlice<String>) {
        self.lines = lines
        cursor = lines.startIndex
    }

    mutating func parse() -> ParsedFileDiff {
        let header = lines[cursor]
        cursor += 1
        while cursor < lines.endIndex {
            let line = lines[cursor]
            if line.hasPrefix("@@ ") {
                appendHunk()
                continue
            }
            cursor += 1
            if line.hasPrefix("--- ") {
                oldSidePath = Self.path(fromSideLine: line)
            } else if line.hasPrefix("+++ ") {
                newSidePath = Self.path(fromSideLine: line)
            } else if line.hasPrefix("rename from ") {
                renameFrom = String(line.dropFirst("rename from ".count))
            } else if line.hasPrefix("rename to ") {
                renameTo = String(line.dropFirst("rename to ".count))
            } else if line.hasPrefix("Binary files ") || line == "GIT binary patch" {
                isBinary = true
                // Whatever follows is a base85 payload, not diff content.
                break
            } else if Self.declaresGitlinkMode(line) {
                isSubmodule = true
            }
        }
        let path = renameTo ?? newSidePath ?? oldSidePath ?? Self.unchangedPath(inHeader: header) ?? ""
        let oldPath = renameFrom ?? oldSidePath
        return ParsedFileDiff(
            path: path,
            oldPath: oldPath == path ? nil : oldPath,
            isBinary: isBinary,
            isSubmodule: isSubmodule,
            hunks: hunks
        )
    }

    private mutating func appendHunk() {
        let header = HunkHeader(lines[cursor])
        cursor += 1
        guard let header else {
            return
        }
        var oldNumber = header.oldStart
        var newNumber = header.newStart
        var body: [DiffLine] = []
        while cursor < lines.endIndex {
            let line = lines[cursor]
            guard !line.hasPrefix("@@ "), !line.hasPrefix(headerPrefix), let kind = Self.kind(of: line)
            else {
                break
            }
            cursor += 1
            // The marker after a line with no trailing newline is `\ ` rather than a diff prefix.
            let text = String(line.dropFirst(kind == .noNewlineMarker ? 2 : 1))
            let width = DisplayWidth(of: text)
            let resolved = conflictMarkerKind(of: text) ?? kind
            body.append(
                DiffLine(
                    kind: resolved,
                    oldNumber: kind.occupiesOldSide ? oldNumber : nil,
                    newNumber: kind.occupiesNewSide ? newNumber : nil,
                    text: text,
                    displayColumns: width.columns,
                    needsMeasurement: width.needsMeasurement,
                    segments: nil
                )
            )
            if kind.occupiesOldSide {
                oldNumber += 1
            }
            if kind.occupiesNewSide {
                newNumber += 1
            }
        }
        hunks.append(
            Hunk(
                index: hunks.count,
                oldStart: header.oldStart,
                oldCount: header.oldCount,
                newStart: header.newStart,
                newCount: header.newCount,
                sectionHeading: header.sectionHeading,
                lines: WordDiff.segmented(body)
            )
        )
    }

    /// A conflict marker, or `nil` for an ordinary line.
    ///
    /// Only a line inside an open conflict can be a separator or a terminator, which is what stops a
    /// Markdown heading underline — a row of `=` signs — from being read as one.
    private mutating func conflictMarkerKind(of text: String) -> DiffLineKind? {
        if Self.isMarker(text, "<<<<<<<") {
            isInsideConflict = true
            return .conflictMarker
        }
        guard isInsideConflict else {
            return nil
        }
        if Self.isMarker(text, ">>>>>>>") {
            isInsideConflict = false
            return .conflictMarker
        }
        // `|||||||` introduces the common ancestor under the diff3 and zdiff3 conflict styles, which
        // an agent's own git configuration may well select.
        return Self.isMarker(text, "=======") || Self.isMarker(text, "|||||||") ? .conflictMarker : nil
    }

    private static func kind(of line: String) -> DiffLineKind? {
        switch line.first {
        case "+": .addition
        case "-": .deletion
        case " ": .context
        case "\\": .noNewlineMarker
        // git writes a leading space on a blank context line, so an empty one can only arrive from
        // something that stripped it. Keeping it as context is what preserves the numbering below.
        case nil: .context
        default: nil
        }
    }

    private static func isMarker(_ text: String, _ marker: String) -> Bool {
        text == marker || text.hasPrefix("\(marker) ")
    }

    private static func declaresGitlinkMode(_ line: String) -> Bool {
        let modeLines = ["index ", "old mode ", "new mode ", "new file mode ", "deleted file mode "]
        return line.hasSuffix("160000") && modeLines.contains { line.hasPrefix($0) }
    }

    /// The path from a `---` or `+++` line, or `nil` for `/dev/null`.
    private static func path(fromSideLine line: String) -> String? {
        var value = line.dropFirst(4)
        // git terminates the path with a TAB when it contains a space, so an applier can find where
        // the name ends.
        if value.hasSuffix("\t") {
            value = value.dropLast()
        }
        guard value != "/dev/null" else {
            return nil
        }
        return String(value.dropFirst(2))
    }

    /// The path from `diff --git a/X b/X`, for the sections that have no `---` and `+++` lines at
    /// all: a mode change, and a binary file summarised in one line.
    ///
    /// Splitting that header is ambiguous whenever a path contains a space — `a/x b/y z` divides two
    /// ways. When both sides are the same the line is exactly `2 * length + 5` characters, which
    /// resolves it, and the only case where they differ is a rename, which always carries `rename
    /// from` and `rename to` instead.
    private static func unchangedPath(inHeader header: String) -> String? {
        let value = header.dropFirst(headerPrefix.count)
        let length = value.count
        guard length > 5, !length.isMultiple(of: 2), value.hasPrefix("a/") else {
            return nil
        }
        let start = value.index(value.startIndex, offsetBy: 2)
        let end = value.index(start, offsetBy: (length - 5) / 2)
        let otherSide = value.index(end, offsetBy: 3)
        guard value[end..<otherSide] == " b/", value[otherSide...] == value[start..<end] else {
            return nil
        }
        return String(value[start..<end])
    }
}

private extension DiffLineKind {

    var occupiesOldSide: Bool {
        switch self {
        case .context, .deletion: true
        case .addition, .noNewlineMarker, .conflictMarker: false
        }
    }

    var occupiesNewSide: Bool {
        switch self {
        case .context, .addition: true
        case .deletion, .noNewlineMarker, .conflictMarker: false
        }
    }
}

/// The `@@ -oldStart,oldCount +newStart,newCount @@ heading` line.
private struct HunkHeader {

    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let sectionHeading: String?

    init?(_ line: String) {
        let afterOpening = line.dropFirst(3)
        guard line.hasPrefix("@@ "), let closing = afterOpening.range(of: " @@") else {
            return nil
        }
        let fields = afterOpening[..<closing.lowerBound].split(separator: " ")
        guard fields.count == 2,
              let old = Self.range(fields[0], sign: "-"),
              let new = Self.range(fields[1], sign: "+")
        else {
            return nil
        }
        oldStart = old.start
        oldCount = old.count
        newStart = new.start
        newCount = new.count
        // Exactly the one space git writes as a separator: the rest is the enclosing declaration,
        // whose own indentation is part of what it says.
        var heading = afterOpening[closing.upperBound...]
        if heading.hasPrefix(" ") {
            heading = heading.dropFirst()
        }
        sectionHeading = heading.isEmpty ? nil : String(heading)
    }

    /// `-1,4` or, when the count is one, `-1`.
    private static func range(_ field: Substring, sign: Character) -> (start: Int, count: Int)? {
        guard field.first == sign else {
            return nil
        }
        let numbers = field.dropFirst().split(separator: ",")
        guard let start = numbers.first.flatMap({ Int($0) }), numbers.count <= 2 else {
            return nil
        }
        guard numbers.count == 2 else {
            return (start, 1)
        }
        return Int(numbers[1]).map { (start, $0) }
    }
}
