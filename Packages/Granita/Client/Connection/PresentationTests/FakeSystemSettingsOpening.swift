import Synchronization

import ClientConnectionDomain

/// **Which pane was asked for, kept**, because that is the whole of what this seam decides and the one
/// thing a screen can get wrong: three screens offer the control and two of them mean a different
/// switch from the third.
///
/// A `Mutex` rather than an actor, unlike the copying fake beside it: `open` is not `async`, so a
/// screen calls it straight through and a fake that had to be awaited could not conform.
final class FakeSystemSettingsOpening: SystemSettingsOpening {

    private let opened = Mutex<[SystemSettingsPane]>([])

    var panes: [SystemSettingsPane] {
        opened.withLock { $0 }
    }

    var invocations: Int {
        panes.count
    }

    func open(_ pane: SystemSettingsPane) {
        opened.withLock { $0.append(pane) }
    }
}
