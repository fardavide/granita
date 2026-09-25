/// The Mac this phone was reading last, put back on the stack before its first draw.
///
/// **Its own value rather than the one a browsed row carries, and that is the whole reason it
/// exists.** The Mac list declares one destination for a `DiscoveredServer` and branches it on
/// whether this phone remembers that Mac — against a set filled by that screen's own `.task`. A
/// `DiscoveredServer` seeded onto the path is resolved on the first pass, before the task has run,
/// so the answer is `false`; and the branch is pinned in `@State`, so it never corrects itself. A
/// launch that resumed through that value would open the pairing screens for a Mac this phone is
/// already paired with, which is the defect design §5 and 0.4.0 exist to have ended.
///
/// This value has one destination and no branch.
public struct ResumedMac: Hashable, Sendable {

    public let server: DiscoveredServer

    public init(server: DiscoveredServer) {
        self.server = server
    }
}
