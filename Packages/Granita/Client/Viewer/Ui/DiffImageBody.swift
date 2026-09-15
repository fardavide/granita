import SwiftUI

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

/// What a changed picture draws where a changed file draws its hunks.
///
/// **Side by side, and the detail is one tap away.** Davide settled it in one sentence — *"Side by
/// side are fine. If you want to see the detail, you're supposed to tap to see it full screen."* —
/// and that decides the rest: each frame is about 170pt wide on a phone, which is not enough to read
/// a screenshot and is plenty to see *that* something moved. Stacking them full width would read a
/// single screenshot better and would put the two versions a scroll apart, which is the one
/// comparison the card exists to make.
///
/// A one-sided file — arrived, or gone — draws **one** frame at the full width of the card. There is
/// nothing to compare it against, and two frames with one of them empty is a card claiming the
/// picture failed to load.
public struct DiffImageBody: View {

    /// The tallest a frame grows, whatever shape the picture is.
    ///
    /// **A cap rather than an aspect ratio**, because a screenshot is portrait and two portrait
    /// frames at their natural height are most of a screen for one file in a scroll of forty. The
    /// picture is letterboxed inside it rather than cropped: a crop would hide the part of a
    /// screenshot that changed, which on a screenshot test is usually the bottom.
    public static let frameHeight: CGFloat = 220

    /// The gap between the two frames, and the inset around them. Design §4's own 10pt, which is what
    /// the page between two files uses — one number for *these two things are separate*.
    static let gap: CGFloat = 10

    @Environment(\.displayScale) private var displayScale

    private let file: FileChange
    private let image: DiffImage
    private let onOpen: (DiffSide, FileID) -> Void
    private let onRetry: (DiffSide, FileID) -> Void

    /// It reports which file each gesture is in, for the reason every other view in this scroll does:
    /// it holds the file already, and a caller re-attaching the identifier is one wrapper per card
    /// per frame and one more place for the wrong one to be attached.
    public init(
        file: FileChange,
        image: DiffImage,
        onOpen: @escaping (DiffSide, FileID) -> Void,
        onRetry: @escaping (DiffSide, FileID) -> Void
    ) {
        self.file = file
        self.image = image
        self.onOpen = onOpen
        self.onRetry = onRetry
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Self.gap) {
            ForEach(image.frames, id: \.side) { frame in
                // `pictureFrame` rather than `frame`, because `View.frame` is in scope here and wins
                // the overload — the compiler reads a call to a private method of this type as a
                // malformed call to the modifier.
                pictureFrame(frame.side, state: frame.state)
            }
        }
        .padding(Self.gap)
        // **The whole card animates when a side lands**, rather than each frame fading on its own:
        // the two arrive a moment apart and the reader is comparing them, so one of them appearing
        // under a still one reads as the card completing rather than as two separate events.
        .animation(.disclosure, value: image)
    }

    @ViewBuilder private func pictureFrame(_ side: DiffSide, state: DiffImageSide) -> some View {
        VStack(spacing: 4) {
            picture(side, state: state)
                .frame(maxWidth: .infinity)
                .frame(height: Self.frameHeight)
                .background(Color.diffBand)
                .clipShape(.rect(cornerRadius: 8))
            caption(side)
        }
    }

    /// The three states a frame can be in, and every one of them says which it is.
    ///
    /// **A picture that will not decode has its own sentence**, separate from one the Mac refused.
    /// They look identical as an empty frame and they are not the same problem: one is a network
    /// away, the other is a file claiming to be a PNG and holding something else, and a reader who
    /// cannot tell them apart will retry the wrong one forever.
    ///
    /// There is no fourth case for a side this file does not have, because ``DiffImage/frames`` does
    /// not hand one over — a branch drawing an empty rectangle for a pairing the domain never
    /// produces is indistinguishable from a picture that failed to paint.
    @ViewBuilder private func picture(_ side: DiffSide, state: DiffImageSide) -> some View {
        switch state {
        case .awaiting:
            sentence("reading from your Mac")
        case .arrived(let bytes):
            if let decoded = DecodedPicture.from(bytes, fittingWithin: Self.frameHeight, scale: displayScale) {
                Button { onOpen(side, file.id) } label: {
                    Image(decorative: decoded, scale: displayScale)
                        .resizable()
                        .scaledToFit()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.captionText(side, sides: image.sides))
                .accessibilityHint("Opens this picture full screen")
            } else {
                sentence("this isn’t a picture this phone can draw")
            }
        case .refused:
            refused(side)
        }
    }

    /// The one control a frame offers, and it exists because the alternative is a picture that
    /// silently never arrives.
    ///
    /// **Per frame rather than in the bar at the bottom of the screen.** That bar counts cards left
    /// blank by a refused batch of diffs; a refused picture leaves no card blank — the file is there,
    /// its header is there, and one of its two frames is what failed. One request failed carrying one
    /// side, so there is one thing to press and it is on the thing that failed.
    private func refused(_ side: DiffSide) -> some View {
        VStack(spacing: 8) {
            Text("couldn’t read this picture")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try Again") { onRetry(side, file.id) }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .multilineTextAlignment(.center)
        .padding(8)
    }

    private func sentence(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(8)
    }

    private func caption(_ side: DiffSide) -> some View {
        Text(Self.captionText(side, sides: image.sides))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    /// **The collapsed bar's register — lower case, a fact about the file rather than a sentence
    /// addressed to the reader** — and it says what happened rather than which side it is. `before`
    /// and `after` are what a reader is comparing; a lone frame says `added` or `deleted`, because
    /// there is no before for an `after` to be after.
    static func captionText(_ side: DiffSide, sides: ImageSides) -> String {
        switch sides {
        case .onlyNew: "added"
        case .onlyOld: "deleted"
        case .both: side == .old ? "before" : "after"
        }
    }
}
