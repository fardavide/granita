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
    /// Public because a baseline has to wrap a view the way the scroll wraps it: a card photographed
    /// on the default background is a picture of a layout that never ships.
    public static var diffPage: Color {
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
    /// Public for the reason ``diffPage`` is.
    public static var diffCard: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.gray.opacity(0.02)
        #endif
    }

    /// The hairline between a block's two cells, and the only thing that says the block continues
    /// past an empty one.
    ///
    /// **The system separator rather than a tint of its own.** Design §4.1's call 2 draws an absent
    /// side as nothing at all, which works because everything around it is a filled rectangle — and
    /// what makes the *row* still read as one row is this rule running down between the cells. It is
    /// chrome standing between two pieces of content, which is the one thing `separator` is for, and
    /// it is the treatment a reader already reads that way everywhere else on the platform.
    ///
    /// Worth its own baseline against the darkest theme's card, where a hairline can disappear.
    static var diffBlockRule: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #else
        // The package builds for the host so `make test` can run without a simulator, and nothing on
        // that platform draws a diff. Near enough for a build that never renders.
        Color.gray.opacity(0.22)
        #endif
    }

    /// The rail a commented run draws in the gutter's leading inset.
    ///
    /// **`.indigo`, and it is the only violet on the screen.** Green, red and orange are spoken for
    /// by the diff's own vocabulary — added, removed, conflicted — and the comment is a fourth thing
    /// that is none of them. It is deliberately *not* load-bearing: design §7.3 makes the rail's
    /// position and its length carry the meaning, so it survives greyscale, a dimmed screenshot and a
    /// reader who cannot tell it from blue.
    ///
    /// **It collides with a renamed file's status bar, which is also indigo**, and that is recorded
    /// rather than resolved: the system palette ran out at four hues, the two are different shapes in
    /// different places — a 3pt vertical rail in the gutter against a 3pt horizontal bar in a header
    /// — and neither carries its meaning by colour alone. See `.ai/docs/decisions.md`.
    static var diffCommentRail: Color { .indigo }

    /// A comment whose lines are gone, which is the one comment state that is a warning.
    ///
    /// Amber rather than red: nothing is broken and nothing was lost — the comment is still in the
    /// review and still goes in the document. What it has lost is somewhere to sit.
    ///
    /// **The status palette's own amber rather than `.orange`, and the design chose it independently
    /// — `#C0821F` in the returned frames is `fileStatusAmber` to the byte.** Orange already means
    /// *conflicted*, which is the one status that means *you must look at this*; a stale comment is
    /// the opposite kind of news, and two things a reader cannot tell apart is worse than one of them
    /// having no colour.
    static var diffCommentStale: Color { .fileStatusAmber }

    /// The light that crosses a card whose file is still on its way.
    ///
    /// **White in both appearances, at two very different alphas, and that is the treatment rather
    /// than an oversight.** In light the card is white and the bars are about 8% black, so the sweep
    /// fades the bars where it passes; in dark the card is `#1C1C1E` and the bars are white, so the
    /// same hue lifts them. Design §9's own numbers, and they are what keeps the sweep from needing
    /// a boundary between two near-blacks to be visible: it reads as light *inside* the card rather
    /// than as a lighter area of it.
    ///
    /// A dynamic `UIColor` rather than two call sites reading the colour scheme, for the reason
    /// every other pair in this file is written here: two halves of one fact, written apart, drift.
    static var diffSweep: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            UIColor.white.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.055 : 0.75)
        })
        #else
        Color.white.opacity(0.5)
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
