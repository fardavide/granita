public protocol ConnectionTimingRecording: Sendable {
    func record(_ event: ConnectionTimingEvent) async
}

public enum ConnectionTimingEvent: Hashable, Sendable {
    case started(ConnectionStage)
    case finished(ConnectionStage, duration: Duration, outcome: ConnectionStageOutcome)
}

public enum ConnectionStage: Hashable, Sendable {
    case localDiscovery
    case tailnetVerification
    case localVerification
}

public enum ConnectionStageOutcome: Hashable, Sendable {
    case succeeded
    case failed
    case cancelled
    case skipped
}
