import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// One picture at the size of the screen, and the state a thumb puts it in.
///
/// **The held state is photographed, and that is the point of it being the model's.** A
/// `@GestureState` inside the cover would have made the swap a thing only a finger could produce —
/// so the one state this whole feature is for would have been the one nothing could hold to its
/// behaviour. Here it is a parameter, and the two frames differ in the raster.
///
/// Main-actor isolated and serialised for the reasons every suite here is.
@Suite("Image comparison", .serialized)
@MainActor
struct ImageComparisonSnapshotTests {

    @Test(arguments: ComparisonCase.all, SnapshotLayout.all)
    func `given an opened picture when it renders full screen then it matches its baseline`(
        subject: ComparisonCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            ImageComparisonView(
                name: subject.fileName,
                sides: subject.sides,
                side: subject.side,
                bytes: subject.bytes,
                onCompare: { _ in },
                onDone: {}
            ),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct ComparisonCase: Sendable, CustomTestStringConvertible {

    let name: String

    /// What the title bar says, which is the file's own name — the one thing on this screen that
    /// tells a reader which of forty pictures they are looking at.
    let fileName: String

    let sides: ImageSides
    let side: DiffSide
    let bytes: Data

    var testDescription: String { name }

    static let all: [ComparisonCase] = [
        // What a tap on the working copy opens: the version the agent produced, with the hint saying
        // there is another one behind it.
        ComparisonCase(
            name: "after",
            fileName: "home-iPhone-light.png",
            sides: .both,
            side: .new,
            bytes: SnapshotPicture.bytes(for: .new)
        ),

        // The same screen with a thumb down. **The whole comparison is that these two rasters differ
        // in one place and nowhere else**, which is exactly what a screenshot test's diff is.
        ComparisonCase(
            name: "before-while-held",
            fileName: "home-iPhone-light.png",
            sides: .both,
            side: .old,
            bytes: SnapshotPicture.bytes(for: .old)
        ),

        // **No hint, because there is nothing to swap to.** A gesture that does nothing is this
        // product's worst defect wearing a gesture's clothes, and the absence of the line is the
        // whole of how a reader is told.
        ComparisonCase(
            name: "added-only",
            fileName: "pairing-iPad-dark.png",
            sides: .onlyNew,
            side: .new,
            bytes: SnapshotPicture.bytes(for: .new)
        ),

        // A picture that made a thumbnail for the card and will not make a full-size image — a
        // truncated file has enough header for one and not the other — so the sentence is here as
        // well as on the card.
        ComparisonCase(
            name: "undecodable",
            fileName: "granita.png",
            sides: .both,
            side: .new,
            bytes: SnapshotPicture.undecodable
        )
    ]

    private init(name: String, fileName: String, sides: ImageSides, side: DiffSide, bytes: Data) {
        self.name = name
        self.fileName = fileName
        self.sides = sides
        self.side = side
        self.bytes = bytes
    }
}
