import ClientConnectionDomain

/// Records what was woken, so a test can assert on packets that were never sent anywhere.
///
/// An actor because the decorators under test wake from a detached task while the test reads the
/// record from another, which is the one thing about waking that is worth holding to its behaviour.
actor FakeMacWaking: MacWaking {

    private(set) var woken: [[HardwareAddress]] = []

    func wake(_ addresses: [HardwareAddress]) async {
        woken.append(addresses)
    }

    /// Every address woken, across every call, which is what most assertions here are about.
    var allWoken: [HardwareAddress] {
        woken.flatMap { $0 }
    }
}
