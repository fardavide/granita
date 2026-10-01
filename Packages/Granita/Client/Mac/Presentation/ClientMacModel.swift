import Observation

import ClientMacDomain
import ServerApiDomain

@Observable
public final class ClientMacModel {
    public private(set) var selection: ReaderSelection

    private let memory: any ReaderSelectionMemory

    public init(memory: any ReaderSelectionMemory) {
        self.memory = memory
        selection = memory.read()
    }

    public func choose(source: ReaderSource) {
        guard source != selection.source else { return }
        selection = ReaderSelection(source: source, worktree: .none)
        memory.remember(selection)
    }

    public func choose(worktree: ReaderWorktreeSelection) {
        selection = ReaderSelection(source: selection.source, worktree: worktree)
        memory.remember(selection)
    }

    public func canReadLocal(serverState: ServerRunState) -> Bool {
        switch serverState {
        case .starting, .running, .failed, .stopped:
            true
        case .blockedByAnotherProcess:
            false
        }
    }
}
