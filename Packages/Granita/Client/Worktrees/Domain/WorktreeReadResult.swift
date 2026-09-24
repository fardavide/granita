import Foundation

import ClientConnectionDomain

public enum WorktreeReadResult: Hashable, Sendable {
    case notRead
    case read(at: Date, route: WorktreeConnectionRoute)
    case stale(at: Date, route: WorktreeConnectionRoute, failure: ApiFailure)

    public func refreshNotice(at now: Date) -> String {
        switch self {
        case .notRead, .read:
            ""
        case .stale(let at, _, _):
            "Couldn't refresh. These worktrees were read \(WorktreeAge(of: at, at: now).receiptDescription)."
        }
    }

    public func footer(at now: Date) -> String {
        let moment: Date
        let route: WorktreeConnectionRoute
        let isStale: Bool
        switch self {
        case .notRead:
            return ""
        case .read(let at, let connection):
            moment = at
            route = connection
            isStale = false
        case .stale(let at, let connection, _):
            moment = at
            route = connection
            isStale = true
        }
        let age = WorktreeAge(of: moment, at: now).receiptDescription
        if isStale { return "Showing worktrees read \(age)." }
        let connection: String = switch route {
        case .unknown: "."
        // Nothing to name, for the same reason `unknown` names nothing: the other two clauses say
        // which network carried the read, and no network carried this one. Saying "on this Mac"
        // here would also be the second place the window mentions the source, which §8's call 6
        // rejects — the source menu says it once and the title's subtitle carries it after that.
        case .thisMac: "."
        case .local: ", on this network."
        case .tailnet: ", over Tailscale."
        }
        return "Read \(age)\(connection)"
    }
}

private extension WorktreeAge {
    var receiptDescription: String {
        switch self {
        case .underAMinute: "just now"
        case .minutes(let count): count == 1 ? "1 minute ago" : "\(count) minutes ago"
        case .hours(let count): count == 1 ? "1 hour ago" : "\(count) hours ago"
        case .days(let count): count == 1 ? "1 day ago" : "\(count) days ago"
        }
    }
}
