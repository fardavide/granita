import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// Every changed file in one scroll, which is `SPEC.md` §10's locked decision and the screen this
/// product exists for.
///
/// **One section per file in a lazy stack with pinned headers**, which is design §4's own
/// implementation note and the shape that keeps the no-reflow rule intact: pinning is a rendering
/// position rather than a layout change, so nothing above the reader's finger moves when a header
/// sticks.
///
/// **A file that has not arrived reserves its height rather than collapsing.** The change set names
/// every file before any diff is fetched, so all of them are drawn from the first frame and the
/// estimate holds the space. Correcting an estimate is invisible below the viewport and is the
/// defect above it, which is why `ContinuousDiffLoading` never fetches backwards.
public struct ContinuousDiffView: View {

    private let entries: [ContinuousDiffEntry]
    private let showsOldNumber: Bool
    private let onReading: (Int) -> Void

    public init(
        entries: [ContinuousDiffEntry],
        showsOldNumber: Bool,
        onReading: @escaping (Int) -> Void
    ) {
        self.entries = entries
        self.showsOldNumber = showsOldNumber
        self.onReading = onReading
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { position, entry in
                    Section {
                        content(of: entry)
                            // **The position is reported on appearance rather than from a scroll
                            // offset.** `SPEC.md` §10 says to track this with visibility and never
                            // with `contentOffset`, and the reason is the same one the whole screen
                            // turns on: an offset is a number about a layout that is allowed to be
                            // wrong below the fold, and a file appearing is a fact.
                            .onAppear { onReading(position) }
                    } header: {
                        DiffFileHeader(file: entry.file)
                    }
                }
            }
        }
    }

    @ViewBuilder private func content(of entry: ContinuousDiffEntry) -> some View {
        switch entry {
        case .awaiting:
            // Deliberately empty rather than a spinner. There is no per-file progress worth
            // reporting — five files are in flight at once and the reader is not waiting on any of
            // them — and a row of spinners scrolling past would be the app describing its own
            // plumbing.
            Color.clear
                .frame(height: reservedHeight(of: entry))
        case .ready(let diff):
            DiffFileContent(hunks: diff.hunks, showsOldNumber: showsOldNumber)
        }
    }

    private func reservedHeight(of entry: ContinuousDiffEntry) -> CGFloat {
        CGFloat(entry.reservedRows) * DiffLineHeight.at(pointSize: DiffFileLines.codePointSize)
    }
}
