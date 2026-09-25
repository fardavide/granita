/// Which Mac this phone opened last, so the next launch can open it rather than the list.
///
/// **A preference rather than a store, and the distinction is what it is allowed to hold**: a name,
/// never a credential. What makes a Mac openable at all is the pairing `RememberedMacStore` keeps in
/// the Keychain; this only says which of them the reader was reading. Losing it costs a reader one
/// tap, which is what makes somewhere losable the right home for it.
///
/// **Synchronous, and that is a requirement rather than a convenience.** The answer is needed before
/// the stack draws its first frame; a read that suspended would put the Mac list on screen for the
/// frame it took, which is the flicker resuming exists to remove.
public protocol LastOpenedMacPreference: Sendable {

    /// The Mac to open at, or nothing on a phone that has never opened one.
    func lastOpenedMac() -> DiscoveredServer?

    func remember(_ mac: DiscoveredServer)

    /// Stops resuming, which is what being sent back to the pairing screens for that Mac means: the
    /// credential behind it is the thing in question, so it is no longer a Mac a launch may assume.
    func forget()
}
