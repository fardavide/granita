import Foundation

/// The intra-line comparison that turns "this whole line changed" into "this one word did".
///
/// Applied to the lines of a single hunk: maximal runs of deletions immediately followed by
/// additions are paired by position, and each pair is compared token by token. A line that is not
/// part of such a pair keeps no segments at all, which is how the client knows to highlight the
/// whole line instead.
enum WordDiff {

    static func segmented(_ lines: [DiffLine]) -> [DiffLine] {
        var segmented = lines
        // The marker for a missing trailing newline sits between the line it belongs to and the next
        // one, so a run has to look past it or no file without a trailing newline is ever paired.
        let content = lines.indices.filter { lines[$0].kind != .noNewlineMarker }
        var position = content.startIndex
        while position < content.endIndex {
            let deletions = run(of: .deletion, in: content, from: &position, lines: lines)
            let additions = run(of: .addition, in: content, from: &position, lines: lines)
            guard !deletions.isEmpty, !additions.isEmpty else {
                // Nothing consumed means neither kind matched, so step past whatever this is.
                if deletions.isEmpty && additions.isEmpty {
                    position += 1
                }
                continue
            }
            for (deletion, addition) in zip(deletions, additions) {
                guard let pair = pairedSegments(lines[deletion].text, lines[addition].text) else {
                    continue
                }
                segmented[deletion] = lines[deletion].carrying(pair.old)
                segmented[addition] = lines[addition].carrying(pair.new)
            }
        }
        return segmented
    }

    /// The segments for both sides of one pair, or `nil` when the two lines are too different or too
    /// long to be worth comparing.
    private static func pairedSegments(
        _ old: String,
        _ new: String
    ) -> (old: [WordSegment], new: [WordSegment])? {
        guard old.count <= lineLengthLimit, new.count <= lineLengthLimit else {
            return nil
        }
        let oldTokens = tokenise(old)
        let newTokens = tokenise(new)
        guard similarity(oldTokens, newTokens) >= similarityFloor else {
            return nil
        }
        let common = longestCommonSubsequence(oldTokens, newTokens)
        return (
            old: merge(oldTokens, unchanged: common.old),
            new: merge(newTokens, unchanged: common.new)
        )
    }

    /// The indices of a maximal run of one kind, advancing `position` past it.
    private static func run(
        of kind: DiffLineKind,
        in content: [Int],
        from position: inout Int,
        lines: [DiffLine]
    ) -> [Int] {
        var indices: [Int] = []
        while position < content.endIndex, lines[content[position]].kind == kind {
            indices.append(content[position])
            position += 1
        }
        return indices
    }

    /// How much two lines have in common, over their non-whitespace tokens.
    ///
    /// Whitespace is excluded deliberately. Counting it would make any two lines of similar length
    /// look alike — the runs between words match whatever the words are — and the floor exists to
    /// tell apart a line that was edited from a line that was replaced.
    private static func similarity(_ old: [Token], _ new: [Token]) -> Double {
        var remaining: [Substring: Int] = [:]
        for token in old where !token.isWhitespace {
            remaining[token.text, default: 0] += 1
        }
        let oldCount = remaining.values.reduce(0, +)
        var newCount = 0
        var shared = 0
        for token in new where !token.isWhitespace {
            newCount += 1
            if let count = remaining[token.text], count > 0 {
                remaining[token.text] = count - 1
                shared += 1
            }
        }
        guard oldCount + newCount > 0 else {
            return 1
        }
        return 2 * Double(shared) / Double(oldCount + newCount)
    }

    /// Words, punctuation runs and whitespace runs, each a token of its own.
    ///
    /// Whitespace being a token is what makes a pure indentation change isolate correctly with no
    /// special case for it anywhere.
    private static func tokenise(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var start = text.startIndex
        var index = text.startIndex
        var current: Token.Category?
        while index < text.endIndex {
            let category = Token.Category(of: text[index])
            if category != current {
                if current != nil {
                    tokens.append(Token(text: text[start..<index], category: current ?? .punctuation))
                }
                start = index
                current = category
            }
            index = text.index(after: index)
        }
        if let current, start < text.endIndex {
            tokens.append(Token(text: text[start...], category: current))
        }
        return tokens
    }

    /// Which tokens on each side are part of a longest common subsequence, and therefore unchanged.
    private static func longestCommonSubsequence(
        _ old: [Token],
        _ new: [Token]
    ) -> (old: [Bool], new: [Bool]) {
        let width = new.count + 1
        var lengths = [Int](repeating: 0, count: (old.count + 1) * width)
        for oldIndex in stride(from: old.count - 1, through: 0, by: -1) {
            for newIndex in stride(from: new.count - 1, through: 0, by: -1) {
                lengths[oldIndex * width + newIndex] = if old[oldIndex].text == new[newIndex].text {
                    lengths[(oldIndex + 1) * width + newIndex + 1] + 1
                } else {
                    max(
                        lengths[(oldIndex + 1) * width + newIndex],
                        lengths[oldIndex * width + newIndex + 1]
                    )
                }
            }
        }
        var oldUnchanged = [Bool](repeating: false, count: old.count)
        var newUnchanged = [Bool](repeating: false, count: new.count)
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < old.count, newIndex < new.count {
            if old[oldIndex].text == new[newIndex].text {
                oldUnchanged[oldIndex] = true
                newUnchanged[newIndex] = true
                oldIndex += 1
                newIndex += 1
            } else if lengths[(oldIndex + 1) * width + newIndex] >= lengths[oldIndex * width + newIndex + 1] {
                oldIndex += 1
            } else {
                newIndex += 1
            }
        }
        return (oldUnchanged, newUnchanged)
    }

    /// Adjacent tokens that agree become one segment, so a renderer walks words rather than letters.
    private static func merge(_ tokens: [Token], unchanged: [Bool]) -> [WordSegment] {
        var segments: [WordSegment] = []
        for (token, isUnchanged) in zip(tokens, unchanged) {
            if segments.last?.isChanged == !isUnchanged {
                let last = segments.removeLast()
                segments.append(WordSegment(text: last.text + token.text, isChanged: last.isChanged))
            } else {
                segments.append(WordSegment(text: String(token.text), isChanged: !isUnchanged))
            }
        }
        return segments
    }
}

/// Below this, the two lines are different lines rather than one line edited, and marking words
/// inside them is noise.
private let similarityFloor = 0.4

/// The comparison is quadratic in tokens; a minified bundle on a single line is where that bites.
private let lineLengthLimit = 1_000

private struct Token {

    let text: Substring
    let category: Category

    var isWhitespace: Bool {
        category == .whitespace
    }

    enum Category {
        case word
        case whitespace
        case punctuation

        init(of character: Character) {
            self = if character.isWhitespace {
                .whitespace
            } else if character.isLetter || character.isNumber || character == "_" {
                .word
            } else {
                .punctuation
            }
        }
    }
}

private extension DiffLine {

    func carrying(_ segments: [WordSegment]) -> DiffLine {
        DiffLine(
            kind: kind,
            oldNumber: oldNumber,
            newNumber: newNumber,
            text: text,
            displayColumns: displayColumns,
            needsMeasurement: needsMeasurement,
            segments: segments
        )
    }
}
