import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The two colours the continuous diff draws that are not a status, a tint or a marker.
///
/// They are here rather than at their call sites because each is one half of a pair: a page is only
/// a page if the thing on it is a card, and a band is only chrome if it is lighter than the code
/// around it. Written apart, the two halves drift.
extension Color {

    /// The page the files sit on, which is what makes the 10pt between two of them a gap.
    ///
    /// **Design §4's separation was built and could not be seen**, because the gap was left clear
    /// over a screen whose background is the same white as the cards: 10pt of white between two
    /// white rows is 10pt of white. The review draws the files as cards on a grouped page and the
    /// gap as the page showing through, which is one colour rather than a rule per boundary — and it
    /// is also what keeps the gap correct when a file below is shut, opened, or still arriving.
    static var diffPage: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        // The package builds for the host so `make test` can run without a simulator, and nothing on
        // that platform draws a diff. Near enough for a build that never renders.
        Color.gray.opacity(0.12)
        #endif
    }

    /// One file's card, and it is the **grouped** background's second level rather than the plain
    /// one.
    ///
    /// **Because the plain pair is two blacks.** `systemBackground` over `systemGroupedBackground`
    /// separates in light — white on grey — and in dark they are both `#000000`, so the first
    /// rendering of this fix worked on one appearance and reproduced the original fault on the
    /// other. The grouped pair is the one that holds in both: white on grey in light, `#1C1C1E` on
    /// black in dark. It is also what a reader already reads a grouped list as, which is what §4's
    /// files are.
    static var diffCard: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.gray.opacity(0.02)
        #endif
    }

    /// The hunk band's fill, and the review's fourth fault finished.
    ///
    /// **`quaternarySystemFill`, which is what this band was always documented as and never drawn
    /// in.** `.background(.quaternary)` resolves the *label* hierarchy, not the fill one — about
    /// 20% of the foreground colour rather than 8% — so the band shipped as a mid-grey slab, the
    /// loudest thing on a screen whose job is the code. Rule 3 took its height from 43pt to 26 and
    /// left its weight alone; this is the other half.
    static var diffBand: Color {
        #if canImport(UIKit)
        Color(uiColor: .quaternarySystemFill)
        #else
        Color.gray.opacity(0.08)
        #endif
    }
}
