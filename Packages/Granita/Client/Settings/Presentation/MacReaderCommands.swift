import SwiftUI

import ClientViewerDomain
import CoreComponentsUi

public struct MacReaderCommands: Commands {
    private let model: AppearanceModel
    @FocusedValue(\.readerSidebarRefresh) private var refreshSidebar
    @FocusedValue(\.readerDiffRefresh) private var refreshDiff
    @FocusedValue(\.readerInspector) private var inspector

    public init(model: AppearanceModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(after: .sidebar) {
            Toggle("Side by Side", isOn: Binding(
                get: { model.isSideBySide },
                set: { model.chooseSideBySide($0) }
            ))
            Divider()
            Button("Increase Code Size") { model.adjustCodeSize(by: 1) }
                .keyboardShortcut("+")
                .disabled((model.isSideBySide ? model.codeSizeReadout.split.pointSize : model.codeSizeReadout.unified.pointSize) >= CodeSize.largest)
                .help("Maximum code size: 17 points")
            Button("Decrease Code Size") { model.adjustCodeSize(by: -1) }
                .keyboardShortcut("-")
                .disabled((model.isSideBySide ? model.codeSizeReadout.split.pointSize : model.codeSizeReadout.unified.pointSize) <= CodeSize.smallest)
                .help("Minimum code size: 8 points")
            Button("Actual Code Size") { model.restoreCodeSize() }
                .keyboardShortcut("0")
                .disabled((model.isSideBySide ? model.codeSize.split : model.codeSize.unified) == .followSystem)
                .help("The code already follows the system size")
            Menu("Code Colours") {
                Picker("Code Colours", selection: Binding(
                    get: { model.codeTheme },
                    set: { model.choose($0) }
                )) {
                    ForEach(CodeTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Divider()
            Button(inspector?.isPresented == true ? "Hide Inspector" : "Show Inspector") {
                inspector?.toggle()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .disabled(inspector == nil)
            .help(inspector == nil ? "Choose a worktree with files or an open review" : "")
            Button("Refresh") {
                refreshSidebar?()
                refreshDiff?()
            }
            .keyboardShortcut("r")
            .disabled(refreshSidebar == nil)
            .help(refreshSidebar == nil ? "Open the reader to refresh its worktrees" : "")
        }
    }
}
