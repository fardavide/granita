import Foundation

import CoreDiffDomain

struct WorktreeObservationSchedule {
    private var pending: [WorktreeID: Duration] = [:]
    private var lastStarted: [WorktreeID: Duration] = [:]
    private var reconciliation: Deadline = .none
    private var lastReconciliation: Deadline = .none
    private var refreshing: Set<WorktreeID> = []
    private var isReconciling = false

    init() {}

    var nextDeadline: Deadline {
        guard isReconciling == false else { return .none }
        if case .at = reconciliation { return refreshing.isEmpty ? reconciliation : .none }
        if let elapsed = pending.filter({ refreshing.contains($0.key) == false }).values.min() { return .at(elapsed) }
        return .none
    }

    mutating func invalidate(_ reaction: WorktreeObservationReaction, at elapsed: Duration) {
        switch reaction {
        case .refresh(let worktrees):
            for worktree in worktrees where pending[worktree] == nil {
                var deadline = elapsed + .milliseconds(400)
                if let previous = lastStarted[worktree] {
                    deadline = max(deadline, previous + .seconds(2))
                }
                if case .at(let previous) = lastReconciliation {
                    deadline = max(deadline, previous + .seconds(2))
                }
                pending[worktree] = deadline
            }
        case .reconcile:
            if case .none = reconciliation {
                var deadline = elapsed + .milliseconds(400)
                if let previous = lastStarted.values.max() {
                    deadline = max(deadline, previous + .seconds(2))
                }
                if case .at(let previous) = lastReconciliation {
                    deadline = max(deadline, previous + .seconds(2))
                }
                reconciliation = .at(deadline)
            }
        case .ignore:
            break
        }
    }

    mutating func takeDue(at elapsed: Duration) -> WorktreeObservationReaction {
        guard isReconciling == false else { return .ignore }
        if case .at(let deadline) = reconciliation {
            guard deadline <= elapsed, refreshing.isEmpty else { return .ignore }
            didStartReconciliation(at: elapsed)
            return .reconcile
        }
        let ready = Set(pending.filter { $0.value <= elapsed && refreshing.contains($0.key) == false }.keys)
        for worktree in ready {
            pending.removeValue(forKey: worktree)
            lastStarted[worktree] = elapsed
        }
        refreshing.formUnion(ready)
        return ready.isEmpty ? .ignore : .refresh(ready)
    }

    mutating func didFinishRefresh(in worktrees: Set<WorktreeID>) {
        refreshing.subtract(worktrees)
    }

    mutating func didStartReconciliation(at elapsed: Duration) {
        isReconciling = true
        reconciliation = .none
        lastReconciliation = .at(elapsed)
        lastStarted = [:]
        pending = [:]
    }

    mutating func didFinishReconciliation() {
        isReconciling = false
    }

    enum Deadline: Equatable {
        case none
        case at(Duration)
    }
}
