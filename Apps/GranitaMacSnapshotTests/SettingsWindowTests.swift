import AppKit
import Foundation
import SwiftUI
import Testing

import ServerApiDomain
import ServerMacDomain
import ServerMacPresentation
import ServerMacUi

/// The window's size, asserted from inside the app.
///
/// This is here rather than in the package suite for a reason the design review named: window
/// geometry is not measurable from outside the process while Stage Manager is on, so the only
/// honest place to ask whether a pane fits its window is in a bundle hosted by the app that owns
/// one. A number in a comment beside `frame(width:height:)` is not an assertion.
///
/// **Measuring whether a pane overflows is deliberately not done here, and the first attempt at it
/// was wrong twice.** `NSView.fittingSize` answers unconstrained, so a long footnote reports an
/// ideal width past 620 and an ideal height nowhere near the truth — a pair of numbers describing a
/// window that does not exist. Constraining the width and asking `sizeThatFits` is no better,
/// because a `Form` is a scroll view: it accepts whatever height it is offered, so the answer to
/// "how tall does this want to be" is "as tall as you like". A pane therefore cannot clip — it
/// scrolls — and what is actually worth knowing is whether it *has* to, which the committed
/// baselines show directly and a reviewer reads by eye. That question first bites on Devices, where
/// the design is explicit that nobody should scroll to reach a QR while holding a phone up to it.
@Suite("Settings window")
@MainActor
struct SettingsWindowTests {

    @Test(arguments: MacAppearance.all)
    func `given the window when it is put on screen then it is the size the design fixes`(
        appearance: MacAppearance
    ) {
        // given - when — the frame modifier and the content size a reader actually gets are two
        // different numbers, and only the second one is worth asserting.
        let hosted = hostedInWindow(
            GeneralSettingsView(
                state: .starting,
                servingSince: nil,
                loginItem: .off,
                opensAtLogin: .constant(false),
                onCopyAddress: { _ in },
                onRestart: {},
                onOpenLocalNetworkSettings: {},
                onOpenLoginItems: {},
                onQuit: {}
            ),
            appearance: appearance
        )
        defer { hosted.window?.orderOut(nil) }

        // then
        #expect(hosted.window?.contentLayoutRect.size == GranitaSettingsScreen.windowSize)
    }
}
