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

    /// **Modified gets no colour at all**, which is the call worth restating: four rows in five are
    /// modified, and colouring the default case spends the palette on the field carrying no
    /// information.
    ///
    /// Green covers both statuses that mean "this is new code", because to a reader of uncommitted
    /// work the difference between added and untracked is git bookkeeping — the accessibility label
    /// is where that distinction survives.
    private var colour: Color {
        switch status {
        case .added, .untracked: .green
        case .deleted: .red
        // Not green. A rename adds no code, and reading it as an addition is the mistake this letter
        // exists to prevent.
        case .renamed: .indigo
        case .conflicted: .orange
        case .modified, .typeChanged: .secondary
        }
    }

    private var spelledOut: String {
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
}

/// `+n −m`, in the one spelling both screens use.
///
/// A `Text` rather than a view, so a caller can interpolate it into a sentence or drop it into a row
/// without the two rendering differently — and so it truncates as part of whatever it is in.
public func changeStatsText(_ stats: ChangeStats) -> Text {
    let added = Text("+\(stats.insertions, format: .number)").foregroundColor(.green)
    let removed = Text("−\(stats.deletions, format: .number)").foregroundColor(.red)
    return Text("\(added) \(removed)")
}
