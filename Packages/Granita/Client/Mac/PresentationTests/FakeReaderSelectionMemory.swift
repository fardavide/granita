import Synchronization

import ClientMacDomain

final class FakeReaderSelectionMemory: ReaderSelectionMemory {

    private let stored: Mutex<ReaderSelection>

    init(remembering selection: ReaderSelection) {
        stored = Mutex(selection)
    }

    func read() -> ReaderSelection {
        stored.withLock { $0 }
    }

    func remember(_ selection: ReaderSelection) {
        stored.withLock { $0 = selection }
    }
}
