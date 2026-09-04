import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// Design §4's wrap-off scroll, in the four layouts it has to survive.
///
/// **A baseline cannot scroll, and that is not the limit it looks like.** What these assert is the
/// half a photograph can reach and the half that went wrong first: that the numbers are on screen at
/// the leading edge, that the code beside them is not truncated to the viewport, and that the tints
/// reach the trailing edge rather than stopping where the widest line does. Whether the gesture
/// feels right under a thumb is the device's question, and design §4 says so.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Diff file lines", .serialized)
@MainActor
struct DiffFileLinesSnapshotTests {

    @Test(arguments: DiffLinesCase.all, SnapshotLayout.all)
    func `given a file's lines when they render then they match their baseline`(
        subject: DiffLinesCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            DiffFileLines(
                lines: subject.lines,
                highestNumber: max(
                    subject.lines.compactMap(\.oldNumber).max() ?? 0,
                    subject.lines.compactMap(\.newNumber).max() ?? 0
                ),
                pointSize: subject.pointSize,
                runs: subject.runs,
                highlighted: subject.highlighted
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which case it captures, and so a failure names it too.
struct DiffLinesCase: Sendable, CustomTestStringConvertible {

    let name: String
    let lines: [DiffLine]

    /// 11pt on the phone and 12pt beside the selector column, which is the review's iPad
    /// measurement. The gutter, the marker and the row height all derive from it, so the two sizes
    /// are two different grids rather than one grid scaled.
    let pointSize: CGFloat

    /// The comment rails this hunk draws. Empty for every case that predates §7, so none of their
    /// baselines moves.
    var runs: [CommentRun] = []

    /// The lexer's answer for these lines. Nothing for every case that predates highlighting, so
    /// none of their baselines moves.
    var highlighted: HighlightedFile = .none

    var testDescription: String { name }

    static let all: [DiffLinesCase] = [
        // The ordinary case, and the one the segmented pair lives in: the deletion and the addition
        // under it differ by one word, and what says so is a background over the row's own tint.
        //
        // **It is also where the review's first fault is photographed fixed.** The deletion carries
        // its old-side number now, where before it drew an empty gutter — so the two rows of the
        // pair both have something a reader can point at.
        DiffLinesCase(name: "a-changed-function", lines: aChangedFunction, pointSize: 11),

        // The same lines at the iPad's size, where 846pt of pane holds about 110 characters.
        DiffLinesCase(name: "a-changed-function-beside-the-selector", lines: aChangedFunction, pointSize: 12),

        // Wrap off means this line leaves the screen and the numbers do not follow it. The baseline
        // holds the resting position, which is the one where the defect showed: the code must run
        // past the trailing edge rather than truncate at it, and the gutter must still be at the
        // leading edge rather than pushed off it by the code's own width.
        //
        // **And it is the only case that photographs the fade and the indicator.** The review's
        // third fault is a line that ends at the bezel looking complete; what a baseline can hold is
        // that the last characters are fading rather than cut, and that the 3pt bar under the hunk
        // says there is more to the right.
        DiffLinesCase(name: "a-line-past-the-edge", lines: aLineThatRunsOffTheEdge, pointSize: 11),

        // The one status worth a badge, and here the row half of it: a full-width warning tint and
        // the marker text at semibold, so a reader scrolling finds them without reading them. Its
        // marker column is deliberately empty — a conflict marker is neither side of the comparison.
        DiffLinesCase(name: "a-conflicted-hunk", lines: aConflictedHunk, pointSize: 11),

        // Three lines that each measure differently from how they look, which is the case the row
        // height exists for: a taller row would misalign every number below it.
        DiffLinesCase(name: "the-awkward-lines", lines: theAwkwardLines, pointSize: 12),

        // **The column is sized from the larger side, and this is the file that proves it.** A
        // hundred lines deleted from the end leaves an old side running into four figures while the
        // new side stops at two — sized on the new maximum, the old numbers would not fit the column
        // they are drawn in.
        DiffLinesCase(name: "an-old-side-that-outruns-the-new", lines: anOldSideThatOutrunsTheNew, pointSize: 11),

        // MARK: - Design §7.3's rail

        // **One row, which is the shortest a rail gets: an 18pt stub.** What this holds is the thing
        // the whole treatment turns on — that 3pt in the leading inset does not move a single figure,
        // a single marker, or a single character of code. Compare it against `a-changed-function`,
        // which is the same lines with no rail: everything but the rail is identical.
        DiffLinesCase(
            name: "a-rail-on-one-row",
            lines: aChangedFunction,
            pointSize: 11,
            runs: [CommentRun(firstRow: 2, rowCount: 1, isPending: false)]
        ),

        // **Four rows, which is the case length has to carry.** Design §7.3 spends the rail's whole
        // argument on this: a run reads as a run without a count, without colour and without a point
        // of new height, because the bar is simply four times as long.
        DiffLinesCase(
            name: "a-rail-across-four-rows",
            lines: aChangedFunction,
            pointSize: 11,
            runs: [CommentRun(firstRow: 1, rowCount: 4, isPending: false)]
        ),

        // **Square caps, which mean a run being picked out rather than a comment that exists.** It is
        // a difference in shape rather than in colour on purpose, so it survives a greyscale
        // screenshot and a reader who cannot tell indigo from blue — which is exactly what a baseline
        // pair like this one and the two above it can be asked to show.
        DiffLinesCase(
            name: "a-rail-still-being-picked-out",
            lines: aChangedFunction,
            pointSize: 11,
            runs: [CommentRun(firstRow: 1, rowCount: 2, isPending: true)]
        ),

        // **Two comments in one hunk, with a gap between them.** Design §7.3 says they must read as
        // separate objects rather than as one long mark with a break in it, and nothing but the gap
        // says so.
        DiffLinesCase(
            name: "two-rails-in-one-hunk",
            lines: aChangedFunction,
            pointSize: 11,
            runs: [
                CommentRun(firstRow: 0, rowCount: 1, isPending: false),
                CommentRun(firstRow: 3, rowCount: 2, isPending: false)
            ]
        ),

        // **The narrowest gutter a change set can produce**, where the strip is about 38pt rather
        // than 51 and the leading inset is the same 4pt it always is. If the rail were going to
        // collide with a figure anywhere, it would be here.
        DiffLinesCase(
            name: "a-rail-on-a-short-file",
            lines: aShortFile,
            pointSize: 11,
            runs: [CommentRun(firstRow: 1, rowCount: 2, isPending: false)]
        ),

        // MARK: - The lexer's colours

        // **The two treatments in one row, which is the only place they can be checked against each
        // other.** The word diff is a *background* and the lexer owns the *text* colour — that is
        // why design §4's inverted emphasis was reverted to `SPEC.md` §10 on 28 August 2026 — so
        // what this holds is `certificate` sitting under a green background while `let` stays
        // Xcode's magenta and the string beside it stays its red. Compare against
        // `a-changed-function`, which is the same lines with no lexer: every tint, every figure and
        // every marker is identical and only the text colour moves.
        DiffLinesCase(
            name: "a-changed-function-highlighted",
            lines: aChangedFunction,
            pointSize: 11,
            highlighted: aLexedChangedFunction
        ),

        // **A colouring the row cannot line up with, which draws plain rather than wrongly.**
        // highlight.js decodes HTML entities on its way back, so a file with `&amp;` written in it
        // literally can return a line shorter than the one it was given — and a background applied
        // at an offset into a shorter string paints the wrong word. The third row here is the
        // refusal; every other row in the same file keeps its colours, which is the half worth
        // photographing.
        DiffLinesCase(
            name: "a-highlight-that-does-not-fit",
            lines: aChangedFunction,
            pointSize: 11,
            highlighted: aLexedChangedFunctionWithOneLineShort
        )
    ]
}

// MARK: - The lexer's answers, hand-built

/// Xcode's own light palette, as `xcode.min.css` declares it.
///
/// **Hand-built rather than lexed, and the screen suites are where highlight.js is held to
/// account.** What this pair of cases is for is the *merge* — a word-diff background over coloured
/// text, and a row refusing a colouring it cannot line up with — so the answer wants to be one a
/// reader can check against the drawn string by eye.
private enum XcodeLight {

    static let keyword = Color(red: 0.667, green: 0.051, blue: 0.569)
    static let string = Color(red: 0.769, green: 0.102, blue: 0.086)
    static let comment = Color(red: 0, green: 0.455, blue: 0)
    static let type = Color(red: 0.361, green: 0.149, blue: 0.600)
}

private let aLexedChangedFunction = HighlightedFile(old: lexedChangedFunction.old, new: lexedChangedFunction.new)

/// The same answer with one line replaced by a shorter one, which is what the row has to refuse.
///
/// Line 140 rather than a line of the changed pair, so the picture shows a row falling back to plain
/// *while its neighbours keep their colours* — a case where every row lost them would look like a
/// highlighter that had not run.
private let aLexedChangedFunctionWithOneLineShort = HighlightedFile(
    old: lexedChangedFunction.old,
    new: lexedChangedFunction.new.merging([140: AttributedString("let request")]) { _, shortened in shortened }
)

private let lexedChangedFunction = lexing(
    aChangedFunction,
    colouring: [
        ("///", XcodeLight.comment),
        ("func", XcodeLight.keyword),
        ("let", XcodeLight.keyword),
        ("try", XcodeLight.keyword),
        ("await", XcodeLight.keyword),
        ("guard", XcodeLight.keyword),
        ("else", XcodeLight.keyword),
        ("throw", XcodeLight.keyword),
        ("async", XcodeLight.keyword),
        ("throws", XcodeLight.keyword),
        ("Request", XcodeLight.type),
        ("HealthResponse", XcodeLight.type),
        ("ApiFailure", XcodeLight.type),
        ("\"/v1/health\"", XcodeLight.string)
    ]
)

/// Colours every occurrence of each token, on the string the row actually draws.
///
/// Built from `MonospacedGrid.expandingTabs` rather than from the raw line, because that is the
/// string the offsets have to line up with — one of these lines is tab-indented precisely so a
/// colouring measured against the raw text would be visibly wrong here.
private func lexing(
    _ lines: [DiffLine],
    colouring tokens: [(String, Color)]
) -> (old: [Int: AttributedString], new: [Int: AttributedString]) {
    var old: [Int: AttributedString] = [:]
    var new: [Int: AttributedString] = [:]
    for line in lines {
        var text = AttributedString(MonospacedGrid.expandingTabs(in: line.text))
        for (token, colour) in tokens {
            var searched = text.startIndex
            while let found = text[searched...].range(of: token) {
                text[found].foregroundColor = colour
                searched = found.upperBound
            }
        }
        if let number = line.oldNumber {
            old[number] = text
        }
        if let number = line.newNumber {
            new[number] = text
        }
    }
    return (old, new)
}

// MARK: -

/// A file of nine lines, so its figure column is one digit wide — the narrowest gutter, and the
/// tightest the rail's 3pt ever has to sit in.
private let aShortFile: [DiffLine] = [
    DiffLine(kind: .context, oldNumber: 6, newNumber: 6, text: "func main() {", displayColumns: 13, segments: nil),
    DiffLine(kind: .deletion, oldNumber: 7, newNumber: nil, text: "    print(\"hi\")", displayColumns: 15, segments: nil),
    DiffLine(kind: .addition, oldNumber: nil, newNumber: 7, text: "    print(\"hello\")", displayColumns: 18, segments: nil),
    DiffLine(kind: .context, oldNumber: 8, newNumber: 8, text: "}", displayColumns: 1, segments: nil)
]
