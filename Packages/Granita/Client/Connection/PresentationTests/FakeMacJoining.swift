import ClientConnectionDomain
import CorePairingDomain

/// A Mac that ends the attempt however a test needs it to.
///
/// The order the three steps happen in is asserted where they happen, one layer down. What is left
/// up here is whether the model puts the outcome where the screen reads it.
struct FakeMacJoining: MacJoining {

    let outcome: PairingOutcome
    let known: Set<ServerInstanceId>

    func pair(with link: PairingLink, as device: PairingDevice) async -> PairingOutcome {
        outcome
    }

    func alreadyPaired() async -> Set<ServerInstanceId> {
        known
    }
}
