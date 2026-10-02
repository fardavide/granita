import SwiftUI

import ClientSettingsPresentation
import ClientSettingsUi
import CoreComponentsUi

struct MacReaderCommands: Commands {
    let model: AppearanceModel
    @FocusedValue(\.readerSidebarRefresh) private var refreshSidebar
    @FocusedValue(\.readerDiffRefresh) private var refreshDiff
    @FocusedValue(\.readerInspector) private var inspector

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            MacReaderMenuView(
                isSideBySide: Binding(get: { model.isSideBySide }, set: model.chooseSideBySide),
                codeTheme: Binding(get: { model.codeTheme }, set: model.choose),
                codeSize: model.activeCodeSize,
                inspector: inspector,
                refreshSidebar: refreshSidebar,
                refreshDiff: refreshDiff,
                onIncreaseCodeSize: { model.adjustCodeSize(by: 1) },
                onDecreaseCodeSize: { model.adjustCodeSize(by: -1) },
                onRestoreCodeSize: model.restoreCodeSize
            )
        }
    }
}
