import SwiftUI

import ClientViewerDomain

/// What to do next while a row is held, and the way out of holding one.
///
/// **It exists because the gesture leaves the reader somewhere iOS has no convention for.** One row
/// is marked and the app is waiting for a second tap that may never come. Nothing in the scroll can
/// explain that — every pixel of it is code — so design §7.1 puts the explanation where the thumb
/// already is.
///
/// **A floating pill, inset from both edges and clear of the home indicator**, which is what §7.1
/// draws and not the full-width bar this was built as first. The difference is not decoration: a bar
/// flush to the bottom of the screen reads as chrome the screen has grown, and this is a state that
/// lasts a few seconds. A pill reads as something that arrived and will leave.
///
/// **It costs the diff no height**, which is the rule the whole feature is built around. It is an
/// overlay rather than a `safeAreaInset`: an inset shortens the scroll, and a scroll that changes
/// height is every cached row position invalidated under a reader who did nothing but press.
public struct CommentInstructionBar: View {

    /// Design §4's figure, and this is a control before it is a sentence.
    public static let height: CGFloat = 44

    /// How far the two floating controls sit from the edges of the screen. §7's frames put both the
    /// bar and the capsule at the same inset, so they occupy one position rather than two.
    public static let inset: CGFloat = 12

    /// Clear of the home indicator, which the frames measure at 38 from the bottom of the glass.
    public static let bottomInset: CGFloat = 38

    private let anchorLabel: String
    private let onCancel: () -> Void

    public init(anchorLabel: String, onCancel: @escaping () -> Void) {
        self.anchorLabel = anchorLabel
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 0) {
            // **The same rail the gutter draws**, so the bar and the mark it is about are one object
            // — the reader's eye has something to carry from the bottom of the screen back up to the
            // row that is held.
            RoundedRectangle(cornerRadius: DiffGutter.railWidth / 2, style: .continuous)
                .fill(Color.diffCommentRail)
                .frame(width: DiffGutter.railWidth, height: 18)
                .padding(.trailing, 10)
            VStack(alignment: .leading, spacing: 0) {
                Text("Tap another line to extend")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                // Which row is held, because the other end may be a screen away by the time the
                // reader goes looking for it — and scrolling deliberately does not cancel the hold.
                Text(verbatim: anchorLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 8)
            Button("Cancel", action: onCancel)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .frame(height: Self.height)
                .contentShape(.rect)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: Self.height)
        // The code under it stays visible, which matters here more than anywhere else on the screen:
        // the reader is aiming at a line and this sits over the bottom of the file they are aiming in.
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 1 / 3))
        .shadow(color: .black.opacity(0.14), radius: 6, y: 1)
        .padding(.horizontal, Self.inset)
        .padding(.bottom, Self.bottomInset)
    }
}
