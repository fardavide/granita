import Foundation

import CorePairingDomain

/// A link for the camera, and six words for when there is not one.
public struct PairingInvitation: Hashable, Sendable {

    /// SPEC §8's window, named here rather than only on the actor that enforces it.
    ///
    /// The countdown under the QR fills a bar against it, so a second copy of the number is a bar
    /// that empties at a different rate from the code it describes. The same reason
    /// ``ConnectionAttempt/logCapacity`` is in this layer: a view says it out loud and cannot see
    /// the implementation.
    public static let lifetime: TimeInterval = 120

    public let link: PairingLink

    /// Six words, redeeming the same pairing as the link. Not a rendering of the code — an
    /// independently random second credential.
    public let spokenCode: String

    public let expiresAt: Date

    public init(link: PairingLink, spokenCode: String, expiresAt: Date) {
        self.link = link
        self.spokenCode = spokenCode
        self.expiresAt = expiresAt
    }
}

/// What the Mac can offer a phone right now.
///
/// The live and the expired code are one case rather than two, and that is deliberate: whether a
/// code has run out is a question about the clock, not about the server, so the view is handed both
/// and decides. It is the same reason a connection log row takes the moment it is measured against —
/// a state derived from `Date()` inside a `body` is a state no picture can be taken of.
public enum PairingOffer: Hashable, Sendable {

    /// Nothing has been asked for yet, or a code is being made.
    case preparing

    case offered(PairingInvitation)

    /// Nothing is serving, so a code has no address to carry.
    case serverNotRunning

    /// A code could not be made, in the words of whatever refused.
    case unavailable(reason: String)
}

/// Makes a pairing a phone can redeem, against the address this Mac is actually reachable at.
///
/// A protocol in this layer because the Devices tab needs one and the thing that produces it lives
/// behind Hummingbird, on the other side of the module graph. Assembling it is not the small job it
/// looks: a link naming a key this Mac does not serve under pairs a phone that then refuses every
/// connection afterwards, with nothing on either side saying why.
public protocol PairingInviting: Sendable {

    func invite(at endpoint: ServerEndpoint) async throws(PairingInvitationError) -> PairingInvitation
}

public enum PairingInvitationError: Error, Hashable, Sendable {

    /// There is no identity to pin, and this is why — in words, because the only person who can act
    /// on it is standing at this Mac.
    case noIdentity(reason: String)
}
