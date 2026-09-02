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
/// **It is attached to the container that lays the movement out, never to the row that changed.**
/// The rows that have to travel when a file shuts are the ones *after* it, and their positions
/// belong to the stack or the list above them — a scope declared inside a section reaches the
/// section's own contents and stops there, so the thing that changed cross-fades while everything
/// else snaps. 0.5.2 made exactly that mistake in the scroll, and it shipped looking like a fix
/// because the other two sites happened to be at the right altitude already.
///
/// Computed rather than stored because this module is main-actor by default, and a curve is a fact
/// about the app rather than about the actor reading it.
/// Public because the iPad's selector column folds on it too, and that fold is laid out a layer up
/// in `Presentation` — a fifth disclosure reusing the curve is the whole point of stating it once.
extension Animation {

    public static var disclosure: Animation { .default }
}
