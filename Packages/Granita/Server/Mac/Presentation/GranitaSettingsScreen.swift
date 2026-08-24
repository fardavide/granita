import Foundation
import SwiftUI

import CoreDiffDomain
import ServerMacDomain
import ServerMacUi

/// Granita's Settings window.
///
/// Design §2 gives it five tabs rather than the specification's four, with Advanced **last**. The
/// connection log is not an advanced setting — it is a live view of what is happening to this Mac,
/// the only panel with a reason to be reopened, and the one thing here read under pressure — so it
/// gets its own tab, and Advanced goes last because of what shares it: `Reset All Data`. A panel
/// opened while annoyed should not be one mis-click from the button that unpairs every device.
///
/// All five are declared now that Devices exists. Restoring the last-used tab, and selecting
/// Projects on a first run, land with §1 and §2's remaining half — the menu that asks for a
/// particular tab is what makes a remembered selection worth having.
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

    /// Which project row is highlighted.
    ///
    /// The one piece of state this screen still holds, and it holds it because nothing else has an
    /// opinion: a highlight drives no I/O, changes nothing on disk, and dies with the window. What
    /// is *ticked in the scan sheet* looked like the same kind of thing and is not — it decides what
    /// a confirm button will add — so it lives on the model with the scan it belongs to.
    @State private var selectedProject: ProjectID?

    public init(model: ServerMacModel) {
        self.model = model
    }

    public var body: some View {
        // The selection is the model's, not this view's. One control other than the tab bar moves
        // it — a refused row's `Pair…`, which brings the reader to the QR — and inside this window
        // that is a tab switch rather than a settings request: an open window cannot open itself.
        TabView(selection: Binding(
            get: { model.settingsTab },
            set: { model.showSettingsTab($0) }
        )) {
            Tab("General", systemImage: "gearshape", value: SettingsTab.general) {
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
                    onCopyAddress: { _ in Task { await model.copyAddress() } },
                    onRestart: { Task { await model.restartServer() } },
                    onOpenLocalNetworkSettings: { Task { await model.openSystemSettings(.localNetwork) } },
                    onOpenLoginItems: { Task { await model.openSystemSettings(.loginItems) } },
                    onQuit: { Task { await model.quit() } }
                )
                .task { await model.loadLoginItem() }
            }

            Tab("Projects", systemImage: "folder", value: SettingsTab.projects) {
                ProjectsSettingsView(
                    projects: model.projects,
                    failure: model.projectsFailure,
                    selection: $selectedProject,
                    onSetVisible: { isVisible, id in
                        Task { await model.setProjectVisible(isVisible, id: id) }
                    },
                    onAddRepository: { Task { await model.addProjectFromPicker() } },
                    onScanFolder: { Task { await model.scanFolderFromPicker() } },
                    onRemove: { id in Task { await model.removeProject(id: id) } },
                    onLocate: { id in Task { await model.locateProjectFromPicker(id: id) } }
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
                            chosen: Binding(
                                get: { model.chosenCandidatePaths },
                                set: { model.setChosenCandidatePaths($0) }
                            ),
                            onAdd: { chosen in Task { await model.addScannedProjects(chosen) } },
                            onCancel: { model.dismissFolderScan() }
                        )
                    }
                }
            }

            Tab("Devices", systemImage: "iphone", value: SettingsTab.devices) {
                // A second a step, because this pane counts one down. The connection log's minute
                // is the coarsest unit a row there changes on; here the smallest thing on screen is
                // a seconds digit, and a bar that moved once a minute would be a bar that looks
                // stuck while a reader watches their code run out.
                //
                // The schedule says when to redraw; what time it *is* comes from the model, which
                // is the only clock in this app a test can move.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    DevicesSettingsView(
                        devices: model.devices,
                        offer: model.pairingOffer,
                        now: model.currentTime,
                        failure: model.devicesFailure,
                        onNewCode: { Task { await model.offerPairing() } },
                        onRevoke: { id in Task { await model.revokeDevice(id: id) } },
                        onOpenGeneral: { model.showSettingsTab(.general) }
                    )
                }
                .task { await model.loadDevices() }
                // Keyed on the server's state rather than run once, so the pane that says pairing
                // needs the server replaces itself with a working code the moment one binds — which
                // is exactly when a reader is standing here having just pressed Restart.
                .task(id: model.serverState) { await model.offerPairing() }
            }

            Tab("Connections", systemImage: "point.3.connected.trianglepath.dotted", value: SettingsTab.connections) {
                // The clock the rows are measured against. A row's elapsed time is a value the view
                // is handed rather than one it derives, which is what lets a baseline photograph
                // it — so something has to move it, and a schedule that re-renders on the minute is
                // both the cheapest thing that can and exactly as often as a row changes: the
                // coarsest unit below an hour is a minute.
                TimelineView(.everyMinute) { _ in
                    ConnectionLogView(
                        attempts: model.connectionAttempts,
                        now: model.currentTime,
                        onPair: { model.showSettingsTab(.devices) }
                    )
                }
            }

            Tab("Advanced", systemImage: "gearshape.2", value: SettingsTab.advanced) {
                AdvancedSettingsView(
                    git: model.gitInstallation,
                    dataFolderUrl: model.dataFolderUrl,
                    projectCount: model.storedProjectCount,
                    deviceCount: model.storedDeviceCount,
                    isVerboseLogging: model.isVerboseLogging,
                    isBlockedByAnotherProcess: model.isBlockedByAnotherProcess,
                    storeLockHolder: model.storeLockHolder,
                    onSetVerboseLogging: { model.setVerboseLogging($0) },
                    onOpenLogInConsole: { Task { await model.openLogInConsole() } },
                    onRevealDataFolder: { Task { await model.revealDataFolder() } },
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
}
