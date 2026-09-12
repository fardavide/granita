public enum DiagnosticCopyState: Sendable, Equatable {
    case ready
    case copying
    case copied
    case failed
}
