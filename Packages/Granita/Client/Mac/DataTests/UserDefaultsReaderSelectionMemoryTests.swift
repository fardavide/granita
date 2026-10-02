import Foundation
import Testing

import ClientConnectionDomain
import ClientMacData
import ClientMacDomain
import CoreDiffDomain

@Suite("Remembered Mac reader selection")
struct UserDefaultsReaderSelectionMemoryTests {

    @Test
    func `given no saved selection when the reader opens then this Mac is selected without a worktree`() throws {
        // given
        let scenario = try Scenario()

        // when
        let selection = scenario.sut.read()

        // then
        #expect(selection == ReaderSelection(source: .thisMac, worktree: .none))
    }

    @Test(arguments: [
        ReaderSelection(source: .thisMac, worktree: .none),
        ReaderSelection(
            source: .thisMac,
            worktree: .chosen(WorktreeID(rawValue: "local-worktree-to-restore"), name: "Local review")
        ),
        ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "remote-studio-instance"),
                name: "Remote Studio"
            )),
            worktree: .none
        ),
        ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "remote-laptop-instance"),
                name: "Remote Laptop"
            )),
            worktree: .chosen(WorktreeID(rawValue: "remote-worktree-to-restore"), name: "Remote review")
        )
    ])
    func `given a reader selection when remembered then another memory restores it`(_ selection: ReaderSelection) throws {
        // given
        let scenario = try Scenario()

        // when
        scenario.sut.remember(selection)

        // then
        let restored = UserDefaultsReaderSelectionMemory(defaults: scenario.defaults)
        #expect(restored.read() == selection)
    }

    @Test
    func `given a chosen worktree name when remembered then the captured display name is restored`() throws {
        // given
        let scenario = try Scenario()
        let id = WorktreeID(rawValue: "opaque-worktree-id-unrelated-to-name")
        let selection = ReaderSelection(
            source: .thisMac,
            worktree: .chosen(id, name: "Improve reader navigation")
        )

        // when
        scenario.sut.remember(selection)

        // then
        let restored = UserDefaultsReaderSelectionMemory(defaults: scenario.defaults)
        #expect(restored.read().worktree == .chosen(id, name: "Improve reader navigation"))
    }

    @Test
    func `given a remembered remote worktree when this Mac is remembered without one then stale selection values are removed`() throws {
        // given
        let scenario = try Scenario()
        scenario.sut.remember(ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "previous-remote-instance"),
                name: "Previous Remote"
            )),
            worktree: .chosen(WorktreeID(rawValue: "previous-remote-worktree"), name: "Previous remote review")
        ))
        let selection = ReaderSelection(source: .thisMac, worktree: .none)

        // when
        scenario.sut.remember(selection)

        // then
        #expect(scenario.sut.read() == selection)
        #expect(scenario.defaults.object(forKey: UserDefaultsReaderSelectionMemory.instanceKey) == nil)
        #expect(scenario.defaults.object(forKey: UserDefaultsReaderSelectionMemory.nameKey) == nil)
        #expect(scenario.defaults.object(forKey: UserDefaultsReaderSelectionMemory.worktreeIdKey) == nil)
        #expect(scenario.defaults.object(forKey: UserDefaultsReaderSelectionMemory.worktreeNameKey) == nil)
    }

    @Test(arguments: InvalidWorktreeRecord.allCases)
    func `given an invalid chosen worktree record when read then the selected source is retained without a worktree`(
        _ invalid: InvalidWorktreeRecord
    ) throws {
        // given
        let scenario = try Scenario()
        let source = ReaderSource.remote(DiscoveredServer(
            id: BonjourInstanceName(rawValue: "valid-remote-for-invalid-worktree"),
            name: "Retained Remote"
        ))
        scenario.sut.remember(ReaderSelection(
            source: source,
            worktree: .chosen(WorktreeID(rawValue: "chosen-worktree-before-corruption"), name: "Captured review name")
        ))
        switch invalid {
        case .emptyId:
            scenario.defaults.set("", forKey: UserDefaultsReaderSelectionMemory.worktreeIdKey)
        case .emptyName:
            scenario.defaults.set("", forKey: UserDefaultsReaderSelectionMemory.worktreeNameKey)
        case .missingId:
            scenario.defaults.removeObject(forKey: UserDefaultsReaderSelectionMemory.worktreeIdKey)
        case .missingName:
            scenario.defaults.removeObject(forKey: UserDefaultsReaderSelectionMemory.worktreeNameKey)
        }

        // when
        let restored = scenario.sut.read()

        // then
        #expect(restored == ReaderSelection(source: source, worktree: .none))
    }

    @Test(arguments: [
        UserDefaultsReaderSelectionMemory.instanceKey,
        UserDefaultsReaderSelectionMemory.nameKey
    ])
    func `given an incomplete remote record when read then the remote worktree is discarded`(_ missingKey: String) throws {
        // given
        let scenario = try Scenario()
        scenario.sut.remember(ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "incomplete-remote-instance"),
                name: "Incomplete Remote"
            )),
            worktree: .chosen(WorktreeID(rawValue: "worktree-only-valid-on-remote"), name: "Remote only review")
        ))
        scenario.defaults.removeObject(forKey: missingKey)

        // when
        let restored = scenario.sut.read()

        // then
        #expect(restored == ReaderSelection(source: .thisMac, worktree: .none))
    }

    @Test(arguments: InvalidSourceRecord.allCases)
    func `given an invalid source record when read then its worktree is discarded`(_ invalid: InvalidSourceRecord) throws {
        // given
        let scenario = try Scenario()
        scenario.sut.remember(ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "invalid-remote-instance"),
                name: "Invalid Remote"
            )),
            worktree: .chosen(WorktreeID(rawValue: "worktree-with-no-valid-source"), name: "Invalid source review")
        ))
        switch invalid {
        case .missingSource:
            scenario.defaults.removeObject(forKey: UserDefaultsReaderSelectionMemory.sourceKey)
        case .unknownSource:
            scenario.defaults.set("unrecognized", forKey: UserDefaultsReaderSelectionMemory.sourceKey)
        case .emptyInstance:
            scenario.defaults.set("", forKey: UserDefaultsReaderSelectionMemory.instanceKey)
        case .emptyName:
            scenario.defaults.set("", forKey: UserDefaultsReaderSelectionMemory.nameKey)
        }

        // when
        let restored = scenario.sut.read()

        // then
        #expect(restored == ReaderSelection(source: .thisMac, worktree: .none))
    }

    private struct Scenario {
        let sut: UserDefaultsReaderSelectionMemory
        let defaults: UserDefaults

        init() throws {
            let name = "granita.tests.\(UUID().uuidString)"
            UserDefaults.standard.removePersistentDomain(forName: name)
            defaults = try #require(UserDefaults(suiteName: name))
            sut = UserDefaultsReaderSelectionMemory(defaults: defaults)
        }
    }

    enum InvalidSourceRecord: CaseIterable {
        case missingSource
        case unknownSource
        case emptyInstance
        case emptyName
    }

    enum InvalidWorktreeRecord: CaseIterable {
        case emptyId
        case emptyName
        case missingId
        case missingName
    }
}
