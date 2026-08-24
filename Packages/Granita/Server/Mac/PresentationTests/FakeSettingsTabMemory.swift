import ServerMacDomain

/// What a previous launch left behind, and what this one wrote down.
///
/// A class rather than an actor, because the protocol it implements is synchronous: the model reads
/// the remembered pane while it is being built, which is what makes "the window opens on Projects the
/// first time and on Connections the second" one assertion rather than a race.
final class FakeSettingsTabMemory: SettingsTabMemory, @unchecked Sendable {

    private(set) var remembered: [SettingsTab] = []

    private let stored: SettingsTab?

    /// `nil` is a first run, which is the case worth being the default: it is the one design §2
    /// makes a decision about.
    init(stored: SettingsTab?) {
        self.stored = stored
    }

    func lastUsedTab() -> SettingsTab? {
        remembered.last ?? stored
    }

    func remember(_ tab: SettingsTab) {
        remembered.append(tab)
    }
}
