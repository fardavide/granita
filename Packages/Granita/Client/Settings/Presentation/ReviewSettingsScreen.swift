import SwiftUI

import ClientSettingsUi

/// The review's settings, with the model that reads and writes them.
///
/// Pinned in `@State` for the reason every other screen here pins one: the composition root rebuilds
/// this on each evaluation of the closure that presents it, and a plain property would swap the
/// model out from under a `.task` that is already loading through the first one.
public struct ReviewSettingsScreen: View {

    @State private var model: ClientSettingsModel

    /// **Not pinned in `@State`, and that is the difference between the two models on this screen.**
    /// The review's settings are per Mac and this screen owns that model's life; the appearance is one
    /// object for the whole app, held by the composition root and observed by the scene root as well —
    /// so pinning a copy here would give the sheet a second one and the picker would move a value the
    /// rest of the app was not watching.
    private let appearance: AppearanceModel

    /// **The sheet's own dismissal rather than a closure handed down.** A `onClose: {}` passed from
    /// the composition root is a *Done* button that does nothing, which is the one defect this
    /// project will not ship — and the environment already carries the real thing here.
    @Environment(\.dismiss) private var dismiss

    private let onPair: () -> Void

    public init(
        model: ClientSettingsModel,
        appearance: AppearanceModel,
        onPair: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.appearance = appearance
        self.onPair = onPair
    }

    public var body: some View {
        ReviewSettingsView(
            openingLine: $model.openingLineDraft,
            identifier: model.settings.identifier,
            isOpeningLineDefault: model.isOpeningLineDefault,
            standing: model.standing,
            macName: model.macName,
            appearance: appearance.appearance,
            codeTheme: appearance.codeTheme,
            onChoose: { identifier in Task { await model.choose(identifier) } },
            // No `Task` around either of these, and the asymmetry with the two above it is the point:
            // the review's settings are offered to a Mac and these are written to this device, so there
            // is nothing to await and no standing to report.
            onChooseAppearance: { appearance.choose($0) },
            onChooseCodeTheme: { appearance.choose($0) },
            onCommitOpeningLine: { Task { await model.commitOpeningLine() } },
            onReset: { Task { await model.resetOpeningLine() } },
            onPair: onPair,
            onClose: { dismiss() }
        )
        // Asked on open rather than held live: these are read at the moment a reader goes looking
        // for them, and there is nothing here worth a subscription.
        .task { await model.load() }
    }
}
