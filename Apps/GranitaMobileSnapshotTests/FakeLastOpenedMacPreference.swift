import ClientConnectionDomain
import Synchronization

/// Which Mac a launch would resume onto, said by the test rather than by the machine.
///
/// **It is here so that no picture depends on the defaults of whatever is rendering it.** The spine
/// resumes when it is given an empty path, and all but one subject in that suite opens at a push it
/// is photographing — so for those the record must be empty, and for the one that is *about* the
/// resume it must be exactly the Mac the test names.
final class FakeLastOpenedMacPreference: LastOpenedMacPreference {

    private let stored: Mutex<DiscoveredServer?>

    init(opened mac: DiscoveredServer? = nil) {
        stored = Mutex(mac)
    }

    func lastOpenedMac() -> DiscoveredServer? {
        stored.withLock { $0 }
    }

    func remember(_ mac: DiscoveredServer) {
        stored.withLock { $0 = mac }
    }

    func forget() {
        stored.withLock { $0 = nil }
    }
}
