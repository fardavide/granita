import Foundation
import SwiftUI

import ServerMacDomain
import ServerStoreDomain

/// Advanced — the rows you set once, and the one button you hope never to press.
///
/// Design §7, and it is **last** in the tab bar rather than first. What shares it is `Reset All
/// Data`, so the panel opened while annoyed must not be one mis-click from the button that unpairs
/// every device — which is also why the connection log moved out of here and got a tab.
///
/// **The verbose switch is here as of 0.0.18**, over a subsystem that emits something. It was held
/// back while Granita wrote no log at all, because a switch that turns on nothing is worse than a
/// switch that is not there.
public struct AdvancedSettingsView: View {

    private let git: GitInstallation
    private let dataFolderUrl: URL
    private let projectCount: Int
    private let deviceCount: Int
    private let isVerboseLogging: Bool
    private let isBlockedByAnotherProcess: Bool
    private let storeLockHolder: StoreLockHolder?
    private let onSetVerboseLogging: (Bool) -> Void
    private let onOpenLogInConsole: () -> Void
    private let onRevealDataFolder: () -> Void
    private let onResetAllData: () -> Void

    @State private var isConfirmingReset = false

    public init(
        git: GitInstallation,
        dataFolderUrl: URL,
        projectCount: Int,
        deviceCount: Int,
        isVerboseLogging: Bool,
        isBlockedByAnotherProcess: Bool,
        storeLockHolder: StoreLockHolder?,
        onSetVerboseLogging: @escaping (Bool) -> Void,
        onOpenLogInConsole: @escaping () -> Void,
        onRevealDataFolder: @escaping () -> Void,
        onResetAllData: @escaping () -> Void
    ) {
        self.git = git
        self.dataFolderUrl = dataFolderUrl
        self.projectCount = projectCount
        self.deviceCount = deviceCount
        self.isVerboseLogging = isVerboseLogging
        self.isBlockedByAnotherProcess = isBlockedByAnotherProcess
        self.storeLockHolder = storeLockHolder
        self.onSetVerboseLogging = onSetVerboseLogging
        self.onOpenLogInConsole = onOpenLogInConsole
        self.onRevealDataFolder = onRevealDataFolder
        self.onResetAllData = onResetAllData
    }

    public var body: some View {
        Form {
            Section {
                // A switch rather than five syslog levels, which design §7 settled: levels are a
                // vocabulary for reading somebody else's logs, and there is one reader here who
                // wants either the normal amount or all of it.
                Toggle("Verbose logging", isOn: Binding(
                    get: { isVerboseLogging },
                    set: { onSetVerboseLogging($0) }
                ))
                .accessibilityIdentifier("granita.advanced.verbose")
                LabeledContent("Log") {
                    // The button matters more than the switch, which design §7 says in as many
                    // words: a level control with no route to the log leaves a person choosing how
                    // much of something they cannot find.
                    Button("Open in Console", action: onOpenLogInConsole)
                        .accessibilityIdentifier("granita.advanced.console")
                }
                LabeledContent("git") { gitRow }
                // Last in the section and drawn only when it is true, because it is the one row on
                // this tab describing a state in which the rest of the app is doing nothing —
                // design §7. A row permanently saying "not blocked" would be reassurance nobody
                // asked for, on the tab with the least room for it.
                if isBlockedByAnotherProcess {
                    LabeledContent("Settings file") { lockRow }
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                // Three sentences, and each is here because leaving it out makes a control lie.
                // The first says what the switch turns on; the second says what it cannot turn
                // off, so nobody leaves it on for a week to catch something already being written;
                // the third says the filter is on the clipboard, because Console opens unfiltered
                // and a reader who is not told to paste has met a button that did nothing.
                Text(
                    """
                    Verbose logging records every request and every git invocation. Refusals and \
                    failures are recorded either way. Opening Console copies a filter for \
                    Granita's log — paste it into Console's search field.
                    """
                )
            }

            Section {
                LabeledContent("Data folder") {
                    HStack(spacing: 8) {
                        Text(verbatim: homeRelative(dataFolderUrl))
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .textSelection(.enabled)
                        Button("Reveal", action: onRevealDataFolder)
                    }
                }
                LabeledContent {
                    // An ordinary button with a red label, which is what the frame draws and what
                    // every destructive row in System Settings does. Not `.borderedProminent`, and
                    // that call is made by reading rather than by looking — a Mac baseline renders
                    // an inactive window, where prominence draws identically to an ordinary button.
                    // A one-way door does not advertise itself as the thing to press.
                    Button { isConfirmingReset = true } label: {
                        Text("Reset All Data…")
                            .foregroundStyle(.red)
                    }
                } label: {
                    // The row above the button counts what exists, which is what makes one button
                    // proportionate to one sentence.
                    Text(verbatim: holdings)
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Resetting forgets every project and every paired device. Each device has to pair again.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset all of Granita's data?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive, action: onResetAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            // Consequences rather than nouns. A reset is precisely why the connection log later
            // says "that token was not issued by this Mac", and this is the one place to say so
            // before it happens.
            Text(verbatim: consequences)
        }
    }

    /// SPEC §9's refusal, read where design §7 puts it.
    ///
    /// The same shape as the git failure above — a warning label with the detail beneath it — since
    /// both say "this part of the Mac is not working and here is the exact thing to look at". The
    /// process is selectable because the next thing a reader does with it is type it somewhere.
    @ViewBuilder private var lockRow: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label("In use by another process", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(verbatim: storeLockHolder?.sentence ?? "The lock file could not be read")
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: 300, alignment: .trailing)
    }

    @ViewBuilder private var gitRow: some View {
        switch git {
        case .checking:
            Text(verbatim: "—")
                .foregroundStyle(.tertiary)
        case .available(let version, let path):
            // Version first and path second: which of the three candidates won is never the
            // question, and whether the one that won works is.
            HStack(spacing: 8) {
                Text(verbatim: version)
                    .foregroundStyle(.secondary)
                Text(verbatim: path)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .truncationMode(.middle)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        case .unavailable(let reason):
            VStack(alignment: .trailing, spacing: 3) {
                Label("Cannot be run", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(verbatim: reason)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: 300, alignment: .trailing)
        }
    }

    private var holdings: String {
        guard projectCount > 0 || deviceCount > 0 else { return "Nothing is stored yet" }
        let projects = counted(projectCount, "project")
        return """
            \(projects.prefix(1).uppercased())\(projects.dropFirst()), \
            \(counted(deviceCount, "paired device"))
            """
    }

    private var consequences: String {
        guard projectCount > 0 || deviceCount > 0 else {
            return "There is nothing stored to forget. This cannot be undone."
        }
        let projects = counted(projectCount, "project")
        return """
            \(projects.prefix(1).uppercased())\(projects.dropFirst()) will have to be added and \
            switched on again, and \(counted(deviceCount, "paired device")) will have to pair \
            again. This cannot be undone.
            """
    }

    /// Spelled out below five, which is where a Mac's own settings panes stop counting in digits
    /// and where this tab will spend its whole life.
    ///
    /// Lower case, because both places this is read put it mid-sentence at least once and only one
    /// of the two positions is a sentence start.
    private func counted(_ count: Int, _ noun: String) -> String {
        let word = switch count {
        case 0: "no"
        case 1: "one"
        case 2: "two"
        case 3: "three"
        case 4: "four"
        default: "\(count)"
        }
        return "\(word) \(noun)\(count == 1 ? "" : "s")"
    }
}
