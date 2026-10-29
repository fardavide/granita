import CoreDiffDomain

public struct PreparedFileDiff: Hashable, Sendable {
    public let diff: FileDiff
    public let linesByHunk: [Int: PreparedDiffLines]

    public init(diff: FileDiff) {
        self.diff = diff
        linesByHunk = diff.hunks.reduce(into: [:]) { prepared, hunk in
            prepared[hunk.index] = PreparedDiffLines(lines: hunk.lines)
        }
    }

    private init(diff: FileDiff, linesByHunk: [Int: PreparedDiffLines]) {
        self.diff = diff
        self.linesByHunk = linesByHunk
    }

    func viewed(_ isViewed: Bool) -> PreparedFileDiff {
        PreparedFileDiff(
            diff: FileDiff(
                file: diff.file.viewed(isViewed),
                hunks: diff.hunks,
                oldLineCount: diff.oldLineCount,
                newLineCount: diff.newLineCount,
                isTruncated: diff.isTruncated,
                truncationReason: diff.truncationReason
            ),
            linesByHunk: linesByHunk
        )
    }
}
