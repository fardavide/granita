import Foundation

import ClientConnectionDomain
import ClientMacDomain
import CoreDiffDomain

// UserDefaults is thread-safe; its implementation protects the shared preferences storage.
public struct UserDefaultsReaderSelectionMemory: ReaderSelectionMemory, @unchecked Sendable {
    public static let sourceKey = "granita.reader.selection.source"
    public static let instanceKey = "granita.reader.selection.instance"
    public static let nameKey = "granita.reader.selection.name"
    public static let worktreeIdKey = "granita.reader.selection.worktreeId"
    public static let worktreeNameKey = "granita.reader.selection.worktreeName"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func read() -> ReaderSelection {
        guard let kind = defaults.string(forKey: Self.sourceKey),
              kind == "thisMac" || kind == "remote" else {
            return ReaderSelection(source: .thisMac, worktree: .none)
        }
        let source: ReaderSource
        if kind == "remote" {
            guard let instance = defaults.string(forKey: Self.instanceKey),
                  let name = defaults.string(forKey: Self.nameKey),
                  !instance.isEmpty,
                  !name.isEmpty else {
                return ReaderSelection(source: .thisMac, worktree: .none)
            }
            source = .remote(DiscoveredServer(id: BonjourInstanceName(rawValue: instance), name: name))
        } else {
            source = .thisMac
        }

        let worktree: ReaderWorktreeSelection
        if let id = defaults.string(forKey: Self.worktreeIdKey),
           let name = defaults.string(forKey: Self.worktreeNameKey),
           !id.isEmpty, !name.isEmpty {
            worktree = .chosen(WorktreeID(rawValue: id), name: name)
        } else {
            worktree = .none
        }
        return ReaderSelection(source: source, worktree: worktree)
    }

    public func remember(_ selection: ReaderSelection) {
        switch selection.source {
        case .thisMac:
            defaults.set("thisMac", forKey: Self.sourceKey)
            defaults.removeObject(forKey: Self.instanceKey)
            defaults.removeObject(forKey: Self.nameKey)
        case .remote(let server):
            defaults.set("remote", forKey: Self.sourceKey)
            defaults.set(server.id.rawValue, forKey: Self.instanceKey)
            defaults.set(server.name, forKey: Self.nameKey)
        }
        switch selection.worktree {
        case .none:
            defaults.removeObject(forKey: Self.worktreeIdKey)
            defaults.removeObject(forKey: Self.worktreeNameKey)
        case .chosen(let id, let name):
            defaults.set(id.rawValue, forKey: Self.worktreeIdKey)
            defaults.set(name, forKey: Self.worktreeNameKey)
        }
    }
}
