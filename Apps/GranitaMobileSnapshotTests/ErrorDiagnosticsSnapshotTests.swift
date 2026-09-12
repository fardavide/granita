import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionUi
import ClientViewerDomain
import ClientViewerUi
import ClientWorktreesDomain
import ClientWorktreesUi

@Suite("Error diagnostics", .serialized)
@MainActor
struct ErrorDiagnosticsSnapshotTests {

    @Test(arguments: ErrorCase.all, SnapshotLayout.all)
    private func `given an error and copy state when rendering then recovery and reporting remain readable`(
        subject: ErrorCase,
        layout: SnapshotLayout
    ) {
        // given
        let diagnostic = String(
            repeating: "RAW-DIAGNOSTIC-MUST-NOT-RENDER NSURLErrorDomain (-1200) TLS handshake failed.\n",
            count: 12
        )

        // when - then
        assertScreenSnapshot(
            errorScreen(subject, diagnostic: diagnostic, layout: layout)
                .environment(\.dynamicTypeSize, subject.logCopyState == .failed ? .accessibility1 : .large)
                // The public flag is read-only; this SDK exposes its writable override for test fixtures.
                .environment(\._accessibilityReduceMotion, subject.logCopyState == .failed),
            layout: layout,
            named: subject.name
        )
    }

    @ViewBuilder
    private func errorScreen(
        _ subject: ErrorCase,
        diagnostic: String,
        layout: SnapshotLayout
    ) -> some View {
        switch subject.screen {
        case .discovery:
            NavigationStack {
                ServerDiscoveryView(
                    state: .failed(diagnostic: diagnostic),
                    logCopyState: subject.logCopyState,
                    onSearchAgain: {},
                    onOpenSettings: {},
                    onCopyLogs: {}
                )
            }
        case .worktrees:
            NavigationStack {
                WorktreeSidebarView(
                    macName: "Davide's MacBook Pro",
                    state: .failed(.unreachable(diagnostic: diagnostic)),
                    logCopyState: subject.logCopyState,
                    mode: .groupedByProject,
                    showsQuietWorktrees: false,
                    removing: [],
                    onChooseMode: { _ in },
                    onShowQuietWorktrees: { _ in },
                    onRename: { _ in },
                    onSetPinned: { _, _ in },
                    onDelete: { _ in },
                    onRetry: {},
                    onCopyLogs: {}
                )
            }
            .frame(maxWidth: layout.isRegularWidth ? WorktreeSidebarView.widthInASplitView : nil)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .viewer:
            NavigationStack {
                ContinuousDiffView(
                    state: .failed(.unreachable(diagnostic: diagnostic)),
                    logCopyState: subject.logCopyState,
                    pointSize: layout.codePointSize,
                    jumpTarget: nil,
                    onReading: { _ in },
                    onJumped: {},
                    onSetViewed: { _, _ in },
                    onSetOpen: { _, _ in },
                    onExpand: { _, _, _ in },
                    onRetry: {},
                    onCopyLogs: {}
                )
                .navigationTitle("Mobile diagnostics")
                .navigationBarTitleDisplayMode(.inline)
            }
        case .pairing:
            NavigationStack {
                PairingOutcomeView(
                    macName: "Davide's MacBook Pro",
                    state: .notReached(.unreachable(diagnostic: diagnostic)),
                    logCopyState: subject.logCopyState,
                    canOpenTestFlight: false,
                    onTryAgain: {},
                    onSaveTokenAgain: {},
                    onOpenTestFlight: {},
                    onOpenSettings: {},
                    onCopyLogs: {}
                )
            }
        }
    }

    private enum ErrorScreen: String, CaseIterable, Sendable {
        case discovery
        case worktrees
        case viewer
        case pairing
    }

    private struct ErrorCase: Sendable, CustomTestStringConvertible {

        let screen: ErrorScreen
        let logCopyState: DiagnosticCopyState

        var name: String {
            let stateName: String
            switch logCopyState {
            case .ready: stateName = "ready"
            case .copying: stateName = "copying"
            case .copied: stateName = "copied"
            case .failed: stateName = "failed-accessibility-reduce-motion"
            }
            return "\(screen.rawValue)-\(stateName)"
        }

        var testDescription: String { name }

        static let all: [ErrorCase] = ErrorScreen.allCases.flatMap { screen in
            [DiagnosticCopyState.ready, .copying, .copied, .failed].map {
                ErrorCase(screen: screen, logCopyState: $0)
            }
        }
    }
}
