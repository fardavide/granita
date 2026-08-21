import Network

import ClientConnectionDomain

/// Decides what a dead browser means, and how soon to put another in its place.
///
/// A refused local network permission reaches the app as one of two DNS codes, and only one of them
/// says so on its own. `PolicyDenied` is what the first browser an app creates reports while it
/// waits, and it means what it says. `DefunctConnection` only means the connection to mDNSResponder
/// is gone — which is what a refusal looks like to a browser created after one, and equally what
/// every browser sees when the process is resumed after being suspended in the background. Reading
/// a single one as a refusal put "Local network access is off" in front of Davide on a device where
/// it was on, and left it there, because the stream ended with it.
///
/// So it is counted instead. A browser that dies this way over and over was refused; one that dies
/// once and is replaced by a browser that reaches `ready` was suspended.
struct BrowserRestartPolicy {

    private static let policyDenied: DNSServiceErrorType = -65570
    private static let defunctConnection: DNSServiceErrorType = -65569
    /// Deaths in a row before a defunct connection is called a refusal. A refused browser dies as
    /// fast as it can be made, so three of them cost the reader about two seconds of "looking for
    /// your Mac" — cheaper than the alternative, which is accusing them of a setting they did not
    /// change.
    private static let deathsBeforeRefusal = 3
    private static let delayBeforeReplacement = Duration.seconds(1)
    /// Once a refusal is the diagnosis, replacements exist only to notice the permission being
    /// granted, so they can be far apart.
    private static let delayAfterRefusal = Duration.seconds(5)

    private var consecutiveDeaths = 0

    /// What to report for a browser that is alive but cannot proceed. Nothing is replaced and
    /// nothing is counted: it recovers on its own.
    static func stateWhileWaiting(on error: NWError) -> DiscoveryState {
        guard case .dns(let code) = error, code == policyDenied else {
            return .failed(error.localizedDescription)
        }
        return .localNetworkDenied
    }

    mutating func recordReady() {
        consecutiveDeaths = 0
    }

    mutating func restart(after error: NWError) -> BrowserRestart {
        consecutiveDeaths += 1
        guard case .dns(let code) = error else {
            return BrowserRestart(
                report: .failed(error.localizedDescription),
                delay: Self.delayBeforeReplacement
            )
        }
        return switch code {
        case Self.policyDenied:
            BrowserRestart(report: .localNetworkDenied, delay: Self.delayAfterRefusal)
        case Self.defunctConnection where consecutiveDeaths >= Self.deathsBeforeRefusal:
            BrowserRestart(report: .localNetworkDenied, delay: Self.delayAfterRefusal)
        case Self.defunctConnection:
            BrowserRestart(report: nil, delay: Self.delayBeforeReplacement)
        default:
            BrowserRestart(
                report: .failed(error.localizedDescription),
                delay: Self.delayBeforeReplacement
            )
        }
    }
}

// MARK: -

/// What to do about a browser that has died.
struct BrowserRestart: Equatable {

    /// What to tell the reader, or nothing when this death says nothing yet — every return from the
    /// background kills a browser, and a screen that flashed a refusal each time would be lying.
    let report: DiscoveryState?
    /// How long to wait before putting a new browser in its place.
    let delay: Duration
}
