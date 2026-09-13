import ClientViewerDomain

/// Records what the screen said out loud, because *how many times* is half of what the design
/// decides: a file arriving announces nothing and a refused batch announces once.
@MainActor
final class FakeDiffReadAnnouncing: DiffReadAnnouncing {

    private(set) var announced: [DiffBatchFailure] = []

    nonisolated init() {}

    func announce(_ failure: DiffBatchFailure) {
        announced.append(failure)
    }
}
