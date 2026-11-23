import Foundation

import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain

actor WorktreeRepairCoordinator {
    private let registry: WorktreeRegistry
    private let service: WorktreeService
    private let backups: any WorktreeRegistrationBackingUp
    private let clock = ContinuousClock()
    private var previews: [ProjectID: PendingPreview] = [:]
    private var applying: Set<ProjectID> = []

    init(registry: WorktreeRegistry, service: WorktreeService, backups: any WorktreeRegistrationBackingUp) {
        self.registry = registry
        self.service = service
        self.backups = backups
    }

    func preview(for worktree: WorktreeID) async throws(WorktreeReadError) -> WorktreeRepairPreview {
        let project = try await prunableProject(for: worktree)
        guard !applying.contains(project.id) else { throw .repairUnavailable }
        let location = RepositoryLocation(path: project.path)
        let registrations: [WorktreeRegistrationName]
        let commonDirectory: RepositoryLocation
        do {
            commonDirectory = try await service.commonGitDirectory(in: location)
            registrations = try await service.staleRegistrations(in: location)
        } catch {
            throw WorktreeReadError(error)
        }
        guard !Task.isCancelled else { throw .cancelled }
        guard !registrations.isEmpty, !applying.contains(project.id) else { throw .repairUnavailable }
        previews = previews.filter { $0.value.expiresAt > clock.now }
        let preview = WorktreeRepairPreview(
            approval: WorktreeRepairApproval(id: UUID()), projectName: project.name,
            registrations: registrations.map(\.rawValue)
        )
        previews[project.id] = PendingPreview(
            preview: preview, project: project, worktree: worktree, commonDirectory: commonDirectory,
            registrations: registrations, expiresAt: clock.now.advanced(by: .seconds(300))
        )
        return preview
    }

    func approve(_ approval: WorktreeRepairApproval) async throws(WorktreeReadError) -> WorktreeSnapshot {
        guard let pending = previews.values.first(where: { $0.preview.approval == approval }),
              pending.expiresAt > clock.now else { throw .repairPreviewChanged }
        let projectID = pending.project.id
        previews.removeValue(forKey: projectID)
        guard applying.insert(projectID).inserted else { throw .repairUnavailable }
        defer { applying.remove(projectID) }

        let current: StoredProject
        do {
            current = try await prunableProject(for: pending.worktree)
        } catch .notFound {
            throw .repairPreviewChanged
        }
        guard current == pending.project else { throw .repairPreviewChanged }
        guard !Task.isCancelled else { throw .cancelled }
        let location = RepositoryLocation(path: current.path)
        let commonDirectory: RepositoryLocation
        do {
            commonDirectory = try await service.commonGitDirectory(in: location)
            try await service.verifyStaleRegistrations(in: location, matching: pending.registrations)
        } catch {
            throw WorktreeReadError(error)
        }
        guard commonDirectory.path.utf8.elementsEqual(pending.commonDirectory.path.utf8) else {
            throw .repairPreviewChanged
        }
        guard !Task.isCancelled else { throw .cancelled }
        do {
            try backups.backUp(pending.registrations, in: commonDirectory)
        } catch {
            throw WorktreeReadError(error)
        }
        do {
            return try await registry.retry(.project(projectID))
        } catch {
            throw WorktreeReadError(error)
        }
    }

    private func prunableProject(for worktree: WorktreeID) async throws(WorktreeReadError) -> StoredProject {
        do {
            return try await registry.prunableProject(for: worktree)
        } catch {
            throw WorktreeReadError(error)
        }
    }

    private struct PendingPreview {
        let preview: WorktreeRepairPreview
        let project: StoredProject
        let worktree: WorktreeID
        let commonDirectory: RepositoryLocation
        let registrations: [WorktreeRegistrationName]
        let expiresAt: ContinuousClock.Instant
    }
}

private extension WorktreeReadError {
    init(_ error: WorktreePruneError) {
        self = switch error {
        case .previewChanged: .repairPreviewChanged
        case .unavailable: .repairUnavailable
        case .git(let cause): .git(cause)
        }
    }
}
