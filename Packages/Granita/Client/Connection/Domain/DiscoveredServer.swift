import Foundation

/// What a Mac is called on this network, and the only name for one the phone holds before it has
/// spoken to it.
///
/// **This is what a remembered pairing is filed under**, which is a departure from the identifier
/// the Mac issues: `ServerInstanceId` arrives inside a pairing response, so a phone that has not
/// paired yet cannot know it, and there is nothing in a browse result to match it against. A Bonjour
/// instance name is unique within a local domain — the system appends "(2)" itself — and it is in
/// hand the instant a Mac appears in the list, which is the moment the phone has to decide whether
/// it already knows this one. See `.claude/docs/decisions.md`.
///
/// Renaming a Mac renames the service, so a rename costs one more pairing. That is the whole of the
/// price, and it is paid by the reader who renamed the machine rather than by everybody every time
/// they open the app.
public struct BonjourInstanceName: RawRepresentable, Hashable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// A Granita server the phone can see on the local network.
///
/// Discovery is by Bonjour rather than by address, because the server binds a service endpoint and
/// the system chooses its port — so a stored `host:port` goes stale the moment the Mac restarts.
/// The instance name is the identity; the endpoint is re-resolved every time.
public struct DiscoveredServer: Hashable, Sendable, Identifiable {

    /// The Bonjour instance name, unique within a local domain, which is what makes it the identity.
    public let id: BonjourInstanceName

    /// What to show a human. The Mac advertises its own device name.
    public let name: String

    public init(id: BonjourInstanceName, name: String) {
        self.id = id
        self.name = name
    }
}
