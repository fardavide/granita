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

    static func at(pointSize: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return UIFont.monospacedSystemFont(ofSize: pointSize, weight: .regular).lineHeight.rounded(.up)
        #else
        // The package builds for the host so `make test` can run without a simulator, and nothing
        // on that platform draws a diff. Six fifths is the ratio the iOS metric comes out at, near
        // enough for a build that never renders.
        return (pointSize * 1.2).rounded(.up)
        #endif
    }
}
