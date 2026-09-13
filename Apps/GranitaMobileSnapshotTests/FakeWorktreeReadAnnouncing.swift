import ClientWorktreesDomain

@MainActor
final class FakeWorktreeReadAnnouncing: WorktreeReadAnnouncing {
    private(set) var announcements: [WorktreeReadAnnouncement] = []

    func announce(_ announcement: WorktreeReadAnnouncement) {
        announcements.append(announcement)
    }
}
