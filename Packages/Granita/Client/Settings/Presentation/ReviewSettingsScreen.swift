import SwiftUI

import ClientSettingsUi

/// The review's settings, with the model that reads and writes them.
///
/// Pinned in `@State` for the reason every other screen here pins one: the composition root rebuilds
/// this on each evaluation of the closure that presents it, and a plain property would swap the
/// model out from under a `.task` that is already loading through the first one.
public struct ReviewSettingsScreen: View {

    @State private var model: ClientSettingsModel

    /// **The sheet's own dismissal rather than a closure handed down.** A `onClose: {}` passed from
    /// the composition root is a *Done* button that does nothing, which is the one defect this
    /// project will not ship — and the environment already carries the real thing here.
    @Environment(\.dismiss) private var dismiss

    private let onPair: () -> Void

    public init(model: ClientSettingsModel, onPair: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onPair = onPair
    }

    public var body: some View {
        ReviewSettingsView(
            openingLine: $model.openingLineDraft,
            identifier: model.settings.identifier,
            isOpeningLineDefault: model.isOpeningLineDefault,
            standing: model.standing,
            macName: model.macName,
            onChoose: { identifier in Task { await model.choose(identifier) } },
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
