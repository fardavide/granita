import Foundation

import ClientConnectionDomain
import CoreDiffDomain

/// How far one side of a picture has got.
///
/// **Three cases rather than an optional `Data`**, for the reason the scroll's own content enum has
/// three: *on its way*, *here* and *refused and not coming* are three different frames, and an
/// absent value can only draw two of them. A picture that failed is the case a card most needs to be
/// able to say out loud, because the alternative is an empty grey rectangle the reader reads as the
/// screenshot having gone blank.
public enum DiffImageSide: Hashable, Sendable {

    /// Asked for, and the Mac has not answered yet.
    case awaiting

    /// The bytes, exactly as the Mac holds them. Decoding is the view's, so a `.png` that is not one
    /// fails where it can be drawn rather than where it was fetched.
    case arrived(Data)

    /// Refused, and not asked again until the reader asks.
    case refused(ApiFailure)
}

/// What the phone has of one changed picture.
///
/// **The sides it *should* have travel with the sides it *does*.** A card drawing only what arrived
/// cannot tell an added file from a replaced one whose committed side is still in flight, and those
/// are two different pictures — one frame or two — so the answer has to be in hand before either is
/// laid out rather than inferred from which requests have landed.
public struct DiffImage: Hashable, Sendable {

    public let format: ImageFormat
    public let sides: ImageSides

    /// Absent when ``sides`` says this file never had a committed one.
    public let old: DiffImageSide?

    /// Absent when ``sides`` says this file no longer has a working copy.
    public let new: DiffImageSide?

    public init(format: ImageFormat, sides: ImageSides, old: DiffImageSide?, new: DiffImageSide?) {
        self.format = format
        self.sides = sides
        self.old = old
        self.new = new
    }

    /// Both sides on their way, which is what a file becomes the moment the change set names it.
    public static func awaiting(_ file: FileChange) -> DiffImage? {
        guard let format = ImageFormat.forPath(file.path) else { return nil }
        let sides = ImageSides.forStatus(file.status)
        return DiffImage(
            format: format,
            sides: sides,
            old: sides.contains(.old) ? .awaiting : nil,
            new: sides.contains(.new) ? .awaiting : nil
        )
    }

    public func side(_ side: DiffSide) -> DiffImageSide? {
        switch side {
        case .old: old
        case .new: new
        }
    }

    /// Each frame the card draws, in the order it draws them: what was there, then what is there now.
    ///
    /// **It is what the card iterates, so the card has no case for a side that does not exist.** A
    /// view walking ``ImageSides`` and reading the optional beside it needs a fourth branch for the
    /// pairing this type can spell and never produces — an unreachable branch drawing an empty
    /// rectangle, which is indistinguishable from a picture that failed to paint.
    public var frames: [(side: DiffSide, state: DiffImageSide)] {
        sides.sides.compactMap { side in self.side(side).map { (side, $0) } }
    }

    /// The same picture with one side answered.
    ///
    /// **A side this file does not have stays absent**, whatever the answer was. The only way to
    /// reach that is a request nobody should have made, and writing it in would grow a second frame
    /// on a card that has one thing to show.
    public func replacing(_ side: DiffSide, with state: DiffImageSide) -> DiffImage {
        guard sides.contains(side) else { return self }
        return DiffImage(
            format: format,
            sides: sides,
            old: side == .old ? state : old,
            new: side == .new ? state : new
        )
    }

    /// Which side the full-screen view draws: the one the reader opened, or its opposite for as long
    /// as they keep a finger down.
    ///
    /// **A one-sided picture never swaps**, which is what makes the hold safe to offer at all: an
    /// added file holding still under a press would be a gesture that does nothing, and a gesture
    /// that does nothing is the same defect as a button that does nothing with nowhere to put the
    /// explanation. The view reads this to decide whether to draw the hint, so the rule and the
    /// affordance cannot disagree.
    public func shownSide(opened: DiffSide, isComparing: Bool) -> DiffSide {
        guard sides == .both, isComparing else { return opened }
        return opened == .old ? .new : .old
    }

    /// The sides that have neither arrived nor been refused.
    ///
    /// A refused side is deliberately not among them: it left the request that failed, and putting it
    /// back would have the scroll re-ask a Mac that is not answering on every frame — the loop the
    /// diff loader's `refused` set exists to prevent, arriving through a second door.
    public var pending: [DiffSide] {
        sides.sides.filter { side($0) == .awaiting }
    }
}

/// The picture the reader has opened full screen.
///
/// **On the model rather than in a view's own state**, which is this screen's standing rule: a
/// presentation nothing outside the view can set is a state no test can ask about and no baseline can
/// photograph — and this one is the whole point of the feature, so it is the last state that should
/// be invisible to both.
public struct OpenedImage: Hashable, Sendable, Identifiable {

    public let file: FileID

    /// Which side the reader tapped, and therefore the one the screen opens on. Holding shows the
    /// other; letting go comes back here.
    public let side: DiffSide

    public init(file: FileID, side: DiffSide) {
        self.file = file
        self.side = side
    }

    public var id: Self { self }
}
