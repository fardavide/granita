import SwiftUI

import ClientMacDomain
import ClientWorktreesUi
import CoreComponentsUi
import CoreDiffDomain

public struct MacWorktreeScreen<Source: View, Opened: View, Settings: View>: View {
    @State private var model: ClientWorktreesModel
    @Binding private var selection: ReaderWorktreeSelection
    private let source: () -> Source
    private let opening: (WorktreeID, String, String, ClientWorktreesModel) -> Opened
    private let onPairAgain: () -> Void
    private let onOpenSettings: (() -> Void)?
    private let settings: () -> Settings
    @State private var isShowingSettings = false
    private let onOpenProjects: (() -> Void)?

    public init(
        model: ClientWorktreesModel,
        selection: Binding<ReaderWorktreeSelection>,
        onPairAgain: @escaping () -> Void,
        onOpenSettings: (() -> Void)?,
        onOpenProjects: (() -> Void)?,
        @ViewBuilder source: @escaping () -> Source,
        @ViewBuilder settings: @escaping () -> Settings,
        @ViewBuilder opening: @escaping (WorktreeID, String, String, ClientWorktreesModel) -> Opened
    ) {
        _model = State(initialValue: model)
        _selection = selection
        self.onPairAgain = onPairAgain
        self.onOpenSettings = onOpenSettings
        self.settings = settings
        self.onOpenProjects = onOpenProjects
        self.source = source
        self.opening = opening
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                source().padding(12)
                Divider()
                WorktreeSidebarScreen(
                    model: model,
                    claimsRowTaps: false,
                    onPairAgain: onPairAgain,
                    onOpenSettings: {
                        if let onOpenSettings {
                            onOpenSettings()
                        } else {
                            isShowingSettings = true
                        }
                    },
                    onOpenProjects: onOpenProjects,
                    selection: Binding(
                        get: {
                            switch selection {
                            case .none: nil
                            case .chosen(let id, _): id
                            }
                        },
                        set: { id in
                            if let id {
                                selection = .chosen(id, name: model.displayName(of: id))
                            } else {
                                selection = .none
                            }
                        }
                    ),
                    opening: opening
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
        } detail: {
            switch MacReaderDetail(selection: selection, sidebar: model.state, worktrees: model.worktrees) {
            case .blank:
                Color.clear
            case .noWorktreeChosen:
                NoWorktreeChosenView()
            case .chosen(let id, let name):
                opening(id, name, model.projectName(of: id), model)
                    .id(id)
            case .gone(let name):
                WorktreeGoneView(name: name)
            }
        }
        .navigationTitle(model.macName)
        .sheet(isPresented: $isShowingSettings) { settings() }
        .focusedSceneValue(\.readerSidebarRefresh) {
            Task { await model.load(trigger: .pullToRefresh) }
        }
    }
}
