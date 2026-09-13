import SwiftUI

import ClientViewerDomain

/// The one thing a reader can press about a batch of diffs the Mac would not send.
///
/// **One control for one request, rather than one per blank card.** Five files go in a batch, so a
/// failure is one event with five symptoms — and design §9's call 6.2 splits the treatment along
/// that line: the cards carry the news, this carries the remedy. A per-file retry would also be a
/// control in a box that can be 18pt tall, which is to say a control that exists on large files and
/// not on small ones.
///
/// **The failure class chooses the control**, which is the whole reason it is in one place. A
/// revoked pairing makes every later request fail too, so *Try Again* there is a control that cannot
/// work — this project's worst defect, and with a per-file retry it would have been drawn once per
/// card.
///
/// **It is chrome over the scroll and never an inset.** A `safeAreaInset` shortens the scroll, and a
/// scroll that changes height is every measured row position invalidated under a reader who pressed
/// nothing. Floating over the bottom costs the layout nothing, and because it is chrome it finds the
/// reader wherever they have scrolled to — including a thousand points below the batch they never saw
/// fail. The count is how they learn there is something behind them.
///
/// **Not dismissible while any file is failed.** A notice you can put away leaves blank cards on
/// screen with nothing to press, which is the defect this whole treatment exists to prevent wearing
/// a tidier face.
public struct DiffFailureBar: View {

    /// Design §9's own figure, and it grows with the words rather than clipping them.
    public static let height: CGFloat = 56

    /// Clear of the home indicator, which design §9 measures at 34pt.
    ///
    /// **It is also what stops the bar being flush with the bottom of the window**, and that turned
    /// out to matter for a reason the design could not have known: a full-width container sitting
    /// hard against the bottom safe area is read by iOS 26 as bottom-bar chrome, and the baselines
    /// came back with this bar's trailing control drawn a second time at the top of the screen — in
    /// the component's own picture as much as the screen's. `CommentInstructionBar` never had the
    /// problem because §7.1 already floats it 38pt clear.
    public static let bottomClearance: CGFloat = 34

    private let failure: DiffBatchFailure
    private let onRemedy: (DiffBatchFailure.Remedy) -> Void

    public init(failure: DiffBatchFailure, onRemedy: @escaping (DiffBatchFailure.Remedy) -> Void) {
        self.failure = failure
        self.onRemedy = onRemedy
    }

    public var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(failure.headline)
                    .font(.footnote.weight(.medium))
                Text(failure.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Wrapping rather than truncating, which is what takes the bar from 56pt to 88 at the
            // largest text sizes — legal because the bar is chrome and its height is nobody's
            // content.
            .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            control
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: Self.height)
        .frame(maxWidth: .infinity)
        // **Its own content's height, never its container's, and the first build left this off.**
        // The bar is placed by an overlay and by a test frame that both propose the full height of
        // the screen, and `minHeight` alone passes an unbounded proposal straight through — which
        // came back as the trailing control drawn a second time at the top of the frame, in the
        // component baseline as well as the screen's. Fixing the vertical size is also what the
        // sentence above needs: the bar grows to fit its words rather than being told how tall it is.
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial)
        // The hairline is what separates it from the page, rather than its fill — which is what lets
        // it work over near-black in dark mode without needing a boundary between two near-blacks.
        .overlay(alignment: .top) { Divider() }
        .padding(.bottom, Self.bottomClearance)
    }

    /// **The stock indicator takes the button's slot while the retry runs**, and it is the one place
    /// on this screen a spinner is honest: the reader asked for exactly this one thing, so there is
    /// one wait and it is theirs.
    @ViewBuilder private var control: some View {
        if failure.isRetrying {
            ProgressView()
                .frame(width: 54, height: 44)
        } else {
            Button(failure.remedy.label) { onRemedy(failure.remedy) }
                .font(.body.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 44)
                .contentShape(.rect)
        }
    }
}
