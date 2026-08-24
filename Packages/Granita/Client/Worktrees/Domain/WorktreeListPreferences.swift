/// The two switches in the sidebar's toolbar menu, kept across launches.
///
/// They are preferences rather than state: design §2 chose a menu over a segmented control precisely
/// because these are set in week one and then forgotten, and a control the reader has to set again
/// every launch is one they would rather not have been offered.
///
/// Synchronous, because both are read while the first listing is being arranged. An asynchronous
/// read would put the list on screen in one arrangement and rearrange it a frame later.
public protocol WorktreeListPreferences: Sendable {

    func mode() -> WorktreeListMode
    func remember(_ mode: WorktreeListMode)

    func showsQuietWorktrees() -> Bool
    func rememberShowingQuietWorktrees(_ shows: Bool)
}
