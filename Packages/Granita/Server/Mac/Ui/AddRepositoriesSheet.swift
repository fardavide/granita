import Foundation
import SwiftUI

import ServerMacDomain

/// What a folder scan found, waiting to be chosen.
///
/// Design §4's central call: **the scan's results never enter the list uninvited.** They stay here
/// until a reader picks, and what this sheet writes is "added, switched off" — the switch in the
/// list is a second, separate act. That is what makes "thirty found, none enabled" read as
/// deliberate rather than as a broken import.
///
/// **There is no Select All**, and its absence is the point: it is the one gesture that would make
/// thirty repositories of private source code addable in a click.
public struct AddRepositoriesSheet: View {

    private let scan: FolderScan
    private let onAdd: ([RepositoryCandidate]) -> Void
    private let onCancel: () -> Void

    /// Which candidates are ticked. A sheet's own state and nothing else's — it exists for as long
    /// as the sheet does, and dismissing without adding is meant to lose it.
    @State private var chosen: Set<String> = []

    public init(
        scan: FolderScan,
        onAdd: @escaping ([RepositoryCandidate]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.scan = scan
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            body(for: scan)
            footer
        }
        .frame(width: 520)
    }

    // MARK: - What the sheet says it did

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add repositories")
                .font(.headline)
            subtitle
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    /// The count and the folder, so the number is the scan's report rather than a surprise. The
    /// sentence after it stays true by construction: repositories already in the list are not
    /// offered, so everything on screen really is unadded.
    @ViewBuilder private var subtitle: some View {
        switch scan {
        case .scanning(let root):
            Text(verbatim: "Looking for git repositories in \(homeRelative(root))…")
        case .found(let root, let candidates) where candidates.isEmpty:
            Text(verbatim: """
                Nothing under \(homeRelative(root)) is a git repository that Granita does not already \
                have.
                """)
        case .found(let root, let candidates):
            Text(verbatim: """
                Found \(candidates.count) git \(candidates.count == 1 ? "repository" : "repositories") \
                in \(homeRelative(root)). None of them are added yet — choose the ones you want.
                """)
        }
    }

    // MARK: - The three bodies

    @ViewBuilder private func body(for scan: FolderScan) -> some View {
        switch scan {
        case .scanning:
            // A tree of a few thousand directories is fast and a home directory is not, and the
            // difference is not something to find out with a frozen sheet.
            centred { ProgressView().controlSize(.small) }
        case .found(_, let candidates) where candidates.isEmpty:
            // Not a state the frames draw, and it has to exist: a reader who scans the wrong folder,
            // or one whose repositories are all added already, otherwise gets a sheet with a
            // disabled button and nothing that says why.
            centred {
                Text("No new repositories")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        case .found(_, let candidates):
            list(candidates)
        }
    }

    @ViewBuilder private func centred(@ViewBuilder _ content: () -> some View) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    @ViewBuilder private func list(_ candidates: [RepositoryCandidate]) -> some View {
        List(candidates) { candidate in
            Toggle(isOn: Binding(
                get: { chosen.contains(candidate.path) },
                set: { isChosen in
                    if isChosen { chosen.insert(candidate.path) } else { chosen.remove(candidate.path) }
                }
            )) {
                HStack(spacing: 10) {
                    Text(verbatim: candidate.name)
                    Spacer(minLength: 12)
                    // The relative path, not the absolute one: the folder is named in the subtitle
                    // above, so repeating it on thirty rows says nothing thirty times. What it does
                    // say is which `swift-nio` this is.
                    Text(verbatim: candidate.relativePath)
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(.tertiary)
                        .truncationMode(.head)
                        .lineLimit(1)
                }
            }
            .toggleStyle(.checkbox)
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(height: 240)
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    // MARK: - The footer, which counts what it will do

    @ViewBuilder private var footer: some View {
        HStack(spacing: 10) {
            note
            Spacer(minLength: 8)
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            confirm
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    /// The explanation while nothing is chosen, which is when it is needed, and the count once
    /// something is, which is the other time there is anything to say.
    @ViewBuilder private var note: some View {
        if case .found(_, let candidates) = scan, candidates.isEmpty == false {
            if chosen.isEmpty {
                Text(
                    """
                    Added repositories start switched off. Nothing becomes visible to a device until \
                    you switch it on.
                    """
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(verbatim: "\(chosen.count) chosen of \(candidates.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The count is in the verb, so the button says what will happen rather than that something
    /// will. Disabled at zero, which is what stops the sheet being dismissed into an ambiguous state
    /// by the return key.
    ///
    /// Absent altogether where there is nothing to add, rather than present and permanently grey:
    /// a button that could never be pressed on this sheet is a control with nothing behind it.
    @ViewBuilder private var confirm: some View {
        if case .found(_, let candidates) = scan, candidates.isEmpty == false {
            Button {
                onAdd(candidates.filter { chosen.contains($0.path) })
            } label: {
                Text(verbatim: chosen.isEmpty
                    ? "Add"
                    : "Add \(chosen.count) \(chosen.count == 1 ? "Repository" : "Repositories")")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(chosen.isEmpty)
        }
    }
}
