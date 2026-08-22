import Foundation
import Observation

import ServerApiDomain
import ServerMacDomain

/// What the Mac app knows, in one place.
///
/// One model for the unit rather than one per screen. The menu bar item and the Settings window are
/// two views onto the same running server, and a state object per view splits that server's state
/// across as many objects as there are places it is drawn — which is a slice per view, not a layer.
/// Views stay stateless and are handed values; this is the only thing between them and the
/// protocols the `Domain` declares.
@Observable
public final class ServerMacModel {

    /// Starting rather than stopped, because the app launches the server as it launches itself.
    /// A menu bar item exists only while that is happening, so "not serving" would be a state this
    /// says before it is true.
    public private(set) var serverState: ServerRunState = .starting

    /// When the server last bound, which is not the same as when the app launched — a rebind after
    /// a wake or a Restart moves it, and that is the point. `nil` until something has bound in this
    /// run of the app; General reads it only in the branch that has already established the server
    /// is running.
    public private(set) var servingSince: Date?

    public private(set) var connectionAttempts: [ConnectionAttempt] = []

    /// Off until the system has been asked. General reads it when it opens rather than trusting
    /// this initial value, which is a placeholder and not a claim.
    public private(set) var loginItem: LoginItemState = .off

    private let host: any ServerHosting
    private let restarts: any ServerRestarting
    private let connectionLog: any ConnectionLog
    private let loginItems: any LoginItemRegistry
    private let now: @Sendable () -> Date

    public init(
        host: any ServerHosting,
        restarts: any ServerRestarting,
        connectionLog: any ConnectionLog,
        loginItems: any LoginItemRegistry,
        now: @escaping @Sendable () -> Date
    ) {
        self.host = host
        self.restarts = restarts
        self.connectionLog = connectionLog
        self.loginItems = loginItems
        self.now = now
    }

    /// Follows the server for as long as the app is running.
    public func followServer() async {
        for await state in host.run() {
            // Stamped on the transition rather than on every reading, so a server that stays up
            // keeps saying when it came up. A rebind moves it, which is the whole reason General
            // shows the time at all: it is how "this has been fine all morning" is told apart from
            // "this has just stood itself up again while I was not looking".
            let wasRunning = if case .running = serverState { true } else { false }
            if case .running = state, wasRunning == false {
                servingSince = now()
            }
            serverState = state
        }
    }

    /// Stands the server up again, at the reader's request.
    public func restartServer() async {
        await restarts.restart()
    }

    /// Follows the connection log for as long as the panel that draws it is on screen. The attempt
    /// worth seeing is usually the one that has not happened yet when it is opened.
    public func followConnections() async {
        for await reading in await connectionLog.attempts() {
            connectionAttempts = reading
        }
    }

    /// Asks the system where the login item actually stands, which is the only place that knows.
    public func loadLoginItem() async {
        loginItem = await loginItems.isRegistered() ? .on : .off
    }

    /// A refusal is a third state rather than a thrown error, because the caller is a `Toggle` and
    /// there is nothing for it to do with one — what it needs is to draw itself off and say why.
    public func setLoginItem(enabled: Bool) async {
        do {
            if enabled {
                try await loginItems.register()
            } else {
                try await loginItems.unregister()
            }
            loginItem = enabled ? .on : .off
        } catch {
            switch error {
            case .notApproved: loginItem = .awaitingApproval
            case .refused(let reason): loginItem = .refused(reason: reason)
            }
        }
    }
}
