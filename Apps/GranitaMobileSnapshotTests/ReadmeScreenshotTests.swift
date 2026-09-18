import ClientConnectionDomain
import ClientConnectionUi
import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
import ClientWorktreesDomain
import ClientWorktreesPresentation
import SwiftUI
import Testing

/// The screenshots `README.md` publishes, rendered by the suite that renders every other screen.
///
/// **A screenshot kept anywhere else is a screenshot of an older app.** A folder of exported images
/// is correct on the day it is filled and silently wrong from the next screen change onwards, and
/// nothing fails when it rots — a stale picture renders exactly as well as a current one. These are
/// baselines, so a screen that moves turns a documentation image red on the pull request that moved
/// it, in the same run as every other baseline it moved.
///
/// **Every shot here is a file path in `README.md`.** The baseline filename is built from this
/// suite's file name, the test's name and the shot's, which is why the test is called `screenshot`
/// and not a `given … then` sentence: the sentence is the larger half of a path that has to be read
/// and typed by a person editing the document. Rename any of the three and an image on the
/// repository's front page stops resolving — quietly, because Markdown has nothing to say about a
/// link that does not.
///
/// **Why these states.** Each is the ordinary case of a screen rather than an edge one: the states
/// beside them in the other suites exist to hold a refusal, a truncation or an empty list, and a
/// reader arriving at this repository should see what the product does when it is working. The diff
/// carries comments because comments are the half of the product a list of features understates.
///
/// This suite asserts nothing the other suites do not, and that is deliberate — it is not a second
/// opinion about a screen, it is a promise about a document. Curate it; do not grow it.
///
/// Main-actor isolated and serialised for the reasons every suite here is: rendering off the main
/// actor traps in a way that reports "0 tests passed", and the suites share one real window.
@Suite("README screenshots", .serialized)
@MainActor
struct ReadmeScreenshotTests {

    @Test(arguments: Shot.all)
    func screenshot(of shot: Shot) async throws {
        // given
        let screen = try await theScreen(of: shot.screen, in: shot.layout)

        // when - then
        assertScreenSnapshot(screen, layout: shot.layout, named: shot.screen.rawValue)
    }
}

// MARK: -

/// One published image: a screen, and the one layout the document shows it in.
///
/// **The layouts are chosen per screen rather than taken four at a time**, because a document is not
/// a test matrix. The diff is the screen the product is for, so it appears in both appearances and on
/// both devices; the Macs list appears once, because a picture of it in the dark says nothing the
/// light one did not.
struct Shot: Sendable, CustomTestStringConvertible {

    let screen: Screen
    let layout: SnapshotLayout

    var testDescription: String { "\(screen.rawValue)-\(layout.name)" }

    static let all: [Shot] = [
        Shot(screen: .macs, layout: .iPhoneLight),

        Shot(screen: .worktrees, layout: .iPhoneLight),
        Shot(screen: .worktrees, layout: .iPadLight),

        Shot(screen: .diff, layout: .iPhoneLight),
        Shot(screen: .diff, layout: .iPhoneDark),
        Shot(screen: .diff, layout: .iPadLight),

        Shot(screen: .review, layout: .iPhoneLight),
        Shot(screen: .reviewColumn, layout: .iPadLight)
    ]
}

/// Named for what the reader is looking at, because the name is what the document's `<img>` says.
enum Screen: String, Sendable {

    case macs
    case worktrees
    case diff
    case review
    case reviewColumn = "review-column"
}

@MainActor
private func theScreen(of screen: Screen, in layout: SnapshotLayout) async throws -> AnyView {
    switch screen {
    case .macs:
        // Wrapped in a navigation stack because the composition root wraps it, and because
        // `.navigationTitle` renders nothing outside one.
        AnyView(
            NavigationStack {
                ServerDiscoveryView(
                    state: .found(theMacsOnThisNetwork),
                    logCopyState: .ready,
                    onSearchAgain: {},
                    onOpenSettings: {},
                    onCopyLogs: {}
                )
            }
        )

    case .worktrees:
        // The split screen rather than the sidebar alone, because that is what the composition root
        // builds on both devices: the phone's list is this same screen with the split collapsed, and
        // photographing the sidebar on its own would publish a container the app does not have.
        //
        // Loaded before rendering, so the raster is settled rather than a race between the screen's
        // own `.task` and the shutter.
        await AnyView(theWorktreeSplit(in: layout))

    case .diff:
        AnyView(theDiffScreen(of: await aReadableChangeSet(in: layout)))

    case .review:
        // The sheet on its own, which is how it arrives over the diff on a phone.
        try AnyView(theReviewSheet())

    case .reviewColumn:
        AnyView(theDiffScreen(of: await aReviewOpenOnTheDiff(in: layout)))
    }
}

// MARK: - The states behind them

/// Three Macs, one of them named long enough that the row has to shorten it.
private let theMacsOnThisNetwork: [DiscoveredServer] = [
    DiscoveredServer(id: BonjourInstanceName(rawValue: "MacBook Pro"), name: "MacBook Pro"),
    DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac Studio"), name: "Mac Studio"),
    DiscoveredServer(
        id: BonjourInstanceName(rawValue: "Davide's 16-inch MacBook Pro (work)"),
        name: "Davide's 16-inch MacBook Pro (work)"
    )
]

@MainActor
private func theWorktreeSplit(in layout: SnapshotLayout) async -> some View {
    let model = ClientWorktreesModel(
        macName: aMacName,
        repository: FakeGranitaRepository(worktrees: aBusyMac, writeFailure: nil),
        preferences: FakeWorktreeListPreferences(mode: .groupedByProject, showsQuiet: false),
        copyingLogs: FakeDiagnosticLogsCopying(),
        announcing: FakeWorktreeReadAnnouncing(),
        now: { aFixedMoment }
    )
    await model.load()
    let diff = await aLoadedViewerModel(in: layout)

    return NavigationStack {
        WorktreeSplitScreen(model: model, onPairAgain: {}, settings: { EmptyView() }) { _, displayName, _ in
            WorktreeDiffScreen(worktreeName: displayName, model: diff, onPairAgain: {})
        }
    }
}

/// A change set with comments on its first file, which is the state both diff images are taken from.
@MainActor
private func aReadableChangeSet(in layout: SnapshotLayout) async -> ClientViewerModel {
    await aLoadedViewerModel(of: aChangeSetPartlyArrived, holding: aReviewOfTheFirstFile, in: layout)
}

@MainActor
private func aReviewOpenOnTheDiff(in layout: SnapshotLayout) async -> ClientViewerModel {
    let model = await aReadableChangeSet(in: layout)
    model.showReview()
    return model
}

@MainActor
private func theReviewSheet() throws -> some View {
    let subject = try #require(ReviewCase.all.first { $0.name == "before-the-copy" })
    return ReviewSheetView(
        presentation: subject.presentation,
        comments: subject.comments,
        note: .constant(subject.note),
        hasSkippedNote: subject.hasSkippedNote,
        hasCopied: subject.hasCopied,
        caption: subject.caption,
        document: subject.document,
        showsDocument: subject.showsDocument,
        onShowDocument: { _ in },
        onClose: {},
        onSkipNote: {},
        onCopy: {},
        onClear: {},
        onDelete: { _ in }
    )
}

/// Wrapped the way the composition root wraps it, because a baseline of a screen out of its stack
/// publishes a toolbar nobody draws.
@MainActor
private func theDiffScreen(of model: ClientViewerModel) -> some View {
    NavigationStack {
        WorktreeDiffScreen(worktreeName: "TLS pinning", model: model, onPairAgain: {})
    }
        // **Still, because one of these files has not arrived.** Design §9's sweep is an infinite
        // repeat, so a raster of it lands wherever the run loop happened to be — and a documentation
        // image caught mid-sweep is a picture of a gradient rather than of a screen.
        .environment(\._accessibilityReduceMotion, true)
}
