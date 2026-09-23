import CoreDiffDomain

/// One drawn row of a hunk when the reader has asked for two columns: a line at full width, or two
/// cells facing each other.
///
/// **The unit of the split is the paired run and not the file, which is design §4.1's call 1.** A
/// run is a maximal stretch of deletions immediately followed by additions — the same stretch
/// `WordDiff` pairs i-th with i-th — and it is the only part of a file that *has* two sides to put
/// beside each other. Everything else is the row it is today: context, a change with only one side,
/// a conflict marker, git's no-newline annotation.
///
/// The alternative was the whole file in two columns, which is what everyone has seen on GitHub and
/// is what this rejects. Four rows in five of an ordinary change set are context, and context is the
/// same string drawn twice — so that form halves the width of every row in the file in order to
/// align the rows that are identical, and it makes the reader *check* that they are identical, which
/// is work the unified scroll never asks for. At 390pt it takes an ordinary line from 49 characters
/// to 22. Splitting the run instead spends those 22 characters only where they buy something, and
/// leaves the other four rows in five at the width they have now.
///
/// **A run of `d` deletions against `a` additions is `d + a` rows unified and `max(d, a)` split**,
/// which is arithmetic over the model rather than a measurement. That is what lets the mode change
/// without measuring anything: every row is `DiffLineHeight.at(pointSize:)` tall whatever is in it,
/// so a line's offset inside its file is its row index times a constant and the reader's place can
/// be computed rather than remembered. `SPEC.md` §10 forbids preserving a content offset across a
/// mode change, and this is what makes obeying it free.
public enum SplitDiffRow: Hashable, Sendable {

    /// A line with no other side to face, drawn on one grid across the full width.
    case full(DiffLine)

    /// One row inside a block. **At least one side is always present** — the construction below
    /// emits `max(d, a)` of these for a run of `d` against `a`, so an index past the end of one side
    /// is still inside the other.
    ///
    /// The absent side is drawn as nothing at all: no tint, no figure, no hatch. Design §4.1's call
    /// 2 — a tint would claim the side has a line there, and hatching is a new drawn texture in an
    /// app that owns exactly one. The card shows through, and absence reads as absence when
    /// everything around it is a filled rectangle.
    case block(old: DiffLine?, new: DiffLine?)

    /// The line in one of the row's two cells, or nothing where the run has run out on that side.
    ///
    /// **A full row answers with itself on both sides**, because it *is* both sides. That keeps the
    /// gutter's target arithmetic one rule rather than two: a touch resolves to a row, and the row
    /// answers for whichever cell it was aimed at.
    public func line(on side: DiffSide) -> DiffLine? {
        switch self {
        case .full(let line):
            return line
        case .block(let old, let new):
            switch side {
            case .old: return old
            case .new: return new
            }
        }
    }

    /// The rows a hunk draws, in the order the parser produced its lines.
    ///
    /// `splitting: false` is one row per line, which is what every measurement outside this type
    /// still assumes — so the unified scroll goes through the same seam rather than around it, and
    /// "the mode changes nothing here" is a thing a test can assert rather than a thing to hope for.
    ///
    /// **The run is recovered from the line kinds rather than from the word-diff segments.** A run
    /// the word differ refused to pair — too different, or a line past its thousand-character limit —
    /// still has two sides, and a re-indented long line is exactly that case. Segments say which
    /// *words* changed; kinds say which *rows* face each other, and only the second question is
    /// being asked here.
    public static func rows(of lines: [DiffLine], splitting: Bool) -> [SplitDiffRow] {
        layout(of: lines, splitting: splitting).rows
    }

    /// Which drawn row each line of the hunk ends up on, indexed the way the lines are.
    ///
    /// **Two lines share a row inside a block, which is the whole point and the whole difficulty.**
    /// Everything outside this type that thinks in lines — a comment's rail, the reader's place when
    /// the mode changes — needs the translation, and it has to come from the same walk that produced
    /// the rows or the two can disagree about where a run ended.
    public static func rowIndices(of lines: [DiffLine], splitting: Bool) -> [Int] {
        layout(of: lines, splitting: splitting).rowOfLine
    }

    /// The rows, and the row each line landed on, from one walk.
    ///
    /// One function rather than two because the mapping is a by-product of the layout: computing it
    /// separately means writing the run-forming rule down twice, and a rule written twice is a rule
    /// that is eventually two rules.
    private static func layout(
        of lines: [DiffLine],
        splitting: Bool
    ) -> (rows: [SplitDiffRow], rowOfLine: [Int]) {
        guard splitting else {
            return (lines.map(SplitDiffRow.full), Array(lines.indices))
        }
        var rows: [SplitDiffRow] = []
        var rowOfLine = [Int](repeating: 0, count: lines.count)
        var position = lines.startIndex
        while position < lines.endIndex {
            let deletions = run(of: .deletion, in: lines, from: &position)
            let additions = run(of: .addition, in: lines, from: &position)
            guard deletions.isEmpty == false, additions.isEmpty == false else {
                // One side and no other, so there is nothing to face: every line stays the width it
                // has. This is the all-additions file, the all-deletions file, and either side of a
                // conflict marker — the cases design §4.1 points at when it says the blast radius of
                // this feature is a run.
                for index in deletions + additions {
                    rowOfLine[index] = rows.count
                    rows.append(.full(lines[index]))
                }
                if deletions.isEmpty, additions.isEmpty {
                    // Neither kind matched, so this is context or an annotation. Step past it.
                    rowOfLine[position] = rows.count
                    rows.append(.full(lines[position]))
                    position += 1
                }
                continue
            }
            for offset in 0..<max(deletions.count, additions.count) {
                if offset < deletions.count {
                    rowOfLine[deletions[offset]] = rows.count
                }
                if offset < additions.count {
                    rowOfLine[additions[offset]] = rows.count
                }
                rows.append(.block(
                    old: offset < deletions.count ? lines[deletions[offset]] : nil,
                    new: offset < additions.count ? lines[additions[offset]] : nil
                ))
            }
        }
        return (rows, rowOfLine)
    }

    /// The indices of a maximal run of one kind, advancing `position` past it.
    ///
    /// **This is where the type diverges from `WordDiff`, deliberately.** That one looks *past* git's
    /// no-newline annotation when it forms a run, so a file with no trailing newline still gets its
    /// words compared. Two columns cannot do the same: the annotation is not a line of the file, so
    /// it has no side to be drawn on, and lifting it out of the middle of a block would put it
    /// somewhere the parser did not. So it ends the run, and a file whose last line changed without a
    /// trailing newline draws that one run unified — which is the same posture every other unpaired
    /// case here takes.
    private static func run(
        of kind: DiffLineKind,
        in lines: [DiffLine],
        from position: inout Int
    ) -> [Int] {
        var run: [Int] = []
        while position < lines.endIndex, lines[position].kind == kind {
            run.append(position)
            position += 1
        }
        return run
    }
}
