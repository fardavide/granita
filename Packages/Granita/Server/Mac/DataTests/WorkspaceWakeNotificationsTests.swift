import AppKit
import Foundation
import Testing

import ServerMacData

/// The one thing that makes a slept laptop reachable again, and it used to be asserted by
/// nothing: it lived in the menu bar app's composition root, which no test can construct.
///
/// It is reachable here because `NSWorkspace.shared.notificationCenter` is an ordinary notification
/// centre that a test may post to — checked rather than assumed, which is what kept this out of the
/// exemption list.
@Suite("Workspace wake notifications", .serialized)
struct WorkspaceWakeNotificationsTests {

    @Test(.timeLimit(.minutes(1)))
    func `given the Mac wakes when observing then the stream yields`() async throws {
        // given
        var wakes = WorkspaceWakeNotifications().wakes().makeAsyncIterator()

        // when — after a turn, so the observation is registered before the notification is posted.
        let posting = Task {
            try? await Task.sleep(for: .milliseconds(50))
            NSWorkspace.shared.notificationCenter.post(
                name: NSWorkspace.didWakeNotification,
                object: nil
            )
        }
        defer { posting.cancel() }

        // then
        #expect(await wakes.next() != nil)
    }
}
