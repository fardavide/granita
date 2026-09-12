/// A local report that can be collected even when the Mac is unreachable.
public protocol DiagnosticReportProviding: Sendable {
    func report() async -> String
}

public enum DiagnosticCopyFailure: Error, Sendable {
    case unavailable
}

public protocol DiagnosticPasteboard: Sendable {
    func copy(_ text: String) async throws(DiagnosticCopyFailure)
}

public protocol DiagnosticLogsCopying: Sendable {
    func copy(context: DiagnosticContext) async throws(DiagnosticCopyFailure)
}

public enum DiagnosticContext: Hashable, Sendable {
    case discovery(DiscoveryState)
    case pairing(PairingState)
    case worktrees(ApiFailure?)
    case diff(ApiFailure?)

    fileprivate var summary: String {
        switch self {
        case .discovery(let state):
            let screen = "Current screen: discovery"
            switch state {
            case .idle: return screen + "\nState: idle"
            case .searching: return screen + "\nState: searching"
            case .found(let servers) where servers.isEmpty:
                return screen + "\nFailure: nothingFound"
            case .found: return screen + "\nState: found"
            case .localNetworkDenied: return screen + "\nFailure: localNetworkDenied"
            case .failed: return screen + "\nFailure: failed"
            }
        case .pairing(let state):
            let screen = "Current screen: pairing"
            switch state {
            case .notStarted: return screen + "\nState: notStarted"
            case .waitingForCameraAccess: return screen + "\nState: waitingForCameraAccess"
            case .cameraRefused: return screen + "\nFailure: cameraRefused"
            case .cameraRestricted: return screen + "\nFailure: cameraRestricted"
            case .looking: return screen + "\nState: looking"
            case .sawSomethingElse: return screen + "\nState: sawSomethingElse"
            case .spending: return screen + "\nState: spending"
            case .savingToken: return screen + "\nState: savingToken"
            case .notReached(let failure):
                switch failure {
                case .unreachable: return screen + "\nFailure: unreachable"
                case .localNetworkDenied: return screen + "\nFailure: localNetworkDenied"
                }
            case .finished(let outcome):
                switch outcome {
                case .paired: return screen + "\nState: paired"
                case .refused(let failure): return screen + "\nFailure: " + failure.safeCode
                case .wrongContract(let compatibility):
                    let failure = screen + "\nFailure: wrongContract\nCompatibility: "
                    switch compatibility {
                    case .sameContract: return failure + "sameContract"
                    case .macIsBehind(let serving):
                        return failure + "macIsBehind\nServing API version: \(serving)"
                    case .phoneIsBehind(let serving):
                        return failure + "phoneIsBehind\nServing API version: \(serving)"
                    }
                case .tokenNotStored(_, let storeFailure):
                    let failure = screen + "\nFailure: tokenNotStored"
                    switch storeFailure {
                    case .refused(let status): return failure + "\nKeychain status: \(status)"
                    case .unreadable: return failure + "\nStore failure: unreadable"
                    }
                case .neverAnswered(let stall):
                    let failure = screen + "\nFailure: neverAnswered\nPairing step: "
                    switch stall {
                    case .readingTheContract: return failure + "readingTheContract"
                    case .spendingTheCode: return failure + "spendingTheCode"
                    case .writingTheKey: return failure + "writingTheKey"
                    }
                }
            }
        case .worktrees(let failure):
            switch failure {
            case .none: return "Current screen: worktrees"
            case .some(let failure): return "Current screen: worktrees\nFailure: " + failure.safeCode
            }
        case .diff(let failure):
            switch failure {
            case .none: return "Current screen: diff"
            case .some(let failure): return "Current screen: diff\nFailure: " + failure.safeCode
            }
        }
    }
}

public struct CopyDiagnosticLogs: DiagnosticLogsCopying {

    private let report: any DiagnosticReportProviding
    private let pasteboard: any DiagnosticPasteboard

    public init(report: any DiagnosticReportProviding, pasteboard: any DiagnosticPasteboard) {
        self.report = report
        self.pasteboard = pasteboard
    }

    public func copy(context: DiagnosticContext) async throws(DiagnosticCopyFailure) {
        let text = await report.report() + "\n\n" + context.summary
        try await pasteboard.copy(text)
    }
}

private extension ApiFailure {

    var safeCode: String {
        switch self {
        case .unauthorized: "unauthorized"
        case .pairingExpired: "pairingExpired"
        case .rateLimited: "rateLimited"
        case .projectNotVisible: "projectNotVisible"
        case .worktreeGone: "worktreeGone"
        case .worktreeNotDeletable: "worktreeNotDeletable"
        case .fileGone: "fileGone"
        case .staleContentHash: "staleContentHash"
        case .gitFailure: "gitFailure"
        case .tooLarge: "tooLarge"
        case .badRequest: "badRequest"
        case .unsupportedApiVersion: "unsupportedApiVersion"
        case .requestNotBuildable: "requestNotBuildable"
        case .unreachable: "unreachable"
        case .cancelled: "cancelled"
        case .notUnderstood: "notUnderstood"
        }
    }
}
