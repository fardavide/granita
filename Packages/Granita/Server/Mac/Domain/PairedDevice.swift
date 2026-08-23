import Foundation

/// One phone the Devices tab draws a row for.
///
/// Not `StoredDevice`: the row shows nothing of the token hash and shows one thing the store does
/// not hold at all. Mapping at the boundary is what keeps the record a reader's device is kept as
/// separate from the record they are shown.
public struct PairedDevice: Identifiable, Hashable, Sendable {

    public let id: String
    public let name: String

    /// As the phone reported it — `iOS`, `iPadOS`. Printed rather than interpreted, because a
    /// platform this Mac has not heard of is still worth showing.
    public let platform: String

    public let pairedAt: Date
    public let sighting: DeviceSighting

    public init(id: String, name: String, platform: String, pairedAt: Date, sighting: DeviceSighting) {
        self.id = id
        self.name = name
        self.platform = platform
        self.pairedAt = pairedAt
        self.sighting = sighting
    }
}

/// When this device was last heard from, as far as anything on this Mac can honestly say.
///
/// **Only ever about the current run.** `StoredDevice` holds when a device paired and nothing later,
/// and the connection log is in memory — so a device that has not been served since Granita started
/// is not a device that has not been used. Saying *Last seen 3 August* over that would be an
/// accusation the data cannot support, which is why the absence carries the moment the watching
/// began instead of a date.
///
/// Persisting it properly was rejected: the store rewrites the whole document and is contracted as
/// "written rarely, read on every request", so a polling phone would turn every request into a disk
/// write. If it is ever wanted it is a coarse daily stamp written on change.
public enum DeviceSighting: Hashable, Sendable {

    case seen(at: Date)

    /// Nothing from this device since Granita started, at the moment it started.
    case notSeenSince(Date)
}
