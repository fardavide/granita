import Foundation
import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionUi
import ClientMacDomain
import ClientMacPresentation
import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
import ClientWorktreesPresentation
import CoreDiffDomain
import CoreReviewDomain
import ServerApiDomain
import ServerStoreDomain

@Suite("Mac reader window", .serialized)
@MainActor
struct MacReaderScreenSnapshotTests {

    @Test(arguments: Subject.allCases, MacAppearance.all)
    func reader(subject: Subject, appearance: MacAppearance) async throws {
        let scenario = Scenario(subject: subject)
        var loading: Task<Void, Never>?
        defer {
            loading?.cancel()
            scenario.sidebar.cancelLoading()
        }

        try await assertReaderSnapshot(
            scenario.view,
            appearance: appearance,
            named: subject.rawValue,
            capturesPresentedSheet: subject == .composer || subject == .editingComment,
            capturesWholeWindow: subject == .refreshing
        ) {
            loading = try await scenario.prepare(appearance: appearance)
        }
        if subject == .refreshing {
            loading?.cancel()
            await loading?.value
            #expect(scenario.viewer.isRefreshing == false)
        }
    }

    enum Subject: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case noProjects = "local-no-projects"
        case noWorktreeChosen = "local-listing-with-no-worktree-chosen"
        case gone = "local-saved-worktree-no-longer-listed"
        case hostFailed = "local-host-failed-still-reading"
        case blocked = "local-blocked-by-another-process"
        case blockedMissingHolder = "local-blocked-with-no-process-name"
        case slowRead = "local-reading-for-47-seconds"
        case refreshing = "local-file-list-refreshing-with-the-diff-still-readable"
        case tree = "inspector-tree-with-a-closed-folder"
        case flat = "inspector-flat-three-files"
        case review = "inspector-review-two-comments"
        case emptyReview = "inspector-review-after-deleting-the-last-comment"
        case cleanWorktreeReview = "inspector-review-after-the-worktree-was-committed"
        case diffReadFailed = "local-diff-read-failed"
        case diffGone = "local-worktree-removed-after-the-sidebar-read"
        case batchReadFailed = "local-diff-batch-refused"
        case composer = "comment-composer-for-a-new-comment"
        case editingComment = "comment-composer-for-an-existing-comment"
        case remoteWhileLocalBlocked = "remote-mac-readable-while-this-mac-is-blocked"
        case nothingChanged = "inspector-nothing-changed"

        var testDescription: String { rawValue }
    }

    @MainActor
    struct Scenario {
        let subject: Subject
        let repository: FakeMacReaderRepository
        let reader: ClientMacModel
        let sidebar: ClientWorktreesModel
        let viewer: ClientViewerModel

        init(subject: Subject) {
            self.subject = subject
            let worktrees: [Worktree]
            let selection: ReaderWorktreeSelection
            switch subject {
            case .noProjects, .blocked, .blockedMissingHolder, .slowRead:
                worktrees = []
                selection = .none
            case .noWorktreeChosen:
                worktrees = Array(aBusyMac.prefix(3))
                selection = .none
            case .gone:
                worktrees = Array(aBusyMac.prefix(3))
                selection = .chosen(WorktreeID(rawValue: "w-no-longer-listed"), name: "Remembered source-menu review")
            case .hostFailed, .tree, .flat, .review, .emptyReview, .cleanWorktreeReview,
                 .diffReadFailed, .diffGone, .batchReadFailed, .composer, .editingComment,
                 .remoteWhileLocalBlocked, .refreshing, .nothingChanged:
                worktrees = Array(aBusyMac.prefix(3))
                selection = .chosen(WorktreeID(rawValue: "w-tls"), name: "TLS pinning")
            }
            let fileDiffs: [FileDiff] = switch subject {
                case .nothingChanged, .cleanWorktreeReview: []
                case .flat: Array(Self.diffs.prefix(3))
                case .noProjects, .noWorktreeChosen, .gone, .hostFailed, .blocked, .blockedMissingHolder,
                     .slowRead, .tree, .review, .emptyReview, .diffReadFailed, .diffGone,
                     .batchReadFailed, .composer, .editingComment, .remoteWhileLocalBlocked,
                     .refreshing: Self.diffs
            }
            let repository = FakeMacReaderRepository(
                worktrees: worktrees,
                fileDiffs: fileDiffs,
                holdsWorktreeRead: subject == .slowRead,
                changesFailure: subject == .diffReadFailed
                    ? .gitFailure(message: "fatal: could not read the working tree")
                    : subject == .diffGone ? .worktreeGone : nil,
                diffFailure: subject == .batchReadFailed
                    ? .gitFailure(message: "fatal: could not read a changed file") : nil
            )
            self.repository = repository
            let source: ReaderSource = subject == .remoteWhileLocalBlocked
                ? .remote(DiscoveredServer(id: BonjourInstanceName(rawValue: "granita-mac-studio"), name: "Mac Studio"))
                : .thisMac
            reader = ClientMacModel(memory: FakeMacReaderSelectionMemory(
                selection: ReaderSelection(source: source, worktree: selection)
            ))
            sidebar = ClientWorktreesModel(
                macName: subject == .remoteWhileLocalBlocked ? "Mac Studio" : "This Mac",
                repository: repository,
                preferences: FakeWorktreeListPreferences(mode: .groupedByProject, showsQuiet: true),
                copyingLogs: FakeDiagnosticLogsCopying(),
                announcing: FakeWorktreeReadAnnouncing(),
                now: { repository.now }
            )
            viewer = ClientViewerModel(
                worktree: WorktreeID(rawValue: "w-tls"),
                macName: subject == .remoteWhileLocalBlocked ? "Mac Studio" : "This Mac",
                repository: repository,
                commentStore: FakeReviewCommentStore(holding:
                    [.review, .emptyReview, .cleanWorktreeReview, .editingComment].contains(subject)
                        ? Self.comments : []
                ),
                pasteboard: FakeReviewPasteboard(),
                highlighter: HighlightrSyntaxHighlighter(),
                copyingLogs: FakeDiagnosticLogsCopying(),
                announcing: FakeMacDiffReadAnnouncing(),
                onViewedCountChanged: { _, _ in },
                longWait: DiffFileWait.longWait,
                loadReviewsAtStart: true,
                refreshAnnouncementDelay: subject == .refreshing ? .zero : UnaskedForRefresh.announcementDelay
            )
        }

        func prepare(appearance: MacAppearance) async throws -> Task<Void, Never>? {
            if subject == .slowRead {
                let loading = Task { await sidebar.load() }
                do {
                    for _ in 0..<100 {
                        if sidebar.readStage == .reading(.thisMac) { break }
                        try await Task.sleep(for: .milliseconds(2))
                    }
                } catch {
                    loading.cancel()
                    throw error
                }
                #expect(sidebar.readStage == .reading(.thisMac))
                if case .running(let started) = sidebar.readTiming {
                    #expect(sidebar.currentTime.timeIntervalSince(started) == 47)
                } else {
                    Issue.record("The 47-second subject must still be reading.")
                }
                return loading
            }
            await sidebar.load()
            // Loading the sidebar inserts the chosen detail and starts its own appearance task.
            // Drain that transaction before restoring the fixture's inspector and file state.
            try await Task.sleep(for: .milliseconds(100))
            await viewer.load()
            await viewer.reading(0)
            await viewer.drawing(
                in: appearance.name == "dark" ? .dark : .light,
                themed: .default,
                at: 12
            )
            switch subject {
            case .refreshing:
                let retainedState = viewer.state
                let readableEntries = switch retainedState {
                case .reading(let entries): entries
                case .loading, .nothingChanged, .failed: []
                }
                try #require(readableEntries.count == 5)
                #expect(readableEntries.allSatisfy(\.isReady))
                repository.suspendChangesReads()
                let refresh = Task { await viewer.load() }
                do {
                    for _ in 0..<100 {
                        if viewer.isRefreshing { break }
                        try await Task.sleep(for: .milliseconds(2))
                    }
                    try #require(viewer.isRefreshing)
                    #expect(viewer.state == retainedState)
                    return refresh
                } catch {
                    refresh.cancel()
                    await refresh.value
                    throw error
                }
            case .tree:
                viewer.toggle("Core/Runtime")
                #expect(viewer.selector.mode == .tree)
            case .flat:
                viewer.show(.flat)
                #expect(viewer.selector.fileCount == 3)
            case .review:
                viewer.showReview()
                #expect(viewer.comments.count == 2)
            case .emptyReview:
                viewer.showReview()
                for comment in viewer.comments {
                    viewer.removeComment(comment.anchor)
                }
                #expect(viewer.sheet == .review)
                #expect(viewer.comments.isEmpty)
            case .cleanWorktreeReview:
                viewer.showReview()
                #expect(viewer.state == .nothingChanged)
                #expect(viewer.comments.count == 2)
            case .composer, .editingComment:
                let file = try #require(repository.fileDiffs.first)
                viewer.tappedGutter(DiffLinePosition(oldNumber: 1, newNumber: 1), in: file.file.id)
                if subject == .composer {
                    viewer.composerText = "Keep the source selection in the reader model."
                    #expect(viewer.editingComment == nil)
                } else {
                    #expect(viewer.editingComment?.text == "Keep this view focused on the reader.")
                }
                #expect(viewer.sheet == .composer)
                #expect(viewer.composerExcerpt.isEmpty == false)
            case .diffReadFailed:
                #expect(viewer.state == .failed(.gitFailure(message: "fatal: could not read the working tree")))
            case .diffGone:
                #expect(viewer.state == .failed(.worktreeGone))
            case .batchReadFailed:
                #expect(viewer.batchFailure != nil)
            case .remoteWhileLocalBlocked:
                #expect(reader.selection.source == .remote(DiscoveredServer(
                    id: BonjourInstanceName(rawValue: "granita-mac-studio"), name: "Mac Studio"
                )))
                #expect(sidebar.macName == "Mac Studio")
                #expect(viewer.macName == "Mac Studio")
                #expect(viewer.state.firstFile == FileID(repositoryRelativePath: "Sources/Reader/ReaderWindow.swift"))
            case .noWorktreeChosen:
                #expect(MacReaderDetail(selection: reader.selection.worktree, sidebar: sidebar.state, worktrees: sidebar.worktrees) == .noWorktreeChosen)
            case .gone:
                #expect(MacReaderDetail(selection: reader.selection.worktree, sidebar: sidebar.state, worktrees: sidebar.worktrees) == .gone(name: "Remembered source-menu review"))
            case .noProjects, .hostFailed, .blocked, .blockedMissingHolder, .slowRead, .nothingChanged:
                break
            }
            return nil
        }

        var view: some View {
            MacReaderScreen(
                model: reader,
                serverState: serverState,
                holder: subject == .blocked || subject == .remoteWhileLocalBlocked
                    ? StoreLockHolder(processIdentifier: 4213, processName: "granita-server") : nil,
                source: { sourceMenu },
                local: { worktreesScreen },
                remote: { _ in worktreesScreen }
            )
            .environment(\.codeTheme, .default)
            .environment(\.codeSize, .default)
            .environment(\.readerTextSize, .default)
            .environment(\.sideBySide, SideBySideSetting(isOn: false, choose: { _ in }))
        }

        private var worktreesScreen: some View {
            MacWorktreeScreen(
                model: sidebar,
                selection: Binding(
                    get: { reader.selection.worktree },
                    set: { reader.choose(worktree: $0) }
                ),
                onPairAgain: {},
                onOpenSettings: {},
                onOpenProjects: {},
                source: { sourceMenu },
                settings: { EmptyView() }
            ) { _, name, projectName, _ in
                WorktreeDiffScreen(
                    worktreeName: name,
                    model: viewer,
                    onPairAgain: {},
                    onBackToWorktrees: { reader.choose(worktree: .none) }
                )
                .navigationSubtitle("\(projectName) · \(sidebar.macName)")
            }
        }

        private var sourceMenu: some View {
            MacSourceMenuView(
                source: reader.selection.source,
                menu: MacSourceMenu(
                    discovery: .found([]),
                    remembered: [],
                    excluding: BonjourInstanceName(rawValue: "granita-this-mac")
                ),
                remembered: [],
                logCopyState: .ready,
                onChoose: { reader.choose(source: $0) },
                onSearchAgain: {},
                onOpenSettings: {},
                onCopyLogs: {}
            )
        }

        private var serverState: ServerRunState {
            switch subject {
            case .hostFailed: .failed(reason: "The host could not bind its listening socket.")
            case .blocked, .remoteWhileLocalBlocked:
                .blockedByAnotherProcess(StoreLockHolder(processIdentifier: 4213, processName: "granita-server"))
            case .blockedMissingHolder: .blockedByAnotherProcess(nil)
            case .noProjects, .noWorktreeChosen, .gone, .slowRead, .tree, .flat, .review,
                 .emptyReview, .cleanWorktreeReview, .diffReadFailed, .diffGone, .batchReadFailed,
                 .composer, .editingComment, .refreshing, .nothingChanged:
                .running(ServerEndpoint(host: "this-mac.local", port: 59_144))
            }
        }

        private static let diffs: [FileDiff] = [
            "Sources/Reader/ReaderWindow.swift",
            "Core/Runtime/SelectionMemory.swift",
            "Core/Runtime/WorktreeReading.swift",
            "Sources/Reader/ReaderToolbar.swift",
            "Sources/Reader/WorktreeSelection.swift"
        ].map { path in
            let file = FileChange(
                id: FileID(repositoryRelativePath: path),
                path: path,
                oldPath: nil,
                status: .modified,
                isBinary: false,
                isSubmodule: false,
                stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 1),
                contentHash: String(repeating: "b", count: 64),
                estimatedLineCount: 5,
                isViewed: false,
                isTruncated: false,
                language: "swift"
            )
            let lines = [
                DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "struct ReaderWindow {", displayColumns: 21, segments: nil),
                DiffLine(kind: .deletion, oldNumber: 2, newNumber: nil, text: "    let source = remote", displayColumns: 23, segments: nil),
                DiffLine(kind: .addition, oldNumber: nil, newNumber: 2, text: "    let source = thisMac", displayColumns: 24, segments: nil),
                DiffLine(kind: .addition, oldNumber: nil, newNumber: 3, text: "    let remembersSelection = true", displayColumns: 32, segments: nil),
                DiffLine(kind: .context, oldNumber: 3, newNumber: 4, text: "}", displayColumns: 1, segments: nil)
            ]
            return FileDiff(
                file: file,
                hunks: [Hunk(index: 0, oldStart: 1, oldCount: 3, newStart: 1, newCount: 4, sectionHeading: nil, lines: lines)],
                oldLineCount: 3,
                newLineCount: 4,
                isTruncated: false,
                truncationReason: nil
            )
        }

        private static let comments: [ReviewComment] = [
            (DiffLinePosition(oldNumber: 1, newNumber: 1), CommentedLines(side: .new, first: 1, last: 1), "struct ReaderWindow {", "Keep this view focused on the reader."),
            (DiffLinePosition(oldNumber: nil, newNumber: 2), CommentedLines(side: .new, first: 2, last: 2), "    let source = thisMac", "Restore the source before opening the worktree.")
        ].map { position, lines, quote, text in
            let path = "Sources/Reader/ReaderWindow.swift"
            return ReviewComment(
                anchor: CommentAnchor(file: FileID(repositoryRelativePath: path), first: position, last: position),
                path: path,
                lines: lines,
                language: "swift",
                quotedLines: [quote],
                text: text
            )
        }
    }
}
