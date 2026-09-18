/// Where this phone's copy of the review settings stands against the Mac they belong to.
///
/// **The screen is one shape with one changing footer**, and this is what changes it. The two
/// controls never move and never disable except in the one case where a value has nowhere to go —
/// so everything the reader is told about the connection is said in a sentence underneath, not by
/// something becoming unusable.
///
/// There is deliberately **no loading case**. The screen opens on the last values it read or on the
/// defaults, and both are values it would honour, so there is nothing for a spinner to stand in
/// front of.
public enum ReviewSettingsStanding: Hashable, Sendable {

    /// Read from the Mac and agreed with it. The footer says where they are stored and nothing else.
    case settled

    /// A write is on its way. One sentence changes and nothing else does — no spinner, no disabled
    /// control, and no confirmation afterwards, because a LAN write that succeeds in 40ms should not
    /// leave a mark.
    case saving

    /// The Mac is not reachable. **The controls stay live and what the reader changes is kept here**
    /// until it answers, because a closed laptop is the normal condition and read-only controls
    /// would be unusable for most of the time this app is open.
    case queued

    /// The Mac answered and refused. The two copies disagree and this phone's is the one being used.
    case refused(reason: String?)

    /// That Mac predates these settings, so there is no route to send them to and nothing queues.
    case tooOld

    /// No Mac at all. The screen is still reachable — otherwise it could never be found — and the
    /// controls are off, because queueing needs an addressee and a control that accepts a value it
    /// will discard is worse than one that is plainly inert.
    case noMac

    /// Whether a value the reader sets now has somewhere to end up, eventually.
    ///
    /// The one thing on this screen that turns a control off, and it is false in exactly two cases:
    /// an unreachable Mac answers later, a Mac that never existed does not.
    public var acceptsEdits: Bool {
        switch self {
        case .settled, .saving, .queued, .refused: true
        case .tooOld, .noMac: false
        }
    }
}
