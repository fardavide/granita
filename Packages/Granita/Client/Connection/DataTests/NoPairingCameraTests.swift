import Testing

import ClientConnectionData
import ClientConnectionDomain
import CorePairingDomain

@Suite("Unavailable pairing camera")
struct NoPairingCameraTests {

    @Test(.timeLimit(.minutes(1)))
    func `given pairing has no camera when authorization and scanning are requested then access stays restricted and no codes arrive`() async {
        // given
        let scenario = Scenario()

        // when
        let initialAccess = scenario.sut.current
        scenario.sut.stop()
        scenario.sut.stop()
        let requestedAccess = await scenario.sut.request()
        var codes: [ScannedCode] = []
        for await code in scenario.sut.start() {
            codes.append(code)
        }
        scenario.sut.stop()
        scenario.sut.stop()

        // then
        #expect(initialAccess == .restricted)
        #expect(requestedAccess == .restricted)
        #expect(codes.isEmpty)
        #expect(scenario.sut.current == .restricted)
    }

    private struct Scenario {

        let sut: any CameraAuthorizing & CodeScanning = NoPairingCamera()
    }
}
