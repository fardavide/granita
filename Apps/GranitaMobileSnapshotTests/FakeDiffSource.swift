import CoreDiffDomain
import Foundation

/// Diff lines a real repository would produce, for the screens design §4 draws.
///
/// **Every one of these is a case the layout has to get right rather than a case that looks nice.**
/// A run of plain context lines photographs a monospaced font; what is worth a baseline is the
/// deletion with no new number, the pair the parser segmented, the tab that has to land on the grid
/// the server measured, the wide character that would make one row taller than the number beside it,
/// and the conflict marker that arrives looking like ordinary content.

// MARK: - The lines

/// A change to one Swift function, as the parser hands it over: context, a segmented pair, and the
/// two numbers moving independently through it.
nonisolated let aChangedFunction: [DiffLine] = [
    context(old: 138, new: 138, "    /// Reads the Mac's health before spending anything."),
    context(old: 139, new: 139, "    func health() async throws(ApiFailure) -> HealthResponse {"),
    // The tab is deliberate and it is the only one here: this repository indents with spaces, and a
    // line that does not is exactly the line whose gutter alignment nobody would have checked.
    context(old: 140, new: 140, "\tlet request = Request(path: \"/v1/health\")"),
    deletion(
        old: 141,
        "        let trust = try await verify(cert)",
        segments: [
            unchanged("        let trust = try await verify("),
            changed("cert"),
            unchanged(")")
        ]
    ),
    addition(
        new: 141,
        "        let trust = try await verify(certificate)",
        segments: [
            unchanged("        let trust = try await verify("),
            changed("certificate"),
            unchanged(")")
        ]
    ),
    addition(new: 142, "        guard trust.isPinned else { throw .notUnderstood(diagnostic: nil) }"),
    context(old: 142, new: 143, "    }")
]

/// A line long enough to leave the screen, which is the whole of what wrap-off means: the code runs
/// past the trailing edge, and the numbers beside it do not go with it.
nonisolated let aLineThatRunsOffTheEdge: [DiffLine] = [
    context(old: 1_203, new: 1_203, "    private let reshapingScriptRanges: [ClosedRange<UInt32>] = ["),
    addition(
        new: 1_204,
        "        0x0590...0x08FF, // Hebrew, Arabic, Syriac, Thaana, N'Ko, Samaritan, Arabic extended A"
    ),
    context(old: 1_204, new: 1_205, "    ]")
]

/// The one status design §4 gives a badge to. They arrive as ordinary diff lines, so the parser's
/// own kind is the only thing that makes them findable.
nonisolated let aConflictedHunk: [DiffLine] = [
    context(old: 61, new: 61, "    let segments = pair(old, new)"),
    conflictMarker(old: 62, new: 62, "<<<<<<< HEAD"),
    context(old: 63, new: 63, "    return segments.merged()"),
    conflictMarker(old: 64, new: 64, "======="),
    addition(new: 65, "    return segments.collapsed()"),
    conflictMarker(old: 66, new: 66, ">>>>>>> feat/word-diff")
]

/// A wide character, a pair with no word diff, and the marker that is rendered and never counted as
/// content — three lines that each measure differently from how they look, and the reason the row
/// height is taken from the font rather than from whatever is in the row.
nonisolated let theAwkwardLines: [DiffLine] = [
    context(old: 7, new: 7, "let label = \"図形\""),
    deletion(old: 8, "let done = false"),
    addition(new: 8, "let done = true"),
    DiffLine(
        kind: .noNewlineMarker,
        oldNumber: nil,
        newNumber: nil,
        text: "\\ No newline at end of file",
        displayColumns: 27,
        segments: nil
    )
]

// MARK: - Builders

private func context(old: Int, new: Int, _ text: String) -> DiffLine {
    DiffLine(
        kind: .context,
        oldNumber: old,
        newNumber: new,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: nil
    )
}

private func addition(new: Int, _ text: String, segments: [WordSegment]? = nil) -> DiffLine {
    DiffLine(
        kind: .addition,
        oldNumber: nil,
        newNumber: new,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: segments
    )
}

private func deletion(old: Int, _ text: String, segments: [WordSegment]? = nil) -> DiffLine {
    DiffLine(
        kind: .deletion,
        oldNumber: old,
        newNumber: nil,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: segments
    )
}

private func conflictMarker(old: Int, new: Int, _ text: String) -> DiffLine {
    DiffLine(
        kind: .conflictMarker,
        oldNumber: old,
        newNumber: new,
        text: text,
        displayColumns: DisplayColumns.of(text),
        segments: nil
    )
}

private func unchanged(_ text: String) -> WordSegment {
    WordSegment(text: text, isChanged: false)
}

private func changed(_ text: String) -> WordSegment {
    WordSegment(text: text, isChanged: true)
}

/// A stand-in for the column count the server sends, near enough for a fixture: nothing on screen
/// branches on it yet, and the thing that will — wrap on — is not built.
private enum DisplayColumns {

    static func of(_ text: String) -> Int {
        text.count
    }
}
