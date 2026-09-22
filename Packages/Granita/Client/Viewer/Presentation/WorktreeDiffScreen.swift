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

    /// What *Pair Again* does, which is the composition root's to answer: pairing lives in another
    /// feature's `Presentation` and this target may not see one. Required rather than optional, so
    /// the one failure whose remedy is not a retry cannot ship as a control that does nothing.
    private let onPairAgain: () -> Void

    /// What *Back to Worktrees* does. The system's own pop rather than a closure, because this
    /// screen is pushed on a stack in both layouts — the phone's spine and, on the iPad, the detail
    /// column's own stack.
    @Environment(\.dismiss) private var dismiss

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Which appearance the code is being lexed for.
    ///
    /// **The colours are baked into what the highlighter answers rather than applied over it**, so
    /// this is part of the question the model asks and not a restyling of one answer. It is an
    /// environment value, which is why the model is told rather than left to guess.
    @Environment(\.colorScheme) private var colorScheme

    /// Which pair of stylesheets that lexing uses, which the reader sets on the Settings sheet and the
    /// scene root puts here. The other half of the same question `colorScheme` asks.
    @Environment(\.codeTheme) private var codeTheme

    /// Whether a paired run opens into two columns, and how to change it. Design §4.5's call 5 puts
    /// the control on this screen rather than in Settings, so the value and its setter arrive
    /// together.
    @Environment(\.sideBySide) private var sideBySide

    public init(worktreeName: String, model: ClientViewerModel, onPairAgain: @escaping () -> Void) {
        self.worktreeName = worktreeName
        self.onPairAgain = onPairAgain
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
            // **In with the toggle rather than in a modifier of its own.** A `.toolbar` whose
            // content builder resolves to nothing replaces the bar instead of adding nothing to it,
            // and this screen's own baselines came back with no navigation bar at all when the
            // spinner had one to itself. The three below each always produce an item.
            .toolbar {
                selectorColumnToggle
                titleWithActivity
            }
            .toolbar { filesButton }
            .toolbar { reviewToggle }
            .toolbar { sideBySideToggle }
            // **One sheet for all three, because only one of them can ever present.** The setter is
            // written out rather than handed `model.dismissSheet`, which is the repository's IRGen
            // crash arriving from a new direction: a method reference in a `Binding`'s setter makes
            // swiftc emit a reabstraction thunk and abort with `SmallVector unable to grow`. A
            // closure that calls the same method compiles.
            .sheet(item: sheetBinding) { sheet in
                presented(sheet)
            }
            .alert(
                "Your Mac cannot make that change",
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
                "Your Mac cannot send those lines",
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
            // **Keyed on both, and `initial: true` so the first render reports rather than assumes.**
            // The model starts on light at the phone's 11pt because nothing else is knowable before a
            // view exists; this is where an iPad at 12pt and a screen already in dark mode say so.
            // A repeat with the same pair is not wasted — it colours anything opened since.
            .task(id: drawing) {
                await model.drawing(in: drawing.appearance, themed: drawing.theme, at: drawing.pointSize)
            }
    }

    /// The trio the highlighter's answers are keyed on, as one value so one `.task` watches all of
    /// them.
    private var drawing: DiffDrawing {
        DiffDrawing(
            appearance: colorScheme == .dark ? .dark : .light,
            theme: codeTheme,
            pointSize: Double(layout.codePointSize)
        )
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

    /// The opened picture, as a binding the cover can put away.
    ///
    /// The setter is written out rather than handed `model.closeImage` for the reason `sheetBinding`
    /// names: a method reference in a `Binding`'s setter makes swiftc emit a reabstraction thunk and
    /// abort. A closure that calls the same method compiles.
    private var openedImageBinding: Binding<OpenedImage?> {
        Binding(
            get: { model.openedImage },
            set: { opened in
                if opened == nil {
                    model.closeImage()
                }
            }
        )
    }

    /// One picture at the size of the screen, and its other side under a thumb.
    ///
    /// **Nothing at all when the side is no longer in hand**, which is a change set landing under an
    /// open cover: the bytes went with the old one, and a cover left up over nothing would be a
    /// screen the reader has to guess their way out of. The model answering nil closes it.
    @ViewBuilder private func openedPicture(_ opened: OpenedImage) -> some View {
        if let shown = model.openedImageSide {
            ImageComparisonView(
                name: DiffFilePath.name(of: name(of: opened.file)),
                sides: shown.image.sides,
                side: shown.side,
                bytes: shown.bytes,
                onCompare: { model.compareImage($0) },
                onDone: { model.closeImage() }
            )
        } else {
            Color.clear.onAppear { model.closeImage() }
        }
    }

    /// The path of one file in the change set, or nothing readable when it has gone.
    private func name(of file: FileID) -> String {
        guard case .reading(let entries) = model.state else { return "" }
        return entries.first { $0.id == file }?.file.path ?? ""
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
            logCopyState: model.logCopyState,
            pointSize: layout.codePointSize,
            isSplit: sideBySide.isOn,
            jumpTarget: model.jumpTarget,
            comments: model.reviewed,
            // **The held row draws a rail too, which is the state that most needs one.** Design
            // §7.1 makes the mark part of holding — square caps, outside the horizontal scroll, and
            // deliberately surviving a scroll that goes looking for the other end. Passing only the
            // composing run left a reader holding a row with nothing in the gutter to say which.
            pending: model.draft.pending ?? model.draft.held,
            highlighted: model.highlighted,
            images: model.images,
            // The strip stops being a target while a sheet is up, because the composer's own detent
            // keeps the diff behind it live — and a gesture that lands there is one the draft has
            // nothing to do with. The scroll still moves; only the aim goes.
            acceptsTargeting: model.sheet == nil,
            isWaitingLong: model.isWaitingLong,
            onReading: { position in Task { await model.reading(position) } },
            onJumped: model.didJump,
            onSetViewed: { isViewed, file in Task { await model.setViewed(isViewed, on: file) } },
            onSetOpen: { isOpen, file in Task { await model.setOpen(isOpen, on: file) } },
            onExpand: { way, hunk, file in Task { await model.expand(way, hunk: hunk, in: file) } },
            onTapGutter: { row, file in model.tappedGutter(row, in: file) },
            onLongPressGutter: { row, file in model.longPressedGutter(row, in: file) },
            onOpenImage: { side, file in model.openImage(side, of: file) },
            onRetryImage: { side, file in Task { await model.retryImage(side, of: file) } },
            onOpenReview: { model.showReview() },
            onRetry: { Task { await model.load() } },
            // **Not the same question as the failure bar's *Try Again*, which is why both survive.**
            // That control re-asks for the files the Mac refused and leaves the rest of the change
            // set alone; this asks whether the change set is still the change set. A batch that
            // failed is a gap in what is drawn, and an agent that committed since is a different
            // drawing entirely.
            onRefresh: { await model.load(trigger: .pullToRefresh) },
            onCopyLogs: { Task { await model.copyLogs() } }
        )
        // **Overlaid, never inset.** A `safeAreaInset` shortens the scroll, and a scroll that changes
        // height is every measured row position invalidated under a reader who pressed nothing —
        // which is the reflow `SPEC.md` §10 exists to forbid. Floating over the bottom of the diff
        // costs the layout nothing at all.
        //
        // **The failure bar sits under the instruction bar rather than beside it**, which is a call
        // the frames do not make: §7.1's bar and §9's are both bottom chrome and, unlike the bar and
        // the capsule, they *can* both be true — a reader can hold a row in one file while another
        // file's batch is failing. Stacked, neither covers the other and the one that is permanent is
        // the one at the edge.
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                instructionBar
                failureBar
            }
        }
        .overlay(alignment: .bottomTrailing) { capsule }
        // **On the container, which is the rule the whole screen follows and the reason the two
        // `.transition`s above were inert.** A transition needs an animated state change to run
        // against, and nothing was animating these: the bar snapped in on a long press and the
        // capsule popped the instant a save landed. Keyed on the two facts that make each appear
        // rather than on the model, so an arriving diff does not restart them.
        .animation(.disclosure, value: model.draft.heldEnd)
        .animation(.disclosure, value: model.comments.isEmpty)
        // **On the diff pane rather than on the screen, and that is load-bearing on one platform.**
        // A picture is presented over the pane it belongs to, which is true either way; on macOS it
        // is also the only way it can be presented at all. There is no full-screen cover there, so it
        // falls back to a sheet — and two `.sheet` modifiers on **one** view is the shape where only
        // the first ever fires, which is this project's own note about several modifiers of a kind.
        // A different view in the hierarchy is a different presentation slot.
        #if os(macOS)
        .sheet(item: openedImageBinding) { opened in
            openedPicture(opened)
                // A cover has the screen; a sheet has to be told, or the Mac opens a panel sized to
                // its content and a screenshot is its content.
                .frame(minWidth: 560, minHeight: 480)
        }
        #else
        // **A cover rather than a fourth sheet.** A picture is what the reader came to look at, so it
        // takes the screen whole — a sheet would give back a corner of the diff and 30pt of inset at
        // exactly the moment the diff has stopped being the subject. It is also what lets the drawer
        // stay up behind it: a reader who reached this file from the selector taps a picture with the
        // list still at half height, and neither presentation has to take the other down.
        .fullScreenCover(item: openedImageBinding) { opened in
            openedPicture(opened)
        }
        #endif
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

    /// The one control a refused batch offers, and the failure picks which one it is.
    ///
    /// **Spanning the diff pane rather than the window**, which on the iPad matters: the failure is
    /// about the content of one pane, the selector beside it is still perfectly good, and a bar
    /// across a 1,194pt window would be the app saying the thing they can still use has stopped too.
    /// It gets that for free by being an overlay on the diff rather than on the screen.
    ///
    /// **No `.transition`, and the first build had one.** The two above it are keyed to facts that
    /// change under the reader's own hand; nothing keys one to a batch failing, so a `.move(edge:)`
    /// here is the inert transition this screen already carries a paragraph about — except that it
    /// was worse than inert. The phone baseline came back with the control drawn a second time at the
    /// top of the window, which is a transition resolved against no animation and photographed
    /// mid-flight. A bar that arrives because the Mac refused something is news rather than a layout
    /// the reader asked for, so it appears.
    @ViewBuilder private var failureBar: some View {
        if let failure = model.batchFailure {
            DiffFailureBar(failure: failure) { remedy in
                switch remedy {
                case .tryAgain: Task { await model.retryDiffs() }
                case .backToWorktrees: dismiss()
                case .pairAgain: onPairAgain()
                }
            }
        }
    }

    /// Design §7.4's way in, and only on the phone: a column already on screen needs no button to
    /// announce itself, so at regular width the count lives in the toolbar instead.
    @ViewBuilder private var capsule: some View {
        if layout.showsReviewCapsule, model.draft.heldEnd == nil {
            ReviewCapsule(count: model.comments.count) { model.showReview() }
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
            caption: ReviewSyncCopy.caption(for: model.reviewSync, macName: model.macName),
            document: model.feedback(note: model.noteDraft),
            showsDocument: model.isShowingDocument,
            onShowDocument: { model.showDocument($0) },
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

    /// **A toggle rather than a menu, because it has two states and the reader flips between them
    /// while reading a block.** Design §4.5's call 5: `rectangle.split.2x1`, one tap from the code on
    /// all three presentations.
    ///
    /// **The glyph does not change, and that is a departure from the return.** §4.5 asks for it
    /// filled when on; built that way it was the heaviest thing in a toolbar whose screen is the
    /// code — two solid slabs sharing a capsule with *7 files*, so the two read as one control.
    /// Davide's call on 22 September 2026: *"the fill state is too heavy."* What says the mode is on
    /// instead is the platform's own selected background, which is what `.toggleStyle(.button)`
    /// draws — one vocabulary the reader already knows from every other toolbar, rather than a glyph
    /// swap they have to learn. A `Toggle` also announces its own on-and-off state, which is a better
    /// accessibility answer than two hand-written labels.
    ///
    /// Rejected with it: the file header's unbuilt menu, which would make this feature also decide
    /// when that menu ships; a Settings row, which is two navigations from the code and would read as
    /// a preference rather than a posture; and a segmented bar under the navigation bar, which is
    /// permanent chrome on a screen that just bought 17pt back.
    ///
    /// **Present whenever there is a diff to look at, and live even when nothing on screen changes.**
    /// A change set of nothing but new files has no paired run, so pressing it draws the same rows —
    /// and still records how the next change set opens. Davide settled that on 22 September 2026: it
    /// is a setting, and a setting's effect is that it is remembered.
    @ToolbarContentBuilder private var sideBySideToggle: some ToolbarContent {
        // Absent rather than dead where no composition root wired a setter, and absent on a screen
        // with no code on it — a toggle over a spinner or a failure has nothing to turn over.
        if let choose = sideBySide.choose, case .reading = model.state {
            ToolbarItem(placement: .primaryAction) {
                // The setter is written out rather than handed `choose` directly, which is the same
                // IRGen crash the sheet binding above works around: a bare function reference in a
                // `Binding`'s setter makes swiftc emit a reabstraction thunk and abort.
                Toggle(isOn: Binding(get: { sideBySide.isOn }, set: { isOn in choose(isOn) })) {
                    Label("Side by Side", systemImage: "rectangle.split.2x1")
                }
                .toggleStyle(.button)
            }
        }
    }

    /// The file list being read again, said in the one place on this screen that costs the diff
    /// nothing.
    ///
    /// **The same control the worktree list gets, for the same reason.** This screen loads from its
    /// own `.task`, so returning to a worktree fetches the whole change set again while the files
    /// already drawn deliberately stay drawn — and until now that read was invisible.
    ///
    /// **Leading, beside the worktree's name rather than beside *12 files*.** The trailing slot
    /// carries the count and the review's chip, which are two things the reader aims a thumb at; a
    /// spinner arriving and leaving there would shift both of them sideways every time this screen
    /// came back. Anything inserted into the scroll instead is `SPEC.md` §10's reflow.
    /// The worktree's name, with the file list being read again turning just after it.
    ///
    /// **`.principal`, for the reason `WorktreeSidebarView` carries in full**: the leading slot is
    /// the back button's and the trailing slot holds *12 files* and the review's chip, so the title
    /// slot is the only place *beside the name* actually is. The item is always present and only the
    /// spinner inside it comes and goes, which is what keeps the bar from being rebuilt.
    ///
    /// Tail truncation rather than the sidebar's middle, which is design §2's split and not an
    /// inconsistency: a Mac is named at its end and a generated worktree directory is a mnemonic
    /// prefix in front of a ULID, so here the front is the half worth keeping.
    private var titleWithActivity: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Text(worktreeName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Reading the file list again")
                }
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

// MARK: -

/// The three facts a lexed side is keyed on that only a rendered view knows.
///
/// One value rather than three watched separately, because `.task(id:)` takes one identity and three
/// tasks would race to reset the same cache.
private struct DiffDrawing: Hashable {

    let appearance: HighlightAppearance

    /// **Here so that changing the theme re-lexes what is already on screen.** Without it the task
    /// would not re-fire, and the reader would get their new colours on files they scrolled to next
    /// and the old ones on everything already lexed — for as long as the worktree's content hash sat
    /// still, which on a checkout nobody is writing to is indefinitely.
    let theme: CodeTheme

    let pointSize: Double
}
