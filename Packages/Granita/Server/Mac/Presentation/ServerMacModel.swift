import Observation
import ServerApiDomain

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

    public private(set) var connectionAttempts: [ConnectionAttempt] = []

    private let host: any ServerHosting
    private let connectionLog: any ConnectionLog

    public init(host: any ServerHosting, connectionLog: any ConnectionLog) {
        self.host = host
        self.connectionLog = connectionLog
    }

    /// Follows the server for as long as the app is running.
    public func followServer() async {
        for await state in host.run() {
            serverState = state
        }
    }

    /// Follows the connection log for as long as the panel that draws it is on screen. The attempt
    /// worth seeing is usually the one that has not happened yet when it is opened.
    public func followConnections() async {
        for await reading in await connectionLog.attempts() {
            connectionAttempts = reading
        }
    }
}
