import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// How tall one row of code is, asked of the font rather than guessed at a ratio.
///
/// **It exists because two stacks have to agree on it.** Design §4's wrap-off scroll draws the line
/// numbers outside the horizontal scroll and the code inside it, so the two are separate view trees
/// laying out separately — and a row that sizes itself is a row whose height depends on what is in
/// it. `142` and `図形` do not measure the same, and one taller row misaligns every row below it in
/// the file. Pinning both columns to one number is what makes the two trees one grid.
///
/// Not scaled by Dynamic Type, deliberately: `SPEC.md` §10 makes the code size its own setting and
/// leaves Dynamic Type governing the chrome around it.
enum DiffLineHeight {

    /// What the review's rule 3 buys, and the only number in this file that is a judgement rather
    /// than a measurement.
    ///
    /// The font's own line height at 11pt is 14, and the screen Davide photographed drew rows at
    /// 13.7 — "the chrome is loose and the content is cramped, which is backwards". Four points of
    /// leading takes a row to 18 and costs about five rows of the viewport, which the same rule wins
    /// back by taking the scope strip from 43pt to 26 and the file header from 50 to 46.
    ///
    /// Added to the font's metric rather than replacing it, so the code size stays a setting: at any
    /// point size a row is still as tall as the glyphs need plus this.
    static let leading: CGFloat = 4

    static func at(pointSize: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return UIFont.monospacedSystemFont(ofSize: pointSize, weight: .regular).lineHeight.rounded(.up) + leading
        #else
        // The package builds for the host so `make test` can run without a simulator, and nothing
        // on that platform draws a diff. Six fifths is the ratio the iOS metric comes out at, near
        // enough for a build that never renders.
        return (pointSize * 1.2).rounded(.up) + leading
        #endif
    }
}
