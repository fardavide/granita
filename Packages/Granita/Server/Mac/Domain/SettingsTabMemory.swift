/// Which pane the Settings window was last on, kept between launches.
///
/// Design §2 asks for two things at once and they are the same fact seen from either end: restore
/// the pane the reader was on, and open **Projects** on a first run, because until a repository is
/// switched on the app does nothing at all. So the answer is an optional rather than a pane with a
/// default baked in — the absence *is* the first run, and what to open instead is a decision the
/// caller makes rather than one this hides.
///
/// **Synchronous, unlike every other seam here, and deliberately.** The rest of them wrap something
/// that really does take time — a subprocess, a panel a person is looking at, a document written to
/// disk. This wraps a value the system already holds in memory, and the model reads it while it is
/// being built: an `await` would buy nothing and would open a window in which a menu item asking for
/// Devices could be overwritten by a restore that landed after it.
///
/// Not the store. That document is shared with `granita-server`, which has no window and no panes,
/// and a preference belonging to one of the two processes does not belong in the file they both
/// hold.
public protocol SettingsTabMemory: Sendable {

    /// The pane last brought to the front, or nothing because this Mac has never had one up.
    func lastUsedTab() -> SettingsTab?

    func remember(_ tab: SettingsTab)
}
