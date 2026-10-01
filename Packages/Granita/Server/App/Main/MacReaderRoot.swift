import SwiftUI

import ClientConnectionData
import ClientConnectionDomain
import ClientConnectionPresentation
import ClientConnectionUi
import ClientMacDomain
import ClientMacPresentation
import ClientSettingsPresentation
import ClientViewerData
import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
import ClientWorktreesData
import ClientWorktreesPresentation

struct MacReaderRoot: View {
    let composition: MacComposition

    var body: some View {
        MacSourceScreen(
            model: composition.remote.model,
            localInstance: composition.remote.localInstance,
            device: composition.remote.device,
            source: Binding(
                get: { composition.readerModel.selection.source },
                set: { composition.readerModel.choose(source: $0) }
            )
        ) { menu, pair in
            MacReaderScreen(
                model: composition.readerModel,
                serverState: composition.model.serverState,
                holder: composition.model.storeLockHolder,
                source: { menu },
                local: { local(menu: menu) },
                remote: { server in remote(server, menu: menu, pair: pair) }
            )
        }
        .environment(\.codeTheme, composition.appearance.codeTheme)
        .environment(\.codeSize, composition.appearance.codeSize)
        .environment(\.readerTextSize, .default)
        .environment(\.sideBySide, SideBySideSetting(
            isOn: composition.appearance.isSideBySide,
            choose: composition.appearance.chooseSideBySide
        ))
    }

    private func local(menu: MacSourceMenuView) -> some View {
        worktrees(
            name: "This Mac",
            repository: composition.localRepository,
            comments: composition.localReviews,
            loadReviewsAtStart: true,
            onPairAgain: { composition.requestSettings(showing: .devices) },
            onOpenSettings: { composition.requestSettings(showing: .review) },
            onOpenProjects: { composition.requestSettings(showing: .projects) },
            menu: menu,
            settings: { EmptyView() }
        )
    }

    private func remote(
        _ server: DiscoveredServer,
        menu: MacSourceMenuView,
        pair: @escaping (DiscoveredServer) -> Void
    ) -> some View {
        let repository = RememberedMacRepository(reading: server, through: composition.remote.rememberedMacs)
        return worktrees(
            name: server.name,
            repository: repository,
            comments: MacReviewCommentStore(
                local: UserDefaultsReviewCommentStore(defaults: composition.defaults), repository: repository
            ),
            loadReviewsAtStart: false,
            onPairAgain: { pair(server) },
            onOpenSettings: nil,
            onOpenProjects: nil,
            menu: menu,
            settings: {
                ReviewSettingsScreen(
                    model: ClientSettingsModel(macName: server.name, isPaired: true, repository: repository),
                    appearance: composition.appearance,
                    appIcon: composition.appIcon,
                    onPair: { pair(server) }
                )
                .frame(minWidth: 400, minHeight: 420)
            }
        )
    }

    private func worktrees<Settings: View>(
        name: String,
        repository: any GranitaRepository,
        comments: any ReviewCommentStore,
        loadReviewsAtStart: Bool,
        onPairAgain: @escaping () -> Void,
        onOpenSettings: (() -> Void)?,
        onOpenProjects: (() -> Void)?,
        menu: MacSourceMenuView,
        @ViewBuilder settings: @escaping () -> Settings
    ) -> some View {
        MacWorktreeScreen(
            model: ClientWorktreesModel(
                macName: name,
                repository: repository,
                preferences: UserDefaultsWorktreeListPreferences(defaults: composition.defaults),
                copyingLogs: composition.copyingLogs,
                announcing: VoiceOverWorktreeReadAnnouncements(),
                now: Date.init
            ),
            selection: Binding(
                get: { composition.readerModel.selection.worktree },
                set: { composition.readerModel.choose(worktree: $0) }
            ),
            onPairAgain: onPairAgain,
            onOpenSettings: onOpenSettings,
            onOpenProjects: onOpenProjects,
            source: { menu },
            settings: settings
        ) { id, worktreeName, projectName, sidebar in
            WorktreeDiffScreen(
                worktreeName: worktreeName,
                model: ClientViewerModel(
                    worktree: id,
                    macName: name,
                    repository: repository,
                    commentStore: comments,
                    pasteboard: SystemReviewPasteboard(),
                    highlighter: composition.highlighter,
                    copyingLogs: composition.copyingLogs,
                    announcing: VoiceOverDiffReadAnnouncements(),
                    onViewedCountChanged: { id, count in sidebar.recordViewedCount(count, on: id) },
                    longWait: DiffFileWait.longWait,
                    loadReviewsAtStart: loadReviewsAtStart
                ),
                onPairAgain: onPairAgain,
                onBackToWorktrees: { composition.readerModel.choose(worktree: .none) }
            )
            .navigationSubtitle("\(projectName) · \(name)")
        }
    }
}
