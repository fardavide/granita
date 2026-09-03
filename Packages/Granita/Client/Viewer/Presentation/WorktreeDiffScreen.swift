import SwiftUI

import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain

/// Binds the viewer model to design §4's one continuous scroll and design §3's selector beside it,
/// and is where a chosen worktree lands.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
///
/// **It replaces `WorktreeNotReadyView`**, which said for two releases that this screen was not
/// built. That view was not a stub — it was a real state with real copy, which is what this project
/// requires of a control whose destination does not exist yet. It exists no longer because the
/// destination does.
///
/// **Two presentations of one list, which is design §3's own instruction.** On the phone the selector
/// is a drawer: a sheet at the medium and large detents with background interaction enabled up
/// through medium, so the diff keeps scrolling behind it and tapping a file jumps the scroll *with
/// the list still open* — the reader walks a change set file by file without a dismiss-present cycle
/// between each one. In a regular width it is permanently visible beside the code at 320pt, which is
/// §4's three columns at 320 / 320 / 554. The tree itself is the same view in both.
public struct WorktreeDiffScreen: View {

    @State private var model: ClientViewerModel

    /// **Open by default and shut by the reader**, which is the review's iPad and Davide's amendment
    /// to it on 1 September 2026: the tree is furniture rather than a modal, and a reader who wants
    /// the whole window for code can fold it away and get the phone's *Files* button back in its
    /// place. Nothing is lost by shutting it, which is what makes shutting it safe to offer.
    @State private var isSelectorColumnOpen = true

    private let worktreeName: String

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(worktreeName: String, model: ClientViewerModel) {
        self.worktreeName = worktreeName
        // Pinned in `@State` rather than held as a plain `let`, the same way every other screen in
        // this app does it and for the reason the iPad's split view proved: a destination closure is
        // re-evaluated, and a plain property would swap the displayed model while the running
        // `.task` kept driving the discarded one.
        _model = State(initialValue: model)
    }

    public var body: some View {
        content
            .navigationTitle(worktreeName)
            #if !os(macOS)
            // Inline for the same reason the worktree list's own title is: 34pt bold holds about
            // sixteen characters, and an agent's session summary is a sentence rather than a word.
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { selectorColumnToggle }
            .toolbar { filesButton }
            .toolbar { reviewToggle }
            // **One sheet for all three, because only one of them can ever present.** The setter is
            // written out rather than handed `model.dismissSheet`, which is the repository's IRGen
            // crash arriving from a new direction: a method reference in a `Binding`'s setter makes
            // swiftc emit a reabstraction thunk and abort with `SmallVector unable to grow`. A
            // closure that calls the same method compiles.
            .sheet(item: sheetBinding) { sheet in
                presented(sheet)
            }
            .alert(
                "Your Mac would not make that change",
                isPresented: Binding(
                    get: { model.viewedFailure != nil },
                    set: { if $0 == false { model.dismissViewedFailure() } }
                )
            ) {
                Button("OK") { model.dismissViewedFailure() }
            } message: {
                // The mark went back to what it was, so without this the toggle is a control that
                // appears to have done nothing — twice, since it moved and then moved back.
                Text("The file is still marked as it was. Trying again usually works.")
            }
            // A second refusal with a sentence of its own rather than one alert covering both. They
            // are different promises: a mark that moved and came back needs the reader told it came
            // back, and an expansion that was refused left the hunk exactly as it was.
            .alert(
                "Your Mac would not send those lines",
                isPresented: Binding(
                    get: { model.expansionFailure != nil },
                    set: { if $0 == false { model.dismissExpansionFailure() } }
                )
            ) {
                Button("OK") { model.dismissExpansionFailure() }
            } message: {
                Text("Nothing was added to the diff. Trying again usually works.")
            }
            // **A third one, and it is what stops Save being a control that did nothing.** A comment
            // whose lines moved under an open composer cannot be written against an anchor that no
            // longer resolves — an invented anchor is worse than no comment, because the agent acts
            // on it — so the reader is told rather than watching a paragraph evaporate.
            .alert(
                "Those lines are gone",
                isPresented: Binding(
                    get: { model.commentFailure },
                    set: { if $0 == false { model.dismissCommentFailure() } }
                )
            ) {
                Button("OK") { model.dismissCommentFailure() }
            } message: {
                Text("The file changed while you were writing, so the comment was not saved.")
            }
            .task { await model.load() }
    }

    /// Which sheet is up, with the review taken out of it wherever it is a column instead.
    ///
    /// **One model fact, two presentations.** `model.sheet == .review` is what the capsule, the
    /// toolbar toggle and the column all read; only the phone renders it as a sheet. The setter
    /// ignores the dismissal SwiftUI sends when the column takes over, because that is the layout
    /// changing rather than the reader closing anything — without the guard, rotating an iPad with
    /// the review up would close the review.
    private var sheetBinding: Binding<ViewerSheet?> {
        Binding(
            get: { layout.showsReviewColumn ? nil : model.sheet },
            set: { presented in
                if presented == nil, layout.showsReviewColumn == false {
                    model.dismissSheet()
                }
            }
        )
    }

    /// Which sheet is up, and the presentation each one needs.
    ///
    /// **The composer keeps the diff live behind it and the review does not**, which is design §7.2
    /// and §7.6 disagreeing on purpose: a composer is a drawer over the thing being commented on, and
    /// the review is a destination where the diff has stopped being the subject.
    @ViewBuilder private func presented(_ sheet: ViewerSheet) -> some View {
        switch sheet {
        case .selector:
            // `.presentationBackgroundInteraction` is the one modifier that turns a modal into a
            // drawer: with it the diff keeps scrolling behind the sheet and the dimming goes, which
            // is what makes tapping a file *while the list is open* a different tool from a modal
            // that has to be dismissed between every file.
            selector
                // **The detent is a value the model holds rather than one the sheet keeps to
                // itself**, because choosing a file has to be able to move it: at `.large` the diff
                // behind the sheet is not on screen and background interaction is off, so the jump
                // the tap asked for lands where nobody can see it. `choose` drops this back to
                // `.medium`, and the reader's own drag writes it the other way.
                //
                // **Projected rather than hand-built**, which is the difference between a rule a test
                // can drive and one it cannot: a `Binding(get:set:)` here would put "which height
                // means what" inside two closures that no baseline renders and no host test reaches.
                .presentationDetents([.medium, .large], selection: $model.drawerDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        case .composer:
            composer
                // One height, because the keyboard has already decided it. A reader dragging a
                // composer taller is a reader hiding the code it is about.
                .presentationDetents([.height(CommentComposerView.detentHeight)])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(CommentComposerView.detentHeight)))
        case .review:
            review(.sheet)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder private var content: some View {
        HStack(spacing: 0) {
            if layout.showsSelectorColumn {
                selector
                    .frame(width: FileSelectorView.widthBesideTheDiff)
                    // The column leaving and arriving is a layout change the reader pressed for, so
                    // it moves rather than teleports — the same curve every other disclosure on this
                    // screen uses.
                    .transition(.move(edge: .leading))
                Divider()
                    .transition(.opacity)
            }
            diff
            // **The review takes the tree's place rather than sitting beside it**, which is design
            // §7.7's call 6 and pure arithmetic: three columns at 1194pt leave the code about 60
            // characters, which is not a diff viewer. Folding the tree keeps 108 and needs no new
            // control, because the fold already exists.
            //
            // **320pt rather than the 360 the frame draws.** At 360 the code pane goes from 874pt to
            // 834 when the review opens, and `SPEC.md` §10 caches every measured row height on
            // `availableWidth` — so a 40pt narrowing reflows the whole file the reader is looking at
            // in exchange for 40pt of list. Matching the tree's width moves the code by zero.
            if layout.showsReviewColumn {
                Divider()
                    .transition(.opacity)
                review(.column)
                    .frame(width: FileSelectorView.widthBesideTheDiff)
                    .transition(.move(edge: .trailing))
            }
        }
        // On the container that lays out the movement, which is what 0.5.2 got wrong inside a file
        // and is the same rule here: the thing that travels when a column goes is the diff beside
        // it, and the diff's position belongs to this stack.
        .animation(.disclosure, value: layout.showsSelectorColumn)
        .animation(.disclosure, value: layout.showsReviewColumn)
    }

    private var diff: some View {
        ContinuousDiffView(
            state: model.state,
            pointSize: layout.codePointSize,
            jumpTarget: model.jumpTarget,
            comments: model.reviewed,
            pending: model.draft.pending,
            onReading: { position in Task { await model.reading(position) } },
            onJumped: model.didJump,
            onSetViewed: { isViewed, file in Task { await model.setViewed(isViewed, on: file) } },
            onSetOpen: { isOpen, file in Task { await model.setOpen(isOpen, on: file) } },
            onExpand: { way, hunk, file in Task { await model.expand(way, hunk: hunk, in: file) } },
            onTapGutter: { row, file in model.tappedGutter(row, in: file) },
            onLongPressGutter: { row, file in model.longPressedGutter(row, in: file) },
            onOpenReview: { model.showReview() },
            onRetry: { Task { await model.load() } }
        )
        // **Overlaid, never inset.** A `safeAreaInset` shortens the scroll, and a scroll that changes
        // height is every measured row position invalidated under a reader who pressed nothing —
        // which is the reflow `SPEC.md` §10 exists to forbid. Floating over the bottom of the diff
        // costs the layout nothing at all.
        .overlay(alignment: .bottom) { instructionBar }
        .overlay(alignment: .bottomTrailing) { capsule }
    }

    /// The state a held row leaves the reader in, explained where their thumb already is.
    ///
    /// **It and the capsule share this corner and can never both be true**, which is what lets both
    /// live at the bottom of the screen with nothing arbitrating between them: one is *a run is being
    /// picked out*, the other is *comments exist and none is being picked*.
    @ViewBuilder private var instructionBar: some View {
        if model.draft.heldEnd != nil {
            CommentInstructionBar(anchorLabel: model.heldRowLabel) { model.cancelDraft() }
                .transition(.move(edge: .bottom))
        }
    }

    /// Design §7.4's way in, and only on the phone: a column already on screen needs no button to
    /// announce itself, so at regular width the count lives in the toolbar instead.
    @ViewBuilder private var capsule: some View {
        if layout.showsReviewCapsule, model.comments.isEmpty == false, model.draft.heldEnd == nil {
            ReviewCapsule(count: model.comments.count) { model.showReview() }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var selector: some View {
        FileSelectorView(
            listing: model.selector,
            onChoose: model.choose,
            onToggleDirectory: model.toggle,
            onChooseMode: model.show
        )
    }

    private var composer: some View {
        CommentComposerView(
            anchorLabel: model.composerAnchorLabel,
            excerpt: model.composerExcerpt,
            isEditing: model.editingComment != nil,
            text: $model.composerText,
            onCancel: { model.dismissSheet() },
            onSave: { model.saveComment() },
            onDelete: { model.deleteComposedComment() }
        )
    }

    /// The review, as a sheet on the phone and as a column on the iPad.
    ///
    /// **The presentation is handed in rather than inferred**, because a column that brought its own
    /// navigation stack would draw its title and its Close into the *screen's* navigation bar — which
    /// is what it did, and what the iPad baseline caught.
    private func review(_ presentation: ReviewSheetView.Presentation) -> some View {
        ReviewSheetView(
            presentation: presentation,
            comments: model.reviewed,
            note: $model.noteDraft,
            hasSkippedNote: model.hasSkippedNote,
            hasCopied: model.hasCopied,
            document: model.feedback(note: model.noteDraft),
            onClose: { model.dismissSheet() },
            onSkipNote: { model.skipNote() },
            onCopy: { model.copyReview() },
            onClear: { model.clearComments() },
            onDelete: { anchor in model.removeComment(anchor) }
        )
    }

    /// The way to the drawer, and the count design §3's frame puts on it — *12 files* rather than a
    /// glyph, because it is also the only place the phone says how big the read is before the reader
    /// starts scrolling.
    ///
    /// **Absent while there is nothing to select**, which is every state but one: a button opening a
    /// drawer over a worktree that failed to load, or has nothing changed in it, would open an empty
    /// list and say nothing about why.
    ///
    /// **It comes back when the iPad's column is folded away.** A width that could show the tree but
    /// currently is not is the phone's situation exactly, and leaving the reader with no way to the
    /// list would make the fold control a one-way door.
    @ToolbarContentBuilder private var filesButton: some ToolbarContent {
        if case .reading(let entries) = model.state, layout.showsFilesButton {
            ToolbarItem(placement: .primaryAction) {
                Button { model.showSelector(true) } label: {
                    Text(entries.count == 1 ? "1 file" : "\(entries.count, format: .number) files")
                }
            }
        }
    }

    /// **The fold, and it is a plain icon rather than a labelled control.** The review's own note on
    /// the iPad bar is that mixing an icon and text in one element makes two controls read as one, so
    /// this stands apart from the back button and says nothing.
    ///
    /// Only where a column would fit: on the phone there is no column to fold, and a toggle for a
    /// layout that does not exist is the dead control this project refuses to ship.
    @ToolbarContentBuilder private var selectorColumnToggle: some ToolbarContent {
        if layout.showsSelectorColumnToggle {
            ToolbarItem(placement: .navigation) {
                Button {
                    isSelectorColumnOpen.toggle()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .accessibilityLabel(isSelectorColumnOpen ? "Hide the file list" : "Show the file list")
            }
        }
    }

    /// The review, at the width where it is a column rather than a sheet.
    ///
    /// **The count lives here at regular width and nowhere else**, which is what the capsule buys
    /// back: a toolbar that hides on scroll is the wrong home for a count that changes while you
    /// read, and on the iPad this toolbar does not hide.
    @ToolbarContentBuilder private var reviewToggle: some ToolbarContent {
        if layout.showsReviewToggle {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if model.sheet == .review {
                        model.dismissSheet()
                    } else {
                        model.showReview()
                    }
                } label: {
                    CommentCountChip(count: model.comments.count)
                }
                .accessibilityLabel(model.sheet == .review ? "Hide the review" : "Show the review")
            }
        }
    }

    /// Every layout answer this screen needs, decided in one place a test can reach.
    ///
    /// The horizontal size class rather than the device, because an iPad in a narrow multitasking
    /// width is the phone's layout too — and a 320pt column taken out of 500 is the keyhole design
    /// §4 rejected two number columns for being.
    private var layout: DiffPaneLayout {
        #if os(macOS)
        let fits = true
        #else
        let fits = horizontalSizeClass == .regular
        #endif
        return DiffPaneLayout(
            fitsSelectorColumn: fits,
            isSelectorColumnOpen: isSelectorColumnOpen,
            hasFilesToSelect: hasFilesToSelect,
            isReviewOpen: model.sheet == .review,
            hasComments: model.comments.isEmpty == false
        )
    }

    private var hasFilesToSelect: Bool {
        if case .reading = model.state { true } else { false }
    }
}
