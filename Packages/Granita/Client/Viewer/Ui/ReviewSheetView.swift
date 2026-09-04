import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// The whole review in one place: the note, the comments, the text, and — only after the copy — the
/// way to throw it away.
///
/// **It is a panel this design drew, not a settings screen.** The first build was a stock
/// `.insetGrouped` `List`, and what that produces is the shape iOS gives a preferences pane: system
/// section headers, a full-width card per control, a plain row per comment, and *Copy review* as one
/// more line of text among them. §7.6 draws something else — a page of small labelled cards, one row
/// per comment carrying **the same 3pt indigo rail the gutter draws**, and the copy as a filled
/// button pinned to the bottom where a thumb is. The rail is the whole reason the list reads as the
/// diff's own: a row here and a mark there are the same object.
///
/// **A `List` underneath, styled, rather than a `ScrollView` that looks like one.** The rows keep
/// their swipe-to-delete, which is one of the two places a single comment can be destroyed and is not
/// something to hand-roll; everything drawn over it is this section's.
///
/// **A list rather than the raw document, which is design §7.6's call 3.** The list is the only place
/// a typo gets fixed before it is sent and the only place a stale comment can be deleted; the
/// document stays one tap behind *Show text*, because what lands on the pasteboard should never be a
/// surprise.
///
/// **There is no path to Clear that does not go through Copy.** A destructive control that exists
/// before the copy is one that can destroy a review before it has been sent anywhere, and this review
/// is the only copy of itself — nothing about it is on the Mac.
public struct ReviewSheetView: View {

    /// Whether this is the phone's sheet or the iPad's column, which is not a styling choice.
    ///
    /// **A sheet brings its own dismissal and a column does not.** Rendered inside the screen's
    /// `HStack`, a navigation stack here drew this view's title and its Close into the *screen's*
    /// navigation bar: opening the review replaced the worktree's name with the word *Review* and put
    /// a Close where the back button goes. The baseline caught it. Neither form has a navigation
    /// stack now — §7.6 draws its own 52pt header — and the column simply has no Close, because the
    /// toolbar toggle that opened it is the way back.
    public enum Presentation: Hashable, Sendable {
        case sheet
        case column
    }

    /// The page's own margin, and the width every card in it is inset by.
    static let margin: CGFloat = 16

    /// A card's corner, which is the same 10 the design draws on all three of them.
    static let cardRadius: CGFloat = 10

    /// The header, and it is a stated height for the reason every other pinned row here is: it holds
    /// three things that must not move when one of them changes length.
    static let headerHeight: CGFloat = 52

    private let presentation: Presentation
    private let comments: [ReviewedComment]
    private let note: Binding<String>
    private let hasSkippedNote: Bool
    private let hasCopied: Bool
    private let document: String
    private let showsDocument: Bool
    private let onShowDocument: (Bool) -> Void
    private let onClose: () -> Void
    private let onSkipNote: () -> Void
    private let onCopy: () -> Void
    private let onClear: () -> Void
    private let onDelete: (CommentAnchor) -> Void

    @State private var isConfirmingClear = false

    /// Transient, and the one piece of state here that is the view's own: *Copied* is a two-second
    /// acknowledgement rather than a fact about the review. What the review remembers is `hasCopied`,
    /// which the model owns because it is what gates Clear.
    @State private var showsCopied = false

    @FocusState private var isWritingNote: Bool

    public init(
        presentation: Presentation,
        comments: [ReviewedComment],
        note: Binding<String>,
        hasSkippedNote: Bool,
        hasCopied: Bool,
        document: String,
        showsDocument: Bool,
        onShowDocument: @escaping (Bool) -> Void,
        onClose: @escaping () -> Void,
        onSkipNote: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onDelete: @escaping (CommentAnchor) -> Void
    ) {
        self.presentation = presentation
        self.comments = comments
        self.note = note
        self.hasSkippedNote = hasSkippedNote
        self.hasCopied = hasCopied
        self.document = document
        self.showsDocument = showsDocument
        self.onShowDocument = onShowDocument
        self.onClose = onClose
        self.onSkipNote = onSkipNote
        self.onCopy = onCopy
        self.onClear = onClear
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            page
            footer
        }
        .background(Color.diffPage)
        .alert("Clear this review?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive, action: onClear)
        } message: {
            // **The second sentence is the whole reason the alert exists.** Everywhere else the app
            // is quiet about where a review lives; this is the one moment where knowing it is not on
            // the Mac changes what the reader does next.
            Text("The note and \(countLabel) will be deleted from this phone. They are not stored on the Mac.")
        }
        // Focused on open, so the reader who has something to say types it immediately.
        .onAppear { isWritingNote = true }
    }

    // MARK: - The header

    /// Three things on one line: the way out, what this is, and how big it is.
    ///
    /// **The count is monospaced and sits at the trailing edge**, which is where §7.6 draws it and
    /// what keeps the title centred while the number grows. The column has no Close — the toolbar
    /// toggle that opened it is the way back — so it stacks the two instead.
    @ViewBuilder private var header: some View {
        switch presentation {
        case .sheet:
            ZStack {
                Text("Review")
                    .font(.headline)
                HStack {
                    Button("Close", action: onClose)
                    Spacer(minLength: 8)
                    Text(countLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Self.margin)
            .frame(height: Self.headerHeight)
        case .column:
            VStack(alignment: .leading, spacing: 1) {
                Text("Review")
                    .font(.headline)
                Text(countLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.margin)
            .frame(height: Self.headerHeight)
        }
    }

    // MARK: - The page

    /// **A plain `List`, because the rows have to keep their swipe.** Everything that makes it look
    /// like a page rather than a settings screen is drawn over it: the rows carry no insets, no
    /// separators and no background of their own, and each block paints its own card.
    private var page: some View {
        List {
            block(label: "A note for the agent · optional") { noteCard }
            commentsLabel
            // **One `List` row per comment, not one card holding all of them.** `swipeActions` is
            // only honoured on a direct child of the list, so a `VStack` of rows inside a single row
            // silently loses the swipe — which is one of the two places a comment can be destroyed.
            // The card is drawn by the rows instead: each paints the card colour and clips only the
            // corners it owns.
            ForEach(Array(comments.enumerated()), id: \.element.id) { position, reviewed in
                commentRow(reviewed, at: position)
            }
            showTextRow
            if showsDocument {
                documentCard
            }
            // The footer is pinned, so the last card needs room to clear it when the list is short.
            Color.clear
                .frame(height: Self.margin)
                .bareListRow()
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .toolbar {
            // **Skip lives on the keyboard bar**, which is design §7.5's whole answer to "one prompt,
            // two answers": the reader who has something to say is already typing, and the reader who
            // does not is one tap away without a modal on top of a modal.
            ToolbarItemGroup(placement: .keyboard) {
                Button("Skip") {
                    onSkipNote()
                    isWritingNote = false
                }
                Spacer()
                Button("Done") { isWritingNote = false }
                    .fontWeight(.semibold)
            }
        }
    }

    /// A small monospaced label over a card, which is the page's one repeating shape.
    private func block(label: String, @ViewBuilder card: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel(label)
            card()
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, Self.margin)
        .bareListRow()
    }

    /// The comments' own label, which cannot ride on a card because its rows are the list's.
    private var commentsLabel: some View {
        sectionLabel("Comments · in document order")
            .padding(.horizontal, Self.margin)
            .padding(.top, 20)
            .padding(.bottom, 7)
            .bareListRow()
    }

    /// Monospaced, uppercase and letter-spaced — the app's own caption idiom rather than the system's
    /// section header, which is what a settings screen uses.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The note

    /// **Skipped replaces the field rather than sitting under it**, which is what §7.6 draws and the
    /// more honest of the two: the field is empty either way, and a caption below an empty box leaves
    /// the reader looking at a box that still invites typing.
    @ViewBuilder private var noteCard: some View {
        if hasSkippedNote {
            Text("Skipped — nothing will be added")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Color.diffCard, in: .rect(cornerRadius: Self.cardRadius))
                // Still a control: tapping it puts the caret back, so *Skip* is not a one-way door.
                .contentShape(.rect)
                .onTapGesture { isWritingNote = true }
        } else {
            TextField("Anything about the change as a whole?", text: note, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...)
                .focused($isWritingNote)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Color.diffCard, in: .rect(cornerRadius: Self.cardRadius))
                // The focus ring §7.5 draws, in the same indigo the rails use — this field and the
                // comments under it are one object.
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cardRadius)
                        .strokeBorder(Color.diffCommentRail.opacity(isWritingNote ? 0.5 : 0), lineWidth: 1)
                }
        }
    }

    // MARK: - The comments

    /// **The rail is the point of this row.** It is the same 3pt indigo bar the gutter draws beside
    /// the code, at the same width and the same corner, so a row in this list and a mark in that
    /// scroll read as one object rather than two reports of it. A stale comment's rail is amber and
    /// its whole row is tinted, which is the one row here that is a warning.
    ///
    /// **The card is drawn by its rows.** Each paints the card colour, clips only the corners it owns
    /// — top on the first, bottom on the last, none in between — and carries the hairline under it
    /// unless it is the last. That is what a single card of rows costs when the rows have to stay the
    /// list's own, and they do: `swipeActions` is honoured on nothing else.
    private func commentRow(_ reviewed: ReviewedComment, at position: Int) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: DiffGutter.railWidth / 2, style: .continuous)
                .fill(reviewed.isStale ? Color.diffCommentStale : Color.diffCommentRail)
                .frame(width: DiffGutter.railWidth)
            VStack(alignment: .leading, spacing: 3) {
                anchorLabel(of: reviewed)
                Text(verbatim: reviewed.comment.text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Color.diffCard
            if reviewed.isStale {
                Color.diffCommentStale.opacity(0.06)
            }
        }
        .overlay(alignment: .bottom) {
            if position < comments.count - 1 {
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1 / 3)
                    // Past the rail and its gap, so the line starts where the words do.
                    .padding(.leading, 26)
            }
        }
        .clipShape(
            .rect(
                topLeadingRadius: position == 0 ? Self.cardRadius : 0,
                bottomLeadingRadius: position == comments.count - 1 ? Self.cardRadius : 0,
                bottomTrailingRadius: position == comments.count - 1 ? Self.cardRadius : 0,
                topTrailingRadius: position == 0 ? Self.cardRadius : 0
            )
        )
        .padding(.horizontal, Self.margin)
        .bareListRow()
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { onDelete(reviewed.id) }
        }
    }

    /// The file's name rather than its path, because the path is in the document and this is a list
    /// the reader is scanning against what they remember writing.
    ///
    /// **In the rail's own colour**, which is what ties the label to the mark; the separator between
    /// the name and the number stays secondary so the two read as two fields.
    private func anchorLabel(of reviewed: ReviewedComment) -> some View {
        HStack(spacing: 5) {
            if reviewed.isStale {
                Image(systemName: "exclamationmark.triangle")
            }
            Text(verbatim: DiffFilePath.name(of: reviewed.comment.path))
                + Text(verbatim: ":").foregroundStyle(.secondary)
                + Text(verbatim: span(of: reviewed.comment.lines))
                + Text(reviewed.isStale ? " · stale" : "")
        }
        .font(.caption2.monospaced())
        .foregroundStyle(reviewed.isStale ? Color.diffCommentStale : Color.diffCommentRail)
        .lineLimit(1)
    }

    // MARK: - The document

    /// A link rather than a disclosure row, which is what §7.6 draws: the document is a thing to
    /// glance at once, not a section of the page.
    private var showTextRow: some View {
        Button {
            onShowDocument(showsDocument == false)
        } label: {
            HStack(spacing: 5) {
                Text(showsDocument ? "Hide text" : "Show text")
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(showsDocument ? 180 : 0))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 4)
        .bareListRow()
    }

    private var documentCard: some View {
        Text(verbatim: document)
            .font(.caption2.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.diffCard, in: .rect(cornerRadius: Self.cardRadius))
            .padding(.horizontal, Self.margin)
            .bareListRow()
    }

    // MARK: - The copy, and only then the clear

    /// **Pinned rather than scrolled to**, which is §7.6 drawn literally: the one thing this screen
    /// exists to do is under the thumb whatever the list is doing.
    private var footer: some View {
        VStack(spacing: 6) {
            copyButton
            if hasCopied {
                Button("Clear review", role: .destructive) { isConfirmingClear = true }
                    .font(.callout)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Text("Paste it to your agent first — clearing deletes it from this phone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, -6)
            }
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 10)
        .padding(.bottom, Self.margin)
        .background(Color.diffPage)
    }

    /// **A filled button, and it turns green when it has done its job.** Two seconds of *Copied* is
    /// the only acknowledgement a pasteboard write can give — nothing else on screen changes — and
    /// the colour is what makes it readable at a glance rather than a word that flickered.
    private var copyButton: some View {
        Button {
            onCopy()
            showsCopied = true
        } label: {
            Label(
                showsCopied ? "Copied" : "Copy review",
                systemImage: showsCopied ? "checkmark" : "doc.on.doc"
            )
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                showsCopied ? Color.reviewCopied : Color.diffCommentRail,
                in: .rect(cornerRadius: 13)
            )
        }
        .buttonStyle(.plain)
        .disabled(showsCopied)
        .animation(.disclosure, value: showsCopied)
        .task(id: showsCopied) {
            guard showsCopied else { return }
            try? await Task.sleep(for: .seconds(2))
            showsCopied = false
        }
    }

    private var countLabel: String {
        comments.count == 1 ? "1 comment" : "\(comments.count) comments"
    }

    private func span(of lines: CommentedLines) -> String {
        lines.first == lines.last ? "\(lines.first)" : "\(lines.first)-\(lines.last)"
    }
}

// MARK: -

private extension View {

    /// A `List` row with nothing of the list's own on it: no insets, no separator, no background.
    ///
    /// Every row on this page draws its own chrome, because the page is a design rather than a
    /// settings screen — and stated once, because five rows repeating three modifiers is five places
    /// for one of them to be forgotten.
    func bareListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private extension Color {

    /// The two seconds after a copy, and the one green on this screen that is not the diff's.
    ///
    /// Darker than `.green`, which in this app means *added* and is a filled 50pt slab away from the
    /// gutter where that meaning lives. §7.6 draws `#1E7A3C`.
    static let reviewCopied = Color(red: 0.118, green: 0.478, blue: 0.235)
}
