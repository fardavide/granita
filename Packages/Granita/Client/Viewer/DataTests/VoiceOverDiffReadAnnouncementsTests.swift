import Foundation
import Testing

import ClientConnectionDomain
import ClientViewerDomain

@testable import ClientViewerData

/// What VoiceOver is handed when a batch of diffs is refused.
///
/// **The priority is the half worth asserting.** A refused batch is news the reader could not have
/// caused, and it arrives while they are mid-file — announced at anything above low it would cut
/// across whatever VoiceOver is already reading out, which on this screen is the code.
@Suite("VoiceOver diff read announcements")
struct VoiceOverDiffReadAnnouncementsTests {

    @Test
    func `given a refused batch when it is spoken then it carries the bar's own sentence`() {
        // given
        let failure = DiffBatchFailure(
            failure: .unreachable(diagnostic: "NSURLErrorDomain -1004"),
            files: ["PinnedCertificate.swift", "GranitaRouter.swift"],
            isRetrying: false,
            hasBeenTried: false
        )

        // when
        let spoken = VoiceOverDiffReadAnnouncements.spoken(failure)

        // then — the bar's own words rather than a second spelling of them, and it names the control
        // because a reader who cannot see the bottom of the screen cannot discover it by scrolling.
        #expect(String(spoken.characters) == failure.announcement)
        #expect(String(spoken.characters).hasSuffix("Try Again is at the bottom of the screen."))
    }

    @Test
    func `given a refused batch when it is spoken then it waits its turn`() {
        // given
        let failure = DiffBatchFailure(
            failure: .unauthorized,
            files: ["PinnedCertificate.swift"],
            isRetrying: false,
            hasBeenTried: false
        )

        // when
        let spoken = VoiceOverDiffReadAnnouncements.spoken(failure)

        // then
        #expect(spoken.accessibilitySpeechAnnouncementPriority == .low)
    }
}
