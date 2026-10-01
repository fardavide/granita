import SwiftUI

import ClientConnectionDomain
import ClientMacDomain

public struct MacSourceMenuView: View {
    private let source: ReaderSource
    private let content: MacSourceMenuContentView

    public init(
        source: ReaderSource,
        menu: MacSourceMenu,
        remembered: Set<BonjourInstanceName>,
        logCopyState: DiagnosticCopyState,
        onChoose: @escaping (ReaderSource) -> Void,
        onSearchAgain: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCopyLogs: @escaping () -> Void
    ) {
        self.source = source
        content = MacSourceMenuContentView(
            source: source, menu: menu, remembered: remembered, logCopyState: logCopyState,
            onChoose: onChoose, onSearchAgain: onSearchAgain,
            onOpenSettings: onOpenSettings, onCopyLogs: onCopyLogs
        )
    }

    public var body: some View {
        Menu {
            content
        } label: {
            switch source {
            case .thisMac: Text("This Mac")
            case .remote(let server): Text(server.name).truncationMode(.middle)
            }
        }
        .accessibilityIdentifier("granita.reader.source")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
