import ClientConnectionDomain

actor FakeWorktreeReadProgressRecording {
    private(set) var stages: [WorktreeReadStage]

    init(stages: [WorktreeReadStage] = []) {
        self.stages = stages
    }

    func record(_ stage: WorktreeReadStage) {
        stages.append(stage)
    }
}
