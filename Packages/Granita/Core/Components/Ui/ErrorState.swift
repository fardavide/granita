import SwiftUI

/// Keeps recovery and local reporting in the existing unavailable-content layout.
public struct ErrorState<Title: View, Description: View, Actions: View>: View {

    private let title: Title
    private let description: Description
    private let actions: Actions

    public init(
        logCopyState: ErrorReportAction.State,
        onCopyLogs: @escaping () -> Void,
        @ViewBuilder title: () -> Title,
        @ViewBuilder description: () -> Description,
        @ViewBuilder actions: (ErrorReportAction) -> Actions
    ) {
        self.title = title()
        self.description = description()
        self.actions = actions(ErrorReportAction(state: logCopyState, onCopyLogs: onCopyLogs))
    }

    public var body: some View {
        EmptyState {
            title
        } description: {
            description
        } actions: {
            actions
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

/// The value passed to an error state's action builder so recovery keeps its existing placement.
public struct ErrorReportAction: View {

    public enum State: Equatable {
        case ready
        case copying
        case copied
        case failed
    }

    private let state: State
    private let onCopyLogs: () -> Void

    public init(state: State, onCopyLogs: @escaping () -> Void) {
        self.state = state
        self.onCopyLogs = onCopyLogs
    }

    public var body: some View {
        VStack(spacing: 8) {
            Button(action: onCopyLogs) {
                switch state {
                case .ready: Text("Copy Logs")
                case .copying: Text("Copying Logs…")
                case .copied: Text("Copy Logs Again")
                case .failed: Text("Try Copying Again")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(state == .copying)

            switch state {
            case .ready, .copying:
                EmptyView()
            case .copied:
                Text("Logs copied. Paste them into your message.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .failed:
                Text("Couldn’t copy logs. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}

/// A machine's diagnostic is small print, never the reader's advice.
public struct ErrorStateDiagnostic: View {

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
    }
}
