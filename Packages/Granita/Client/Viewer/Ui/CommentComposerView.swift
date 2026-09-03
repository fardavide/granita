import SwiftUI

/// Where the reader writes what they have to say about a run of lines.
///
/// **A sheet at one fixed height, with the diff still live behind it.** Design §7.2 keeps the file
/// selector's best property and drops the rest: no dimming, no `.large`, and no drag to resize,
/// because the keyboard has already decided how tall this is. What the reader keeps is the ability to
/// scroll the diff behind it and check the caller they are about to complain about, without losing
/// what they have typed.
///
/// **The excerpt is the receipt for an 18pt aim.** Three rows of the anchored code, at a size of its
/// own, is what stops a reader typing a paragraph against the wrong line and finding out on the Mac —
/// and it is the same snapshot that gets exported, which is why it is drawn from the diff rather than
/// re-fetched.
///
/// **An alert with a text field was the cheap alternative and it was rejected.** It cannot show the
/// excerpt, cannot scroll a long comment, and cannot carry a 44pt range control — which would make
/// the answer to the 44pt question in `GutterTarget` untrue.
public struct CommentComposerView: View {

    /// The one detent this sheet has. Fixed rather than a range, because the keyboard sets the height
    /// and a reader dragging a composer taller is a reader hiding the code it is about.
    public static let detentHeight: CGFloat = 300

    /// The excerpt's own size, and it is a third one beside the diff's 11 and 12.
    ///
    /// Smaller on purpose: this is a quotation rather than the thing being read, and it is inside a
    /// sheet where nothing has to line up with the gutter.
    public static let excerptPointSize: CGFloat = 10.5

    /// How many rows of the excerpt are drawn before the rest becomes a count.
    public static let excerptRows = 3

    private let anchorLabel: String
    private let excerpt: [String]
    private let isEditing: Bool
    private let text: Binding<String>
    private let onCancel: () -> Void
    private let onSave: () -> Void
    private let onDelete: () -> Void

    public init(
        anchorLabel: String,
        excerpt: [String],
        isEditing: Bool,
        text: Binding<String>,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.anchorLabel = anchorLabel
        self.excerpt = excerpt
        self.isEditing = isEditing
        self.text = text
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            // **The anchor is pinned above the field and the field scrolls inside its own frame**,
            // which is design §7.2's answer to a comment longer than the sheet. The one thing a
            // reader must never lose sight of while writing is which lines they are writing about.
            anchor
            quotation
            Divider()
            field
            if isEditing {
                Divider()
                deleteRow
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .frame(minWidth: 60, minHeight: 44, alignment: .leading)
            Spacer(minLength: 8)
            Text("Comment")
                .font(.headline)
            Spacer(minLength: 8)
            Button("Save", action: onSave)
                .fontWeight(.semibold)
                .frame(minWidth: 60, minHeight: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
    }

    /// **44pt, and that is the whole of section one's remedy for an 18pt aim.** A reader who lands one
    /// row off fixes it here, at full size, after the aim rather than during it — which is what makes
    /// the target's height cheap to be wrong about.
    ///
    /// It is a plain label until the range controls exist. Drawn as the design's `Menu` the day
    /// extend-up / extend-down / shrink lands; a menu with no items would be this project's dead
    /// control, so it is a label that says what the comment is about and nothing more.
    private var anchor: some View {
        Text(anchorLabel)
            .font(.subheadline.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 16)
    }

    private var quotation: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(excerpt.prefix(Self.excerptRows).enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if excerpt.count > Self.excerptRows {
                let rest = excerpt.count - Self.excerptRows
                Text(rest == 1 ? "+1 more line" : "+\(rest) more lines")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: Self.excerptPointSize, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var field: some View {
        TextField("What is wrong with these lines?", text: text, axis: .vertical)
            .font(.body)
            .lineLimit(3...)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// **The only place a single comment can be destroyed from the diff**, and it exists only for one
    /// that is already there. On a new comment there is nothing to delete and Cancel is the answer.
    private var deleteRow: some View {
        Button("Delete Comment", role: .destructive, action: onDelete)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
    }
}
