import SwiftUI

import ClientWorktreesDomain
import CoreApiDomain
import CoreDiffDomain

struct WorktreeRecoveryRow: View {
    let issue: WorktreeScanIssue
    let action: WorktreeScanAction
    let now: Date
    let onRetry: (WorktreeScanTarget) -> Void
    let onPreview: (WorktreeID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(issue.name, systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(explanation)
                .foregroundStyle(.secondary)
            if case .worktree = issue.target {
                Text(issue.projectName)
                    .foregroundStyle(.secondary)
            }
            if case .at(let date) = issue.lastRead {
                Text(WorktreeReadResult.read(at: date, route: .unknown).footer(at: now))
                    .foregroundStyle(.secondary)
            }
            if let status {
                Text(status)
                    .foregroundStyle(.secondary)
            }
            if !action.isBusy {
                ViewThatFits(in: .horizontal) {
                    HStack { actions }
                    VStack(alignment: .leading) { actions }
                }
            }
        }
        .font(.footnote)
        .padding(.vertical, 4)
    }

    @ViewBuilder private var actions: some View {
        Button("Try Again") { onRetry(issue.target) }
            .buttonStyle(.borderless)
        if issue.reason == .staleRegistration, case .worktree(let worktree) = issue.target {
            Button("Repair…") { onPreview(worktree) }
                .buttonStyle(.borderless)
        }
    }

    private var explanation: String {
        switch issue.target {
        case .project:
            issue.reason == .gitTimedOut ? "Git timed out while listing worktrees." : "Git couldn’t list this project’s worktrees."
        case .worktree:
            switch issue.reason {
            case .gitFailure: "Git can’t open this worktree."
            case .gitTimedOut: "Git timed out while scanning this worktree."
            case .staleRegistration: "Git can’t find this worktree’s link."
            }
        }
    }

    private var status: String? {
        switch action {
        case .checking(let target) where target == issue.target: "Checking with Git…"
        case .stillUnavailable(let target) where target == issue.target: "Still unavailable."
        case .repairing(let worktree) where .worktree(worktree) == issue.target: "Backing up stale registrations…"
        case .failed(let target, let failure) where target == issue.target:
            failure.diagnostic ?? "The Mac couldn’t complete that action."
        case .idle, .checking, .stillUnavailable, .confirming, .repairing, .failed: nil
        }
    }
}

public struct WorktreeRepairSheet: View {
    private let preview: WorktreeRepairPreview
    private let macName: String
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    public init(
        preview: WorktreeRepairPreview,
        macName: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.preview = preview
        self.macName = macName
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Granita will move the listed Git registrations in \(preview.projectName) to a backup on \(macName). Working folders and branches are kept.")
                }
                Section("Stale registrations") {
                    ForEach(preview.registrations, id: \.self) { registration in
                        Text(registration)
                            .textSelection(.enabled)
                    }
                }
                DisclosureGroup("Details") {
                    Text("Git checks which registrations are stale.")
                    Text("git worktree prune --dry-run --verbose --expire now")
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Text("The backup keeps each registration’s Git index and history.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button(removalTitle, role: .destructive, action: onConfirm)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Worktree Repair")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    private var removalTitle: String {
        let count = preview.registrations.count
        return count == 1 ? "Back Up Stale Registration" : "Back Up \(count) Stale Registrations"
    }
}
