import SwiftUI

import ClientSettingsDomain
import ClientViewerDomain
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

    /// What this device decides for itself, which is the fourth section and the only one on this sheet
    /// with nothing to be out of step with.
    private let appearance: AppAppearance
    private let codeTheme: CodeTheme

    /// Which half of the pair the phone is drawing right now.
    ///
    /// **Read from the environment rather than derived from `appearance`**, because *System* is an
    /// answer this view cannot resolve on its own — and it is the common case. The *in use* marker is
    /// the one thing on the screen that has to be right about it.
    @Environment(\.colorScheme) private var colorScheme
    // `@Sendable` because a `Binding`'s setter is. Without it this compiles with a data-race
    // warning rather than an error, which is how it would have reached `main` unnoticed.
    private let onChoose: @Sendable (ReviewIdentifier) -> Void
    private let onChooseAppearance: (AppAppearance) -> Void
    private let onChooseCodeTheme: (CodeTheme) -> Void
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
        appearance: AppAppearance,
        codeTheme: CodeTheme,
        onChoose: @escaping @Sendable (ReviewIdentifier) -> Void,
        onChooseAppearance: @escaping (AppAppearance) -> Void,
        onChooseCodeTheme: @escaping (CodeTheme) -> Void,
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
        self.appearance = appearance
        self.codeTheme = codeTheme
        self.onChoose = onChoose
        self.onChooseAppearance = onChooseAppearance
        self.onChooseCodeTheme = onChooseCodeTheme
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
                // **Fourth, below the receipt, and that position is the reason the three sections above
                // it keep their nine baselines.** It is also the contrast the `no-mac-at-all` state
                // exists to show: the two controls above are switched off with a sentence saying why,
                // and this one is entirely live underneath them, because nothing about how a reader's
                // code looks was ever the Mac's to answer.
                appearanceSection
                if standing == .noMac {
                    pairingSection
                }
            }
            // **No longer *Review*.** The sheet held one subject when it shipped and holds two now, and
            // the chooser's back button reads *Settings* — a back button naming a screen called
            // *Review* that also decides the app's appearance would be the first thing on it that is
            // untrue.
            .navigationTitle("Settings")
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

    // MARK: - What this device decides for itself

    /// The app's appearance and the code's colours, in one section with one sentence.
    ///
    /// **One section rather than two, and the footer is why.** Both rows are this device's and the
    /// three above them are that Mac's, so one sentence states the divide once; two sections would need
    /// it twice or leave one of them without it. They also belong together because the picker decides
    /// which half of the pair the reader is looking at, and the *in use* marker under the samples is
    /// only legible as an answer to the control directly above it.
    ///
    /// **Nothing in here is ever disabled and nothing in here can be pending.** Not even in `noMac`,
    /// where the two controls above are off: an unreachable Mac has somewhere for a value to go later
    /// and a missing one has nowhere ever, but neither is true of a value that never leaves this phone.
    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: Binding(get: { appearance }, set: onChooseAppearance)) {
                ForEach(AppAppearance.allCases, id: \.self) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // A `NavigationLink` with its destination declared in this file, which is the rule this
            // repository learned the expensive way: discovery's rows were links to a value no module
            // declared a destination for, so tapping the Mac you opened the app to read did nothing,
            // for eight releases.
            NavigationLink {
                CodeThemeChooserView(chosen: codeTheme, onChoose: onChooseCodeTheme)
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Text("Code colours")
                        Spacer(minLength: 8)
                        Text(codeTheme.displayName)
                            .foregroundStyle(.secondary)
                    }
                    CodeThemePairView(theme: codeTheme, inUse: drawnAppearance)
                }
                .padding(.vertical, 2)
            }
            .accessibilityLabel("Code colours, \(codeTheme.displayName)")
            .accessibilityValue("light and dark preview")
        } header: {
            Text("Appearance")
        } footer: {
            Text(
                "Kept on this device. Neither changes what a review says, so other devices reading "
                    + "\(macName) are unaffected."
            )
        }
    }

    /// Which half the phone is drawing, resolved where an environment exists.
    ///
    /// The picker's own value cannot answer this: *System* is the default and the common case, and what
    /// it resolves to is a fact about the phone rather than about the setting.
    private var drawnAppearance: HighlightAppearance {
        appearance.highlightAppearance.resolved(whenFollowing: colorScheme == .dark ? .dark : .light)
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
