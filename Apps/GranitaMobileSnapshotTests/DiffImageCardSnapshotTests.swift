import ClientConnectionDomain
import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// What a changed picture draws where a changed file draws its hunks.
///
/// **Every state a frame can be in gets a picture**, because a frame is where this feature either
/// works or silently does nothing: a side still arriving, a side the Mac refused, and a side that
/// came back and will not decode all look like an empty rectangle unless something says otherwise,
/// and only a raster can hold the screen to that.
///
/// Main-actor isolated and serialised for the reasons every suite here is: rendering touches UIKit
/// from a `@Test` that Swift Testing would otherwise run off the main actor, and the suites share one
/// real window.
@Suite("Diff image card", .serialized)
@MainActor
struct DiffImageCardSnapshotTests {

    @Test(arguments: ImageCardCase.all, SnapshotLayout.all)
    func `given a changed picture when its card renders then it matches its baseline`(
        subject: ImageCardCase,
        layout: SnapshotLayout
    ) {
        // given - when - then — on the card colour the scroll gives it, so the frames are
        // photographed against what is actually behind them.
        assertScreenSnapshot(
            DiffImageBody(file: subject.file, image: subject.image, onOpen: { _, _ in }, onRetry: { _, _ in })
                .background(Color.diffCard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.diffPage),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
struct ImageCardCase: Sendable, CustomTestStringConvertible {

    let name: String
    let file: FileChange
    let image: DiffImage

    var testDescription: String { name }

    static let all: [ImageCardCase] = [
        // The state the feature exists for: a re-recorded screenshot baseline, both versions in hand
        // and side by side, with the block that moved visible in both frames.
        ImageCardCase(
            name: "both-sides",
            path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/home-iPhone-light.png",
            status: .modified,
            old: .arrived(SnapshotPicture.bytes(for: .old)),
            new: .arrived(SnapshotPicture.bytes(for: .new))
        ),

        // **Both sides do not land together**, and the frame that has not is the one that has to say
        // it is coming rather than sitting empty beside a picture that arrived.
        ImageCardCase(
            name: "one-side-still-arriving",
            path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/home-iPhone-light.png",
            status: .modified,
            old: .arrived(SnapshotPicture.bytes(for: .old)),
            new: .awaiting
        ),

        // **The one control a frame offers.** A refused picture leaves no card blank, so the bar at
        // the bottom of the screen never appears for it — without this button the reader has nothing
        // to press and no way to learn that anything failed.
        ImageCardCase(
            name: "one-side-refused",
            path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/home-iPhone-light.png",
            status: .modified,
            old: .arrived(SnapshotPicture.bytes(for: .old)),
            new: .refused(.gitFailure(message: "git exited 128"))
        ),

        // **The state 0.14.0 actually shipped into, and the one the first build could not say.** The
        // phone reached a Mac still serving 0.13's API, which has no picture route, so every frame on
        // every card printed *couldn’t read this picture* — a sentence that named neither the cause
        // nor the remedy, and made a working feature read as broken.
        //
        // It is photographed with **no Try Again**, because pressing re-asks a route that does not
        // exist. That absence is the assertion: a control that cannot help is absent rather than
        // disabled, and here it is the difference between a reader updating their Mac and a reader
        // pressing a button all afternoon.
        ImageCardCase(
            name: "the-mac-is-too-old",
            path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/home-iPhone-light.png",
            status: .modified,
            old: .refused(.notUnderstood(diagnostic: "the Mac refused with 404")),
            new: .refused(.notUnderstood(diagnostic: "the Mac refused with 404"))
        ),

        // A file claiming to be a PNG and holding something else, which is a different problem from
        // a refusal and has a different sentence — a reader who cannot tell them apart retries the
        // wrong one forever.
        ImageCardCase(
            name: "undecodable",
            path: "Art/icon/granita.png",
            status: .modified,
            old: .arrived(SnapshotPicture.bytes(for: .old)),
            new: .arrived(SnapshotPicture.undecodable)
        ),

        // **One frame at full width, not two with one empty.** A screenshot an agent has just
        // recorded has nothing to be compared against, and the caption says so rather than saying
        // *after*.
        ImageCardCase(
            name: "added",
            path: "Apps/GranitaMobileSnapshotTests/__Snapshots__/pairing-iPad-dark.png",
            status: .untracked,
            old: nil,
            new: .arrived(SnapshotPicture.bytes(for: .new))
        ),

        // The other one-sided case, and the only one where the picture on screen is the one that is
        // gone.
        ImageCardCase(
            name: "deleted",
            path: "Art/icon/granita-old.png",
            status: .deleted,
            old: .arrived(SnapshotPicture.bytes(for: .old)),
            new: nil
        )
    ]

    /// **Built through `ImageSides` rather than by hand**, so a picture cannot show a pairing the
    /// domain would never produce — two frames on an added file, or a committed side on one that has
    /// only ever existed in the working tree.
    private init(
        name: String,
        path: String,
        status: FileStatus,
        old: DiffImageSide?,
        new: DiffImageSide?
    ) {
        self.name = name
        file = FileChange(
            id: FileID(repositoryRelativePath: path),
            path: path,
            oldPath: nil,
            status: status,
            isBinary: status != .untracked,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 0, deletions: 0),
            contentHash: String(repeating: "f", count: 64),
            estimatedLineCount: 0,
            isViewed: false,
            isTruncated: false,
            language: nil
        )
        let sides = ImageSides.forStatus(status)
        image = DiffImage(
            format: .png,
            sides: sides,
            old: sides.contains(.old) ? old : nil,
            new: sides.contains(.new) ? new : nil
        )
    }
}
