import Foundation
import SwiftUI

import CoreDiffDomain
import ServerMacDomain

/// Projects — the security boundary, and the only tab where a control changes what a phone can read.
///
/// Design §4. **Two verbs, kept apart:** adding a repository puts it in this list, and a switch
/// decides whether the phone can see it. A scan can only ever do the first, which is why its results
/// arrive in a sheet rather than here.
///
/// The trailing figure is drawn in two halves because it is learned at two prices. `4 worktrees` is
/// one git invocation for the whole project; `2 with changes` is one per worktree, measured at 16.7
/// seconds for a single monorepo's sixteen. Davide chose, on 23 August 2026, to fill the second in
/// as it arrives rather than to drop it — so the row is complete a moment after it is drawn, and
/// never blank while it waits.
public struct ProjectsSettingsView: View {

    private let projects: [ManagedProject]
    private let failure: ProjectsFailure?
    private let onSetVisible: (Bool, ProjectID) -> Void
    private let onAddRepository: () -> Void
    private let onScanFolder: () -> Void
    private let onRemove: (ProjectID) -> Void
    private let onLocate: (ProjectID) -> Void

    /// A selection is a view's own state and nothing else's: nothing outside this pane has an
    /// opinion about which row is highlighted, and it does not survive the window closing.
    @State private var selection: ProjectID?

    public init(
        projects: [ManagedProject],
        failure: ProjectsFailure?,
        onSetVisible: @escaping (Bool, ProjectID) -> Void,
        onAddRepository: @escaping () -> Void,
        onScanFolder: @escaping () -> Void,
        onRemove: @escaping (ProjectID) -> Void,
        onLocate: @escaping (ProjectID) -> Void
    ) {
        self.projects = projects
        self.failure = failure
        self.onSetVisible = onSetVisible
        self.onScanFolder = onScanFolder
        self.onAddRepository = onAddRepository
        self.onRemove = onRemove
        self.onLocate = onLocate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if projects.isEmpty {
                empty
            } else {
                list
                bar
            }
            failureAdvice
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Nothing added yet

    /// Both verbs, offered once each. This is the state the app spends its first run in, and until
    /// something is switched on the whole product does nothing at all.
    @ViewBuilder private var empty: some View {
        ContentUnavailableView {
            Label("No projects yet", systemImage: "folder.badge.plus")
        } description: {
            Text("Nothing on this Mac is visible to your phone until you add a repository here and switch it on.")
        } actions: {
            HStack(spacing: 10) {
                Button("Add Repository…", action: onAddRepository)
                    .buttonStyle(.borderedProminent)
                Button("Scan a Folder…", action: onScanFolder)
            }
        }
    }

    // MARK: - The list

    @ViewBuilder private var list: some View {
        List(projects, selection: $selection) { project in
            row(project)
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
    }

    /// Switch, name, path, then what it costs.
    ///
    /// The switch is first because it is the only thing on the row with consequences, and left is
    /// where a Mac reader's eye starts. The path is monospaced and secondary because two projects can
    /// share a name and only the path settles it.
    @ViewBuilder private func row(_ project: ManagedProject) -> some View {
        HStack(spacing: 11) {
            Toggle("Visible to paired devices", isOn: Binding(
                get: { project.isVisible },
                set: { onSetVisible($0, project.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(isOperable(project) == false)
            .help(isOperable(project)
                ? "Let paired devices read this project"
                : "Granita cannot read this folder, so it cannot be switched on")

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: project.name)
                    .foregroundStyle(isOperable(project) ? .primary : .secondary)
                secondLine(project)
            }

            Spacer(minLength: 12)
            trailing(project)
        }
        .padding(.vertical, 2)
    }

    /// The path, or the reason there is nothing behind it with the path still beside the reason.
    ///
    /// The last known path stays on the row through both failures. It is where `Locate…` starts
    /// from, and it is the only thing on a row that says *which* project this is.
    @ViewBuilder private func secondLine(_ project: ManagedProject) -> some View {
        switch project.contents {
        case .worktrees:
            path(project.path, style: .secondary)
        case .folderNotFound:
            HStack(spacing: 4) {
                Label("Folder not found", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                path(project.path, style: .tertiary)
            }
        case .notARepository:
            HStack(spacing: 4) {
                Label("Not a repository", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                path(project.path, style: .tertiary)
            }
        }
    }

    /// Truncated at the **head**, because what identifies a project folder is its last component and
    /// everything in front of it is a reader's own home directory. The tail is what has to survive.
    @ViewBuilder private func path(_ path: String, style: HierarchicalShapeStyle) -> some View {
        Text(verbatim: homeRelative(path))
            .font(.caption)
            .monospaced()
            .foregroundStyle(style)
            .truncationMode(.head)
            .lineLimit(1)
            .textSelection(.enabled)
    }

    @ViewBuilder private func trailing(_ project: ManagedProject) -> some View {
        switch project.contents {
        case .worktrees(let count):
            if project.isVisible {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: "\(count) \(count == 1 ? "worktree" : "worktrees")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    changes(project.worktreesWithChanges)
                }
            } else {
                Text("not visible")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        case .folderNotFound, .notARepository:
            // The one affordance a broken row gets, and the reason its switch is disabled rather
            // than silently flipped off: turning off something a person turned on is a decision the
            // app should not make while they are not looking.
            Button("Locate…") { onLocate(project.id) }
                .controlSize(.small)
        }
    }

    /// The second half of the figure, which arrives after the row it lands in.
    ///
    /// `Checking…` rather than nothing, so the line is the same height before and after: a row that
    /// grows by one line when an answer lands moves every row below it, on a list where a reader is
    /// aiming at a switch.
    @ViewBuilder private func changes(_ withChanges: WorktreesWithChanges) -> some View {
        switch withChanges {
        case .counting:
            Text("checking…")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .counted(0):
            Text("no changes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .counted(let count):
            Text(verbatim: "\(count) with \(count == 1 ? "change" : "changes")")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    // MARK: - The bar under the list

    /// The plus is a menu because there are two ways to add and only one of them is a folder picker.
    /// The minus is the other verb this tab has, and it is not the switch.
    @ViewBuilder private var bar: some View {
        HStack(spacing: 6) {
            Menu {
                Button("Add Repository…", action: onAddRepository)
                Button("Scan a Folder…", action: onScanFolder)
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Add a repository, or scan a folder for them")

            Button {
                if let selection { onRemove(selection) }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(selection == nil)
            // A disabled control that does not say why is a different unanswerable question, and
            // this one has an answer worth one line.
            .help(selection == nil ? "Select a project to remove it" : "Remove the selected project")

            Spacer()
            Text("Only the projects switched on here can be read by a paired device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .controlSize(.small)
    }

    // MARK: - When something did not happen

    /// Our sentence, the system's underneath. Not in the frames, and built anyway: every control on
    /// this tab writes to the store, and a switch that springs back with no explanation is a control
    /// that did nothing.
    @ViewBuilder private var failureAdvice: some View {
        if let failure {
            VStack(alignment: .leading, spacing: 2) {
                Label(failure.sentence, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                if let reason = failure.reason {
                    Text(verbatim: reason)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func isOperable(_ project: ManagedProject) -> Bool {
        if case .worktrees = project.contents { true } else { false }
    }
}
