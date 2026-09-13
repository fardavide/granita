import ClientConnectionDomain

public struct WorktreeLoadingDescription: Hashable, Sendable {

    public let headline: String
    public let sentence: String
    public let isLongWait: Bool

    public init(stage: WorktreeReadStage, macName: String, elapsed: Double) {
        isLongWait = elapsed >= 10
        switch stage {
        case .finding(let routes):
            headline = isLongWait ? "Still finding \(macName)" : "Finding \(macName)"
            sentence = switch routes {
            case .unknown: "Looking for your Mac."
            case .local: "Looking on this network."
            case .tailnet: "Looking over Tailscale. Finding it on this network needs Wi-Fi."
            case .localAndTailnet: "Looking on this network and over Tailscale."
            }
        case .verifying:
            headline = isLongWait ? "Still verifying \(macName)" : "Verifying \(macName)"
            sentence = "Checking it against the key this device pinned when it paired."
        case .reading(let route):
            headline = isLongWait ? "Still reading worktrees" : "Reading worktrees"
            sentence = switch route {
            case .unknown: "Waiting for your Mac’s response."
            case .local: "Connected on this network."
            case .tailnet: "Connected over Tailscale."
            }
        }
    }
}
