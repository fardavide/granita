import Foundation
import SystemConfiguration

/// What this Mac is called.
///
/// **TRAP.** The two obvious answers are both reverse DNS lookups, not names of this machine:
/// `ProcessInfo.processInfo.hostName` and `Host.current().localizedName` ask the network what the
/// address currently resolves to. On Davide's connection that is
/// `customer.mlnnita1.isp.starlink.com`, and a Granita advertising under that name is one nobody
/// recognises in the phone's list of Macs — while the same call from a terminal a minute later
/// answers `macbook-pro.local`, so it looks like it works.
///
/// System Configuration answers from the machine's own preferences instead, and does not vary with
/// what the router says.
public enum MachineName {

    /// The friendly name from System Settings — what the phone shows in its list of Macs.
    public static var computer: String {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? ProcessInfo.processInfo.hostName
    }

    /// The name that resolves to this Mac on the local network — what belongs beside a port.
    public static var localHost: String {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String? else {
            return ProcessInfo.processInfo.hostName
        }
        return "\(name).local"
    }
}
