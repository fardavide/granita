import AppKit
import Foundation
import SwiftUI

import CoreDiffDomain
import ServerMacUi

/// Granita's Settings window.
///
/// Design §2 gives it five tabs rather than the specification's four, with Advanced **last**. The
/// connection log is not an advanced setting — it is a live view of what is happening to this Mac,
/// the only panel with a reason to be reopened, and the one thing here read under pressure — so it
/// gets its own tab, and Advanced goes last because of what shares it: `Reset All Data`. A panel
/// opened while annoyed should not be one mis-click from the button that unpairs every device.
///
/// The three that are not built yet are not declared. A tab bar with placeholders in it is a worse
/// answer than a tab bar that grows: the order above is what the tabs land into, and Advanced stays
/// last throughout.
///
/// Restoring the last-used tab, and selecting Projects on a first run, land with the tabs that make
/// either question answerable — a remembered selection is a preference for a set of tabs that does
/// not exist yet.
public struct GranitaSettingsScreen: View {

    /// Fixed, not a minimum, and read by the window as well as by the test that asserts it.
    ///
    /// The height comes from Devices: the pairing payload is about 140 bytes once the digest is
    /// percent-encoded, which in byte mode at error correction M is a QR of 49 to 53 modules — at
    /// the 4pt module that scans from arm's length, plus a four-module quiet zone, 236 to 244pt
    /// square. Stacked with the six words, the countdown and two paired devices, that pane needs
    /// 560pt. The window does not resize per tab, because between a 560pt QR pane and a three-row
    /// General pane the jump reads as a glitch.
    public static let windowSize = CGSize(width: 620, height: 560)

    private let model: ServerMacModel

    /// Which project row is highlighted, and which scanned repositories are ticked.
    ///
    /// Held here rather than inside the two views that read them, because a `Ui` view is a
    /// vocabulary of stateless views and these are the states its controls turn on. Kept out of
    /// `ServerMacModel` for the opposite reason: neither outlives the window, and a model that
    /// remembered a highlighted row would be remembering something about a screen.
    @State private var selectedProject: ProjectID?
    @State private var chosenCandidates: Set<String> = []

    public init(model: ServerMacModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(
                    state: model.serverState,
                    servingSince: model.servingSince,
                    loginItem: model.loginItem,
                    // Read and write derived from the same property, so the toggle cannot disagree
                    // with the sentence under it. Registration is asynchronous and can be refused,
                    // so the write is a request rather than an assignment — what the toggle shows
                    // next is whatever the system allowed.
                    opensAtLogin: Binding(
                        get: { model.loginItem == .on },
                        set: { enabled in Task { await model.setLoginItem(enabled: enabled) } }
                    ),
                    onCopyAddress: Self.copy,
                    onRestart: { Task { await model.restartServer() } },
                    onOpenLocalNetworkSettings: { Self.open(Self.localNetworkSettings) },
                    onOpenLoginItems: { Self.open(Self.loginItemsSettings) }
                )
                .task { await model.loadLoginItem() }
            }

            Tab("Projects", systemImage: "folder") {
                ProjectsSettingsView(
                    projects: model.projects,
                    failure: model.projectsFailure,
                    selection: $selectedProject,
                    onSetVisible: { isVisible, id in
                        Task { await model.setProjectVisible(isVisible, id: id) }
                    },
                    onAddRepository: {
                        // Only what the picker returns reaches the model. A cancelled pick is not an
                        // event: nothing happened, and nothing on this tab should move because a
                        // reader changed their mind.
                        guard let folder = Self.pickFolder(
                            prompt: "Add",
                            message: "Choose a git repository to add. It arrives switched off."
                        ) else { return }
                        Task { await model.addProject(atFolder: folder) }
                    },
                    onScanFolder: {
                        // Cleared here rather than when the sheet closes, so a second scan never
                        // opens with the previous one's ticks against a different folder's list.
                        chosenCandidates = []
                        guard let folder = Self.pickFolder(
                            prompt: "Scan",
                            message: "Choose a folder to look for git repositories in. Nothing is added yet."
                        ) else { return }
                        Task { await model.scanForRepositories(under: folder) }
                    },
                    onRemove: { id in Task { await model.removeProject(id: id) } },
                    onLocate: { id in
                        guard let folder = Self.pickFolder(
                            prompt: "Locate",
                            message: "Choose where this repository is now."
                        ) else { return }
                        Task { await model.relocateProject(id: id, to: folder) }
                    }
                )
                // Re-read every time the tab is opened rather than once at launch. A folder can be
                // moved, and a repository can grow a worktree, while Granita is running — and the
                // expensive half of the row is cancelled with this task when the reader leaves.
                .task { await model.loadProjects() }
                .sheet(isPresented: Binding(
                    get: { model.folderScan != nil },
                    set: { if $0 == false { model.dismissFolderScan() } }
                )) {
                    // Read inside the sheet rather than captured beside it, so a scan that finishes
                    // while the sheet is up replaces the spinner with the list it found instead of
                    // presenting a second sheet.
                    if let scan = model.folderScan {
                        AddRepositoriesSheet(
                            scan: scan,
                            chosen: $chosenCandidates,
                            onAdd: { chosen in Task { await model.addScannedProjects(chosen) } },
                            onCancel: { model.dismissFolderScan() }
                        )
                    }
                }
            }

            Tab("Connections", systemImage: "point.3.connected.trianglepath.dotted") {
                // The clock the rows are measured against. A row's elapsed time is a value the view
                // is handed rather than one it derives, which is what lets a baseline photograph
                // it — so something has to move it, and a schedule that re-renders on the minute is
                // both the cheapest thing that can and exactly as often as a row changes: the
                // coarsest unit below an hour is a minute.
                TimelineView(.everyMinute) { clock in
                    ConnectionLogView(attempts: model.connectionAttempts, now: clock.date)
                }
                .task { await model.followConnections() }
            }

            Tab("Advanced", systemImage: "gearshape.2") {
                AdvancedSettingsView(
                    git: model.gitInstallation,
                    dataFolderUrl: model.dataFolderUrl,
                    projectCount: model.storedProjectCount,
                    deviceCount: model.storedDeviceCount,
                    onRevealDataFolder: { Self.reveal(model.dataFolderUrl) },
                    onResetAllData: { Task { await model.resetAllData() } }
                )
                .task {
                    // Both on opening rather than at launch. Running git is a subprocess and the
                    // counts are a disk read, and neither is worth doing for a tab nobody has
                    // looked at — while both are worth re-doing every time this one is, because
                    // git can be installed and projects added while Granita is running.
                    await model.loadGitInstallation()
                    await model.loadStoredCounts()
                }
            }
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
    }

    /// AppKit rather than a protocol with a fake behind it. Both of these are one-line system
    /// gestures with nothing to decide and nothing a test would assert; a seam here would be an
    /// abstraction invented for a future nobody asked for.
    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// A folder, chosen by hand, for the three things on Projects that need one.
    ///
    /// **The activation dance is the same trap `SettingsOpener` exists for, and SPEC §9 names this
    /// half of it too.** An `LSUIElement` app runs as `.accessory`, and an accessory app cannot
    /// bring a panel to the front — the panel would open behind everything, or appear not to open at
    /// all. It costs one line here because the Settings window that raised it has already switched
    /// the app to `.regular`; activating anyway is what makes it true when that stops being so.
    ///
    /// AppKit directly, like the pasteboard and Finder calls above. There is nothing here to decide
    /// and nothing a test would assert: a seam would be an abstraction invented for a future nobody
    /// has asked for.
    private static func pickFolder(prompt: String, message: String) -> URL? {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Finder, with the folder selected rather than opened, which is what "Reveal" means everywhere
    /// else on this machine.
    private static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Privacy & Security › Local Network, and Login Items, addressed directly. Without the first
    /// one an `NWError` code is the whole explanation a person gets for an app that does nothing.
    // Force-unwrapped, and justified: both are literals in this file with no runtime input in
    // them, so the optional can only be nil if the literal beside it is malformed — which is a
    // compile-time editing mistake and not a state to handle.
    private static let localNetworkSettings = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork"
    )!

    private static let loginItemsSettings = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    )!
}
