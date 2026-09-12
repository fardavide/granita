import Synchronization

import ClientConnectionData
import CorePairingDomain

final class FakeHttpTransportFactory: Sendable {
    var createdPins: [SpkiFingerprint] { pins.withLock { $0 } }

    private let pins = Mutex<[SpkiFingerprint]>([])
    private let answer: any HttpTransport

    init(answer: any HttpTransport) { self.answer = answer }

    func transport(pinnedTo fingerprint: SpkiFingerprint) -> any HttpTransport {
        pins.withLock { $0.append(fingerprint) }
        return answer
    }
}
