import SwiftUI

import ClientSettingsDomain
import CoreReviewDomain

private extension Color {

    /// The same amber a changed file's status letter is drawn in, stated here rather than reached
    /// for across a module boundary.
    ///
    /// **`ClientViewerUi` owns the palette and this target may not see it** — they are siblings over
    /// `Domain`, not a pipeline. One colour duplicated is the smaller cost: the alternative is a
    /// dependency from a settings screen to the diff's view layer, which would be the first crack in
    /// the rule that keeps those two apart. The value is `#C0821F`, the one the frames returned.
    static let reviewSettingsAmber = Color(red: 0.753, green: 0.510, blue: 0.122)
}

/// The review's two settings, as a sheet of stock grouped rows.
///
/// **Nothing on it is a new control and nothing on it is a spinner.** The seven states this screen
/// can be in are one shape with one changing footer: the controls never move, they disable only
/// where a value would have nowhere to go, and the sentence underneath says what this phone and that
/// Mac currently disagree about.
///
/// It should feel like a preference pane the reader can close without wondering whether anything was
/// saved — dull, immediate, and never between them and the code.
public struct ReviewSettingsView: View {

    private let openingLine: Binding<String>
    private let identifier: ReviewIdentifier
    private let isOpeningLineDefault: Bool
    private let standing: ReviewSettingsStanding
    private let macName: String
    // `@Sendable` because a `Binding`'s setter is. Without it this compiles with a data-race
    // warning rather than an error, which is how it would have reached `main` unnoticed.
    private let onChoose: @Sendable (ReviewIdentifier) -> Void
    private let onCommitOpeningLine: () -> Void
    private let onReset: () -> Void
    private let onPair: () -> Void
    private let onClose: () -> Void

    @FocusState private var isEditing: Bool

    public init(
        openingLine: Binding<String>,
        identifier: ReviewIdentifier,
        isOpeningLineDefault: Bool,
        standing: ReviewSettingsStanding,
        macName: String,
        onChoose: @escaping @Sendable (ReviewIdentifier) -> Void,
        onCommitOpeningLine: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onPair: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.openingLine = openingLine
        self.identifier = identifier
        self.isOpeningLineDefault = isOpeningLineDefault
        self.standing = standing
        self.macName = macName
        self.onChoose = onChoose
        self.onCommitOpeningLine = onCommitOpeningLine
        self.onReset = onReset
        self.onPair = onPair
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            Form {
                openingLineSection
                labelSection
                if standing != .noMac {
                    receiptSection
                }
                if standing == .noMac {
                    pairingSection
                }
            }
            .navigationTitle("Review")
            // The Client compiles for macOS too — the Mac Client links these same views — and the
            // inline title is one of the modifiers that does not exist there.
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    // MARK: - The two controls

    /// **Real editable text, never a placeholder.** A placeholder says *type something here*; these
    /// grey words would be the exact string that gets exported, which is a different claim — and
    /// Davide's own sentence for this screen is *"you will see the default one, and you will be able
    /// to edit it"*.
    private var openingLineSection: some View {
        Section {
            TextField("", text: openingLine, axis: .vertical)
                .focused($isEditing)
                .disabled(standing.acceptsEdits == false)
                // **Dimmed only when it is genuinely inoperable**, which is a different question
                // from whether the line is the default. `.disabled` greys the segmented control on
                // its own and leaves a text field looking exactly as editable as before — so a
                // reader would tap this, get no keyboard, and be given no reason. The footer says
                // why; this is what makes the field agree with it.
                .foregroundStyle(standing.acceptsEdits ? .primary : .secondary)
                .onSubmit(onCommitOpeningLine)
                .onChange(of: isEditing) { _, editing in
                    if editing == false { onCommitOpeningLine() }
                }
            // Absent when there is nothing to reset, which is the other half of how the default is
            // told apart. A reader who has never touched this sees neither this row nor the sentence
            // that names their own line.
            if isOpeningLineDefault == false, standing.acceptsEdits {
                Button("Reset to the default line", action: onReset)
            }
        } header: {
            Text("Opening line")
        } footer: {
            // **The only mark on this screen**, and it means one thing: what this phone holds and
            // what that Mac holds are not the same. The same amber a changed file's letter uses, so
            // it needs no legend — and absent in every state where nothing disagrees, including the
            // two where the controls are off, because nothing is pending there either.
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if isUnsettled {
                    Circle()
                        .fill(Color.reviewSettingsAmber)
                        .frame(width: 6, height: 6)
                }
                Text(openingLineFooter)
            }
        }
    }

    /// **A segmented control whose segments are the thing itself**, so the setting is its own
    /// preview. A popup menu would hide one option behind a tap and show the chosen one as a word.
    private var labelSection: some View {
        Section {
            Picker(
                "Comment labels",
                selection: Binding(get: { identifier }, set: onChoose)
            ) {
                Text("A. B. C.").tag(ReviewIdentifier.letters)
                Text("1. 2. 3.").tag(ReviewIdentifier.numbers)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(standing.acceptsEdits == false)
        } header: {
            Text("Comment labels")
        } footer: {
            Text("How each comment is named in the copied review, so you can ask your agent to reply point by point.")
        }
    }

    /// **The only place both settings are legible together.** The two controls are about a document
    /// the reader cannot see from here, so this shows them what they add up to. It is text rather
    /// than a control, which is why nothing on this screen needs a preview button.
    private var receiptSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                if let line = resolvedOpeningLine {
                    Text(line)
                }
                Text("")
                Text("\(identifier.label(at: 0)). Sources/Worktree.swift:12-14")
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        } header: {
            Text("What a review begins with")
        }
    }

    private var pairingSection: some View {
        Section {
            Button("Pair with a Mac", action: onPair)
        }
    }

    // MARK: -

    private var resolvedOpeningLine: String? {
        openingLine.wrappedValue.isEmpty ? nil : openingLine.wrappedValue
    }

    /// Whether the two copies of these settings disagree, which is the only thing the dot reports.
    ///
    /// Saving is not one of them: a write in flight is not a disagreement, it is the absence of one
    /// arriving. Neither is a Mac that cannot hold these at all — nothing is pending for it.
    private var isUnsettled: Bool {
        switch standing {
        case .queued, .refused: true
        case .settled, .saving, .tooOld, .noMac: false
        }
    }

    /// The one sentence that changes, and the whole of what this screen says about the connection.
    private var openingLineFooter: String {
        switch standing {
        case .settled where isOpeningLineDefault:
            "This is the default line. Every review you copy begins with it until you change it. "
                + "Stored on \(macName)."
        // **Cleared is its own sentence, because the ordinary one would be false here.** "Every
        // review begins with this line" said over an empty field describes a line that does not
        // exist — and clearing it is a deliberate choice rather than an unfinished edit, so what the
        // reader needs is confirmation that the choice took.
        case .settled where resolvedOpeningLine == nil:
            "Reviews begin at your first comment. Stored on \(macName), so any device reading it "
                + "starts the same way."
        case .settled:
            "Every review you copy begins with this line. Stored on \(macName), so any device "
                + "reading it starts the same way."
        case .saving:
            "Saving to \(macName)…"
        case .queued:
            "\(macName) is not reachable. What you change is kept on this phone and sent when it "
                + "answers."
        case .refused(let reason):
            reason.map { "\(macName) cannot save this, so it still has the old line. \($0)" }
                ?? "\(macName) cannot save this, so it still has the old line. This phone will keep "
                    + "using the one above."
        case .tooOld:
            "Granita on \(macName) is too old to store this. Update it, or keep these on this phone."
        case .noMac:
            "These are stored on the Mac you read from, so there is nowhere to keep them yet. "
                + "Reviews begin with the default line above."
        }
    }
}
