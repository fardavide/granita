import SwiftUI

/// The curve every expand and collapse in the review moves on.
///
/// **A layout change the reader asked for is animated, and a jump is what it looks like when it is
/// not.** Shutting a file, opening one, expanding a hunk's context and opening a directory in §3's
/// selector all replace a run of rows with a different run — done without motion, the whole screen
/// below the press relocates between one frame and the next, and the reader has to re-find where
/// they were. Motion is what carries them from the old layout to the new one.
///
/// **`.default`, deliberately, and stated once so it can be refined in one edit.** The four
/// disclosures are one gesture wearing four hats, so a curve chosen per call site is four answers to
/// one question — and the first honest answer is the platform's own, which already respects Reduce
/// Motion without any of these views asking.
///
/// Not the 0.2s ease the scroll's jump uses: that one is a *scroll* landing on a file and is timed
/// against the baseline that photographs it mid-flight. This is a layout opening and closing.
///
/// Computed rather than stored because this module is main-actor by default, and a curve is a fact
/// about the app rather than about the actor reading it.
extension Animation {

    static var disclosure: Animation { .default }
}
