public protocol WorktreeReadAnnouncing: Sendable {
    @MainActor func announce(_ announcement: WorktreeReadAnnouncement)
}
