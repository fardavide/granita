import SwiftUI

import ClientViewerDomain

public struct VoiceOverDiffReadAnnouncements: DiffReadAnnouncing {

    public init() {}

    @MainActor public func announce(_ failure: DiffBatchFailure) {
        AccessibilityNotification.Announcement(Self.spoken(failure)).post()
    }

    /// What VoiceOver is handed, separated from the posting so that both halves are facts rather than
    /// one fact and one unreachable line.
    ///
    /// **Low priority, like the worktree list's own announcements**: this is worth hearing at the end
    /// of what VoiceOver is already saying rather than in the middle of it. The reader is mid-file and
    /// the news is about files they may not have reached.
    static func spoken(_ failure: DiffBatchFailure) -> AttributedString {
        var sentence = AttributedString(failure.announcement)
        sentence.accessibilitySpeechAnnouncementPriority = .low
        return sentence
    }
}
