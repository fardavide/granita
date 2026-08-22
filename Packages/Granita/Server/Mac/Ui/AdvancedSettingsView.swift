import Foundation
import SwiftUI

import ServerMacDomain

/// Advanced — the rows you set once, and the one button you hope never to press.
///
/// Design §7, and it is **last** in the tab bar rather than first. What shares it is `Reset All
/// Data`, so the panel opened while annoyed must not be one mis-click from the button that unpairs
/// every device — which is also why the connection log moved out of here and got a tab.
///
/// **Two of the drawn rows are absent, and neither is an oversight.** The verbose switch and *Open
/// in Console* are controls over a subsystem that emits nothing: Granita has no logging at all
/// today, and a switch that turns on nothing is worse than a switch that is not there. They land
/// with the logging they describe. The lock-file row is absent for the same shape of reason — the
/// lock file itself is not built.
public struct AdvancedSettingsView: View {

    private let git: GitInstallation
    private let dataFolderUrl: URL
    private let projectCount: Int
    private let deviceCount: Int
    private let onRevealDataFolder: () -> Void
    private let onResetAllData: () -> Void

    @State private var isConfirmingReset = false

    public init(
        git: GitInstallation,
        dataFolderUrl: URL,
        projectCount: Int,
        deviceCount: Int,
        onRevealDataFolder: @escaping () -> Void,
        onResetAllData: @escaping () -> Void
    ) {
        self.git = git
        self.dataFolderUrl = dataFolderUrl
        self.projectCount = projectCount
        self.deviceCount = deviceCount
        self.onRevealDataFolder = onRevealDataFolder
        self.onResetAllData = onResetAllData
    }

    public var body: some View {
        Form {
            Section("Diagnostics") {
                LabeledContent("git") { gitRow }
            }

            Section {
                LabeledContent("Data folder") {
                    HStack(spacing: 8) {
                        Text(verbatim: abbreviatedDataFolder)
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

    /// The home directory as a tilde, and no trailing separator.
    ///
    /// The literal path is a reader's own name plus forty characters of nothing they chose, and the
    /// separator is there because the value is a directory URL rather than because anyone wants to
    /// read it.
    private var abbreviatedDataFolder: String {
        var path = dataFolderUrl.path(percentEncoded: false)
        if path.hasSuffix("/") { path.removeLast() }
        let home = NSHomeDirectory()
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
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
