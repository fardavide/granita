import Synchronization

import ClientMacDomain

final class FakeMacReaderSelectionMemory: ReaderSelectionMemory {
    private let selection: Mutex<ReaderSelection>

    init(selection: ReaderSelection) {
        self.selection = Mutex(selection)
    }

    func read() -> ReaderSelection { selection.withLock { $0 } }

    func remember(_ selection: ReaderSelection) {
        self.selection.withLock { $0 = selection }
    }
}
