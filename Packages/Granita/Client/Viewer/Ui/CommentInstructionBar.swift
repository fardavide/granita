import SwiftUI

/// What to do next while a row is held, and the way out of holding one.
///
/// **It exists because the gesture leaves the reader somewhere iOS has no convention for.** One row
/// is marked and the app is waiting for a second tap that may never come. Nothing in the scroll can
/// explain that — every pixel of it is code — so design §7.1 puts the explanation where the thumb
/// already is: a 44pt bar at the bottom safe area, floating over the diff.
///
/// **It costs the diff no height**, which is the rule the whole feature is built around. It is an
/// overlay rather than a `safeAreaInset`: an inset shortens the scroll, and a scroll that changes
/// height is every cached row position invalidated under a reader who did nothing but press.
public struct CommentInstructionBar: View {

    /// Design §4's figure, and this is a control before it is a sentence.
    public static let height: CGFloat = 44

    private let anchorLabel: String
    private let onCancel: () -> Void

    public init(anchorLabel: String, onCancel: @escaping () -> Void) {
        self.anchorLabel = anchorLabel
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Tap another line to extend")
                    .font(.subheadline)
                    .lineLimit(1)
                // Which row is held, because the other end may be a screen away by the time the
                // reader goes looking for it — and scrolling deliberately does not cancel the hold.
                Text(anchorLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 8)
            Button("Cancel", action: onCancel)
                .font(.subheadline)
                .frame(minWidth: 60, minHeight: Self.height)
                .contentShape(.rect)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(minHeight: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The code under it stays visible, which matters here more than anywhere else on the screen:
        // the reader is aiming at a line and this sits over the bottom of the file they are aiming in.
        .background(.thinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
