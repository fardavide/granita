import ClientViewerDomain

struct FakeMacDiffReadAnnouncing: DiffReadAnnouncing {
    func announce(_ failure: DiffBatchFailure) {}
}
