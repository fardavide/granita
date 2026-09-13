import SwiftUI

import ClientWorktreesDomain

public struct VoiceOverWorktreeReadAnnouncements: WorktreeReadAnnouncing {
    public init() {}

    @MainActor public func announce(_ announcement: WorktreeReadAnnouncement) {
        var sentence = AttributedString(announcement.sentence)
        sentence.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(sentence).post()
    }
}
