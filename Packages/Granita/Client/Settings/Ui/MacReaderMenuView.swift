import SwiftUI

import ClientViewerDomain
import CoreComponentsUi

public struct MacReaderMenuView: View {
    @Binding private var isSideBySide: Bool
    @Binding private var codeTheme: CodeTheme
    private let codeSize: CodeSizeReadout.Half
    private let inspector: ReaderInspectorAction?
    private let refreshSidebar: (() -> Void)?
    private let refreshDiff: (() -> Void)?
    private let onIncreaseCodeSize: () -> Void
    private let onDecreaseCodeSize: () -> Void
    private let onRestoreCodeSize: () -> Void

    public init(
        isSideBySide: Binding<Bool>,
        codeTheme: Binding<CodeTheme>,
        codeSize: CodeSizeReadout.Half,
        inspector: ReaderInspectorAction?,
        refreshSidebar: (() -> Void)?,
        refreshDiff: (() -> Void)?,
        onIncreaseCodeSize: @escaping () -> Void,
        onDecreaseCodeSize: @escaping () -> Void,
        onRestoreCodeSize: @escaping () -> Void
    ) {
        _isSideBySide = isSideBySide
        _codeTheme = codeTheme
        self.codeSize = codeSize
        self.inspector = inspector
        self.refreshSidebar = refreshSidebar
        self.refreshDiff = refreshDiff
        self.onIncreaseCodeSize = onIncreaseCodeSize
        self.onDecreaseCodeSize = onDecreaseCodeSize
        self.onRestoreCodeSize = onRestoreCodeSize
    }

    public var body: some View {
        Toggle("Side by Side", isOn: $isSideBySide)
        Divider()
        Button("Increase Code Size", action: onIncreaseCodeSize)
            .keyboardShortcut("+")
            .disabled(codeSize.pointSize >= CodeSize.largest)
            .help("Maximum code size: 17 points")
        Button("Decrease Code Size", action: onDecreaseCodeSize)
            .keyboardShortcut("-")
            .disabled(codeSize.pointSize <= CodeSize.smallest)
            .help("Minimum code size: 8 points")
        Button("Actual Code Size", action: onRestoreCodeSize)
            .keyboardShortcut("0")
            .disabled(codeSize.choice == .followSystem)
            .help("The code already follows the system size")
        Menu("Code Colours") {
            Picker("Code Colours", selection: $codeTheme) {
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
