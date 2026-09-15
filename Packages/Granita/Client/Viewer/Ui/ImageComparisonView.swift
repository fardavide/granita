import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// One picture at the size of the screen, and the other one under a thumb.
///
/// **The hold is the comparison.** Two screenshots of the same screen differ by a few points in one
/// place, and the only way to see that on a phone is to put them in the same pixels and swap between
/// them — laying them side by side at half width is what the card already does, and it is what tells
/// a reader there is something to look at rather than what it is. Davide asked for exactly this:
/// *"keep the finger to see the other variant, so you can easily tap to see the other version."*
///
/// **A file with one side does not offer it**, and the hint is absent rather than greyed. There is
/// nothing to swap to, and a gesture that does nothing is this product's worst defect wearing a
/// gesture's clothes — with nowhere to put the explanation a disabled control would carry.
///
/// It renders what it is handed and reports the press. Which side is on screen is
/// ``DiffImage/shownSide(opened:isComparing:)``, resolved by the model, so the state that makes this
/// screen worth having is one a test can set and a baseline can photograph.
public struct ImageComparisonView: View {

    @Environment(\.displayScale) private var displayScale

    private let name: String
    private let sides: ImageSides
    private let side: DiffSide
    private let bytes: Data
    private let onCompare: (Bool) -> Void
    private let onDone: () -> Void

    public init(
        name: String,
        sides: ImageSides,
        side: DiffSide,
        bytes: Data,
        onCompare: @escaping (Bool) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.name = name
        self.sides = sides
        self.side = side
        self.bytes = bytes
        self.onCompare = onCompare
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            picture
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.diffPage)
                .safeAreaInset(edge: .bottom) { footer }
                .navigationTitle(name)
                #if !os(macOS)
                // Inline for the reason every title in this app is: the subject is a file path's
                // last component, and a large title holds about sixteen characters of one.
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onDone)
                    }
                }
        }
    }

    /// **A container-relative decode rather than a fixed one**, because this is the size the reader
    /// came here for: the card's frame is 220pt and this is the whole screen, so asking for the same
    /// raster twice would make the tap a no-op on anything with detail in it.
    private var picture: some View {
        GeometryReader { geometry in
            let edge = max(geometry.size.width, geometry.size.height)
            if let decoded = DecodedPicture.from(bytes, fittingWithin: edge, scale: displayScale) {
                Image(decorative: decoded, scale: displayScale)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // **Every part of the picture takes the press, including the letterboxing.** A
                    // gesture attached to the drawn image alone would work in the middle of a
                    // portrait screenshot and not at its edges, which is a control that works
                    // sometimes.
                    .contentShape(.rect)
                    .gesture(hold)
            } else {
                // The card says this too, in its own words. Repeated here rather than made
                // unreachable, because a picture can decode at 220pt and fail at 1,200 — a truncated
                // file has enough header to make a thumbnail and not enough to make an image.
                Text("this isn’t a picture this phone can draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    /// **A drag of zero distance rather than a `LongPressGesture`.** A long press fires once, at its
    /// threshold, and has no event for the finger coming up — so the picture would swap and stay
    /// swapped, which is a toggle rather than a comparison. A drag reports both ends, and its minimum
    /// distance of zero is what makes a press with no movement count as one.
    ///
    /// **It reports the press on a one-sided picture too**, and does not check first.
    /// ``DiffImage/shownSide(opened:isComparing:)`` is what decides that a picture with one side has
    /// nothing to swap to, it is asserted there, and a second copy of the rule in here would be two
    /// answers to one question — with the copy in the one place nothing can ask about it.
    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in onCompare(true) }
            .onEnded { _ in onCompare(false) }
    }

    /// What the reader is looking at, and — only when there is another one — how to see it.
    private var footer: some View {
        VStack(spacing: 2) {
            Text(DiffImageBody.captionText(side, sides: sides))
                .font(.headline)
            if sides == .both {
                Text("hold to compare")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
