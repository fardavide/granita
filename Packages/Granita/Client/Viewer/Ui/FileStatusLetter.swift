import SwiftUI

import CoreDiffDomain

/// Seven statuses, four colour treatments — design §3's palette, drawn once for the two screens that
/// use it.
///
/// It is one view rather than a rule written twice because the selector and the diff's file header
/// are the same column of letters seen from two places: a reader scans them in the sheet and then
/// reads the same letter at the top of the file they jumped to. Two implementations is two chances
/// for a rename to be green in one of them, which is the exact mistake the indigo exists to prevent.
public struct FileStatusLetter: View {

    private let status: FileStatus

    public init(status: FileStatus) {
        self.status = status
    }

    public var body: some View {
        Text(verbatim: letter)
            .font(.footnote.monospaced().weight(.semibold))
            .foregroundStyle(colour)
            .accessibilityLabel(spelledOut)
    }

    private var letter: String {
        switch status {
        case .added: "A"
        case .modified: "M"
        case .deleted: "D"
        case .renamed: "R"
        case .typeChanged: "T"
        case .untracked: "U"
        case .conflicted: "C"
        }
    }

    private var colour: Color {
        fileStatusColour(status)
    }

    private var spelledOut: String {
        spelledOutFileStatus(status)
    }
}

/// The same seven statuses as a 3pt bar, which is what the diff's file header shows instead of a
/// letter.
///
/// **Every status carries one, modified included.** `design.md` §3 gave modified no colour at all —
/// four rows in five are modified, and colouring the default case spends the palette on the field
/// carrying no information — and the diff design review replaced the letter with a bar that has to
/// be *some* colour or be absent. An absent bar on four rows in five is a column of holes rather than
/// a column, so Davide settled it on 1 September 2026: every state is reflected, and modified keeps a
/// bar. Amber is the review's own choice for it.
///
/// The letter survives in §3's selector, where a column of letters is scannable and 3pt of colour
/// repeated down a 32pt row is not.
public struct FileStatusBar: View {

    /// Takes no width worth measuring and is legible at a glance, which is what the letter was not
    /// once the filename moved onto its own line beside it.
    public static let width: CGFloat = 3

    /// Shorter than the two lines beside it, so it reads as a marker on the row rather than a rule
    /// dividing it from the chevron.
    public static let height: CGFloat = 24

    private let status: FileStatus

    public init(status: FileStatus) {
        self.status = status
    }

    public var body: some View {
        Capsule()
            .fill(fileStatusColour(status))
            .frame(width: Self.width, height: Self.height)
            .accessibilityLabel(spelledOutFileStatus(status))
    }
}

/// One colour rule for the letter and the bar, because the selector and the diff's file header are
/// the same status seen from two places.
///
/// Two implementations would be two chances for a rename to be green in one of them, which is the
/// exact mistake the indigo exists to prevent.
///
/// Green covers both statuses that mean "this is new code", because to a reader of uncommitted work
/// the difference between added and untracked is git bookkeeping — the accessibility label is where
/// that distinction survives.
func fileStatusColour(_ status: FileStatus) -> Color {
    switch status {
    case .added, .untracked: .green
    case .deleted: .red
    // Not green. A rename adds no code, and reading it as an addition is the mistake this colour
    // exists to prevent.
    case .renamed: .indigo
    // The one status that means *you must look at this*.
    case .conflicted: .orange
    case .modified, .typeChanged: .fileStatusAmber
    }
}

extension Color {

    /// The review's own amber for modified, and the one literal colour in this file.
    ///
    /// **It is a literal because the palette has no room left.** Green, red, indigo and orange are
    /// already spoken for by the other four treatments, and the system's `.yellow` against white at
    /// 3pt is too weak to be a marker. Design named `#C0821F`, which is a mid-tone: it holds against
    /// both the light card and the dark one, which is why it does not need a per-appearance pair.
    ///
    /// It is deliberately *not* `.orange`. Conflicted is orange, and two statuses a reader cannot
    /// tell apart is worse than a status with no colour at all — which is what modified used to have.
    static let fileStatusAmber = Color(red: 0.753, green: 0.510, blue: 0.122)
}

func spelledOutFileStatus(_ status: FileStatus) -> String {
    switch status {
    case .added: "Added"
    case .modified: "Modified"
    case .deleted: "Deleted"
    case .renamed: "Renamed"
    case .typeChanged: "Type changed"
    case .untracked: "Untracked"
    case .conflicted: "Conflicted"
    }
}

/// `+n −m`, in the one spelling both screens use.
///
/// A `Text` rather than a view, so a caller can interpolate it into a sentence or drop it into a row
/// without the two rendering differently — and so it truncates as part of whatever it is in.
///
/// **A side that changed nothing is not printed**, which is Davide's call on 1 September 2026 and is
/// the same argument design §3 already makes about modified getting no colour: `+0` is the field
/// carrying no information, and on a binary file or a rename that changed nothing it was the whole
/// of what the row said about the change — `+0 −0`, twice as wide as it is useful, and wide enough
/// on those two rows to push the counts under the bezel. What is left is a number the reader can
/// only read one way.
public func changeStatsText(_ stats: ChangeStats) -> Text {
    switch (stats.insertions, stats.deletions) {
    // Nothing at all, rather than a zero pair. A binary file and a rename with no content change
    // both say what they are on the line below the name, which is where that belongs.
    case (0, 0): Text(verbatim: "")
    case (let added, 0): plus(added)
    case (0, let removed): minus(removed)
    case (let added, let removed): Text("\(plus(added)) \(minus(removed))")
    }
}

private func plus(_ insertions: Int) -> Text {
    Text("+\(insertions, format: .number)").foregroundColor(.green)
}

private func minus(_ deletions: Int) -> Text {
    Text("−\(deletions, format: .number)").foregroundColor(.red)
}
