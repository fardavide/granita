import AppKit
import Foundation
import Synchronization
import Testing

import ServerMacData

@MainActor
@Suite("Reader application lifecycle", .serialized)
struct ReaderApplicationDelegateTests {

    @Test
    func `given the reader is the last window when it closes then Granita keeps running`() {
        // given
        let scenario = Scenario()

        // when
        let shouldTerminate = scenario.sut.applicationShouldTerminateAfterLastWindowClosed(
            NSApplication.shared
        )

        // then
        #expect(shouldTerminate == false)
    }

    @Test(arguments: [true, false])
    func `given the Dock requests the reader when reopening then exactly one reader request is published`(
        hasVisibleWindows: Bool
    ) {
        // given
        let scenario = Scenario()
        let requests = Mutex(0)
        let observation = scenario.notifications.addObserver(
            forName: ReaderApplicationDelegate.readerRequested,
            object: nil,
            queue: nil
        ) { _ in
            requests.withLock { $0 += 1 }
        }
        defer { scenario.notifications.removeObserver(observation) }

        // when
        let shouldHandle = scenario.sut.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: hasVisibleWindows
        )

        // then
        #expect(requests.withLock { $0 } == 1)
        #expect(shouldHandle == false)
    }

    @Test
    func `given the default delegate when reopening then a reader request is published on the default center`() {
        // given
        let scenario = Scenario(usingDefaultNotifications: true)
        let requests = Mutex(0)
        let observation = scenario.notifications.addObserver(
            forName: ReaderApplicationDelegate.readerRequested,
            object: nil,
            queue: nil
        ) { _ in
            requests.withLock { $0 += 1 }
        }
        defer { scenario.notifications.removeObserver(observation) }

        // when
        let shouldHandle = scenario.sut.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false
        )

        // then
        #expect(requests.withLock { $0 } == 1)
        #expect(shouldHandle == false)
    }

    @MainActor
    private struct Scenario {

        let sut: ReaderApplicationDelegate
        let notifications: NotificationCenter

        init(usingDefaultNotifications: Bool = false) {
            if usingDefaultNotifications {
                notifications = .default
                sut = ReaderApplicationDelegate()
            } else {
                notifications = NotificationCenter()
                sut = ReaderApplicationDelegate(notificationCenter: notifications)
            }
        }
    }
}
