import Synchronization

import ClientConnectionDomain
import CorePairingDomain

/// A Mac that ends the attempt however a test needs it to.
///
/// The order the three steps happen in is asserted where they happen, one layer down in
/// `MacPairingTests`. What is left up here is whether the model puts the outcome where the screen
/// reads it — and, for the two states design §5 draws while a request is in flight, whether it puts
/// anything there at all before the answer arrives.
///
/// **Both answers are configured up front and both can be made to take their time.** The frozen
/// viewfinder and the outcome screen's retry are only on screen while somebody else is thinking, so
/// a fake that answered instantly could not be asked what the reader was looking at meanwhile.
final class FakeMacJoining: MacJoining {

    /// Every credential that was spent. Empty is the assertion that matters twice: when six words
    /// were never sent because the Mac could not be found, and when the Keychain write was retried
    /// on its own.
    var attemptsOffered: [PairingAttempt] { attempts.withLock { $0 } }

    private let answeringPair: PairingOutcome
    private let answeringPairAfter: Duration
    private let answeringWrite: PairingOutcome
    private let answeringWriteAfter: Duration
    private let remembering: Set<BonjourInstanceName>
    private let attempts = Mutex<[PairingAttempt]>([])

    init(
        answeringPair: PairingOutcome,
        answeringPairAfter: Duration,
        answeringWrite: PairingOutcome,
        answeringWriteAfter: Duration,
        remembering: Set<BonjourInstanceName> = []
    ) {
        self.answeringPair = answeringPair
        self.answeringPairAfter = answeringPairAfter
        self.answeringWrite = answeringWrite
        self.answeringWriteAfter = answeringWriteAfter
        self.remembering = remembering
    }

    func pair(
        with attempt: PairingAttempt,
        on mac: DiscoveredServer,
        as device: PairingDevice
    ) async -> PairingOutcome {
        attempts.withLock { $0.append(attempt) }
        // Cancelling is how a test lets go of a Mac it deliberately made slow: the answer it
        // configured still arrives, which is what leaves the model in the state after the wait
        // rather than in no state at all.
        try? await Task.sleep(for: answeringPairAfter)
        return answeringPair
    }

    func saveToken(of pairing: PairedMac) async -> PairingOutcome {
        try? await Task.sleep(for: answeringWriteAfter)
        return answeringWrite
    }

    /// Which Macs the phone can open without pairing, which is what the discovery screen routes a
    /// tap with. Configured, because a row going to the wrong one of two destinations is now the
    /// thing worth asserting.
    func rememberedMacs() async -> Set<BonjourInstanceName> {
        remembering
    }
}
