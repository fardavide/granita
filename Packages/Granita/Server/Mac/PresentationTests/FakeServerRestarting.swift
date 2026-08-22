import ServerApiDomain

/// Counts, because the only thing worth asserting about a restart from this side is that the ask
/// reached the seam — what happens after it is `RebindingOnWake`'s and is tested there.
actor FakeServerRestarting: ServerRestarting {

    private var restarts = 0

    func count() -> Int {
        restarts
    }

    func restart() async {
        restarts += 1
    }
}
