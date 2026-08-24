import SwiftUI

import ClientWorktreesDomain

/// Naming a checkout in the reader's own words.
///
/// **The footer always states what the row will read after Save, and it updates as the field
/// changes.** That one sentence answers every case at once: an empty field is not a mystery because
/// the footer says what it will fall back to, and the placeholder is that same fallback, so an empty
/// field even *looks* like the result it will produce.
///
/// Clearing needs no destructive button. The field's own clear glyph plus Save is the whole gesture,
/// and the footer confirms it before the tap — a red "Remove alias" row would put a destructive
/// treatment on an operation that touches no git state and is reversible in four seconds.
public struct WorktreeRenameSheet: View {

    private let subject: WorktreeRenameSubject
    private let onSave: (String) -> Void
    private let onCancel: () -> Void

    @State private var alias: String

    public init(
        subject: WorktreeRenameSubject,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.subject = subject
        self.onSave = onSave
        self.onCancel = onCancel
        _alias = State(initialValue: subject.alias ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(subject.derivedName, text: $alias)
                        .autocorrectionDisabled()
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    footer
                }

                // **Offered, never prefilled** — the one place this repository departs from
                // `SPEC.md` outright, and it is recorded in `decisions.md`. A prefilled field makes
                // the reader's first act a select-all and a delete of fifty-one characters on a
                // phone keyboard, and it hides the difference between accepting the agent's summary
                // and naming this yourself.
                if let suggestion = subject.suggestedAlias {
                    Section {
                        Button { alias = suggestion } label: {
                            HStack(alignment: .firstTextBaseline) {
                                // At full length, two lines if it needs them: this is the only
                                // place in the app where all sixty characters are worth reading.
                                Text(suggestion)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 12)
                                Text("Use")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    } header: {
                        Text("From the agent's session")
                    } footer: {
                        Text("Taken from the Claude Code session that ran here. Editing it is expected.")
                    }
                }
            }
            .navigationTitle("Rename")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(alias) }
                }
            }
        }
        // Medium, because renaming is a four-second job: a full-screen push would spend a
        // navigation event on it, and an alert with a text field cannot hold a two-line suggestion,
        // cannot show a live footer, and gets clipped by the keyboard.
        .presentationDetents([.medium])
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Empty means the derived name. This worktree will show as \(subject.derivedName).")
            } else {
                Text("Clear the field and save to go back to \(subject.derivedName).")
            }

            // With nothing to suggest the section above is absent, and an empty sheet with no
            // explanation is what that would leave. Saying *why* in the reader's terms turns it
            // into an answer instead.
            switch subject.derivedNameSource {
            case .sessionSuggestion:
                EmptyView()
            case .branch:
                Text("There is no session Granita could read for this worktree, so its derived name is its branch.")
            case .directory:
                Text(
                    """
                    This worktree is detached and has no session Granita could read, \
                    so its only name is its directory.
                    """
                )
            }
        }
    }
}
