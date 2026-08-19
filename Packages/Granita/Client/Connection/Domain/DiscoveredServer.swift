import Foundation

/// A Granita server the phone can see on the local network.
///
/// Discovery is by Bonjour rather than by address, because the server binds a service endpoint and
/// the system chooses its port — so a stored `host:port` goes stale the moment the Mac restarts.
/// The instance name is the identity; the endpoint is re-resolved every time.
public struct DiscoveredServer: Hashable, Sendable, Identifiable {

    /// The Bonjour instance name, unique within a local domain, which is what makes it the identity.
    public let id: String

    /// What to show a human. The Mac advertises its own device name.
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
