import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// The whole review in one place: the note, the comments, the text, and — only after the copy — the
/// way to throw it away.
///
/// **A list rather than the raw document, which is design §7.6's call 3.** The list is the only place
/// a typo gets fixed before it is sent and the only place a stale comment can be deleted, and it is
/// what makes the note and the comments one object instead of two screens. The document stays one tap
/// behind *Show text*, because what lands on the pasteboard should never be a surprise.
///
/// **`.large` with nothing live behind it**, unlike the composer. This one is a destination rather
/// than a drawer: the diff is no longer the subject, the review is.
///
/// **There is no path to Clear that does not go through Copy.** A destructive control that exists
/// before the copy is one that can destroy a review before it has been sent anywhere, and this review
/// is the only copy of itself — nothing about it is on the Mac. That is design §7.6's sequencing and
/// it is a safety property rather than a nicety.
public struct ReviewSheetView: View {

    /// Whether this is the phone's sheet or the iPad's column, which is not a styling choice.
    ///
    /// **A sheet brings its own navigation stack and a column must not.** Rendered inside the
    /// screen's `HStack` with a stack of its own, this view's title and its Close button are drawn by
    /// the *screen's* navigation bar — so opening the review on iPad replaced the worktree's name
    /// with the word *Review* and put a Close where the back button goes. The baseline caught it; a
    /// column carries its own heading and is closed by the toolbar toggle that opened it.
    public enum Presentation: Hashable, Sendable {
        case sheet
        case column
    }

    private let presentation: Presentation
    private let comments: [ReviewedComment]
    private let note: Binding<String>
    private let hasSkippedNote: Bool
    private let hasCopied: Bool
    private let document: String
    private let onClose: () -> Void
    private let onSkipNote: () -> Void
    private let onCopy: () -> Void
    private let onClear: () -> Void
    private let onDelete: (CommentAnchor) -> Void

    @State private var showsDocument = false
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
        self.onClose = onClose
        self.onSkipNote = onSkipNote
        self.onCopy = onCopy
        self.onClear = onClear
        self.onDelete = onDelete
    }

    public var body: some View {
        presented
            .alert("Clear this review?", isPresented: $isConfirmingClear) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive, action: onClear)
            } message: {
                // **The second sentence is the whole reason the alert exists.** Everywhere else the
                // app is quiet about where a review lives; this is the one moment where knowing it is
                // not on the Mac changes what the reader does next.
                Text("The note and \(countLabel) will be deleted from this phone. They are not stored on the Mac.")
            }
            // Focused on open, so the reader who has something to say types it immediately.
            .onAppear { isWritingNote = true }
    }

    @ViewBuilder private var presented: some View {
        switch presentation {
        case .sheet:
            NavigationStack {
                list
                    .navigationTitle("Review")
                    // The count beside the title, which is where §7.6 draws it — and the only place
                    // the review says how big it is, since the list itself scrolls.
                    .navigationSubtitle(countLabel)
                    #if !os(macOS)
                    // The package builds for the host so `make test` needs no simulator, and nothing
                    // on that platform presents a review — the guard every screen here carries.
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", action: onClose)
                        }
                    }
            }
        case .column:
            VStack(spacing: 0) {
                heading
                list
            }
        }
    }

    /// What the column says instead of a navigation bar it must not have.
    private var heading: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Review")
                .font(.headline)
            Text(countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var list: some View {
        List {
            noteSection
            commentsSection
            documentSection
            copySection
            if hasCopied {
                clearSection
            }
        }
        // **Skip lives on the keyboard bar**, which is design §7.5's whole answer to "one prompt, two
        // answers": the reader who has something to say is already typing, and the reader who does
        // not is one tap away without a modal on top of a modal. It is on the list rather than in the
        // navigation stack, because the column has no stack and still has a keyboard.
        .toolbar {
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

    private var countLabel: String {
        comments.count == 1 ? "1 comment" : "\(comments.count) comments"
    }

    private var noteSection: some View {
        Section {
            TextField("Anything about the change as a whole?", text: note, axis: .vertical)
                .lineLimit(2...)
                .focused($isWritingNote)
            if hasSkippedNote {
                // **Said out loud, because *Skip* has no other evidence.** The field is empty either
                // way, and a reader who skipped and then wondered whether it took has nothing else to
                // read. What it must not do is put a placeholder in the document — an agent reading
                // one treats it as an instruction to go and find the note.
                Text("Skipped — nothing will be added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("A note for the agent · optional")
        }
    }

    private var commentsSection: some View {
        Section {
            ForEach(comments) { reviewed in
                row(of: reviewed)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { onDelete(reviewed.id) }
                    }
            }
        } header: {
            Text("Comments · in document order")
        }
    }

    /// The file's name rather than its path, because the path is in the document and this is a list
    /// the reader is scanning against what they remember writing.
    private func row(of reviewed: ReviewedComment) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(verbatim: "\(DiffFilePath.name(of: reviewed.comment.path)):\(span(of: reviewed.comment.lines))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if reviewed.isStale {
                    Text("· stale")
                        .font(.caption)
                        .foregroundStyle(Color.diffCommentStale)
                }
            }
            Text(verbatim: reviewed.comment.text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private var documentSection: some View {
        Section {
            DisclosureGroup("Show text", isExpanded: $showsDocument) {
                Text(verbatim: document)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var copySection: some View {
        Section {
            Button {
                onCopy()
                showsCopied = true
            } label: {
                Label(showsCopied ? "Copied" : "Copy review", systemImage: showsCopied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(showsCopied)
            .task(id: showsCopied) {
                guard showsCopied else { return }
                try? await Task.sleep(for: .seconds(2))
                showsCopied = false
            }
        }
    }

    private var clearSection: some View {
        Section {
            Button("Clear review", role: .destructive) { isConfirmingClear = true }
                .frame(maxWidth: .infinity, minHeight: 44)
        } footer: {
            Text("Paste it to your agent first — clearing deletes it from this phone.")
        }
    }

    private func span(of lines: CommentedLines) -> String {
        lines.first == lines.last ? "\(lines.first)" : "\(lines.first)-\(lines.last)"
    }
}
