import Foundation

import ClientWorktreesDomain

/// How the sidebar was left, without a defaults file.
///
/// A class rather than a struct because the point of this seam is that a change survives being
/// written — a value type would hand the model a copy and every assertion about persistence would
/// pass against nothing.
final class FakeWorktreeListPreferences: WorktreeListPreferences, @unchecked Sendable {

    private let lock = NSLock()
    private var storedMode: WorktreeListMode
    private var storedShowsQuiet: Bool

    init(mode: WorktreeListMode = .groupedByProject, showsQuiet: Bool = false) {
        storedMode = mode
        storedShowsQuiet = showsQuiet
    }

    func mode() -> WorktreeListMode {
        lock.withLock { storedMode }
    }

    func remember(_ mode: WorktreeListMode) {
        lock.withLock { storedMode = mode }
    }

    func showsQuietWorktrees() -> Bool {
        lock.withLock { storedShowsQuiet }
    }

    func rememberShowingQuietWorktrees(_ shows: Bool) {
        lock.withLock { storedShowsQuiet = shows }
    }
}
