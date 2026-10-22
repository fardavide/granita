import CoreGraphics
import Testing

@testable import ClientViewerUi

@Suite("Hunk frame preference", .serialized)
@MainActor
struct HunkFramesPreferenceTests {

    @Test
    func `given measured hunks when a hunk reports a newer frame then its frame is replaced and other hunks remain`() {
        // given
        var frames = [
            2: CGRect(x: 11, y: 29, width: 180, height: 35),
            7: CGRect(x: 17, y: 101, width: 220, height: 58)
        ]

        // when
        HunkFramesPreference.reduce(value: &frames) {
            [7: CGRect(x: 23, y: 137, width: 240, height: 76)]
        }

        // then
        #expect(frames == [
            2: CGRect(x: 11, y: 29, width: 180, height: 35),
            7: CGRect(x: 23, y: 137, width: 240, height: 76)
        ])
    }
}
