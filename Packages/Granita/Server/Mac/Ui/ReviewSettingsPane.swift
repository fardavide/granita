import SwiftUI

import CoreReviewDomain

/// The Settings window's Review pane: the two settings every exported review is shaped by.
///
/// **The only pane whose values a phone both reads and writes**, which is most of the argument for
/// it having a tab of its own rather than sharing General's or Advanced's.
///
/// It should feel like a preference that was always meant to be there — two rows a reader reads
/// once, changes once, and never opens again. The sample below them is the only thing on the pane
/// worth looking at twice.
public struct ReviewSettingsPane: View {

    private let openingLine: Binding<String>
    private let identifier: ReviewIdentifier
    private let isOpeningLineDefault: Bool
    private let storedReviews: Int
    private let storedComments: Int
    // `@Sendable` because a `Binding`'s setter is, and handing it a closure that is not produces a
    // data-race warning under complete checking rather than a compile error — which is the kind of
    // thing that reaches `main` as a warning nobody read.
    private let onChoose: @Sendable (ReviewIdentifier) -> Void
    private let onCommitOpeningLine: () -> Void
    private let onReset: () -> Void

    public init(
        openingLine: Binding<String>,
        identifier: ReviewIdentifier,
        isOpeningLineDefault: Bool,
        storedReviews: Int,
        storedComments: Int,
        onChoose: @escaping @Sendable (ReviewIdentifier) -> Void,
        onCommitOpeningLine: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.openingLine = openingLine
        self.identifier = identifier
        self.isOpeningLineDefault = isOpeningLineDefault
        self.storedReviews = storedReviews
        self.storedComments = storedComments
        self.onChoose = onChoose
        self.onCommitOpeningLine = onCommitOpeningLine
        self.onReset = onReset
    }

    public var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Opening line", text: openingLine)
                        .onSubmit(onCommitOpeningLine)
                    // **Visibly disabled rather than absent**, which is the one place this pane and
                    // the phone's screen differ on purpose: a Mac window has room to show a control
                    // that is not available, and a grouped row on a phone does not.
                    Button("Reset", action: onReset)
                        .disabled(isOpeningLineDefault)
                }

                Picker("Comment labels", selection: Binding(get: { identifier }, set: onChoose)) {
                    Text("A. B. C.").tag(ReviewIdentifier.letters)
                    Text("1. 2. 3.").tag(ReviewIdentifier.numbers)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("What a review looks like")
            } footer: {
                Text(
                    "Every review copied from a phone or an iPad begins with this line, and its "
                        + "comments are named this way."
                )
                .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 2) {
                    if openingLine.wrappedValue.isEmpty == false {
                        Text(openingLine.wrappedValue)
                    }
                    Text("")
                    Text("\(identifier.label(at: 0)). Sources/Worktree.swift:12-14")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            } header: {
                Text("Sample")
            }

            // **Two numbers, and it is not a review browser.** `SPEC.md` §9 called the viewed marks
            // the store's only unbounded collection and that stopped being true when reviews landed
            // here — a comment carries an excerpt, so these are kilobytes where a mark is bytes.
            // This is where a reader sees the document is not growing without bound.
            //
            // **No clear button.** Clearing is the reader's act at the moment they paste, and a
            // button here would destroy a review a phone might still be holding unsent. Pruning is a
            // rule rather than a control: reviews for worktrees that are gone go at startup.
            Section {
                LabeledContent("Stored reviews", value: "\(storedReviews)")
                LabeledContent("Comments in them", value: "\(storedComments)")
            }
        }
        .formStyle(.grouped)
    }
}
