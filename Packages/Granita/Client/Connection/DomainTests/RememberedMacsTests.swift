import Foundation
import Synchronization
import Testing

import CoreDiffDomain
import CorePairingDomain

@testable import ClientConnectionDomain

/// Opening a Mac this phone has paired with before, which until 0.4.1 it could not do at all: the
/// pairing was written down and never read again, so every tap on every Mac asked for a code.
@Suite("Remembered Macs")
struct RememberedMacsTests {

    @Test
    func `given a Mac paired with before when it is read then no code is asked for`() async throws {
        // given — the whole point. The pairing is in the Keychain under the name the browse offered,
        // and that is all it takes: nothing here spends a credential, and nothing asks for one.
        let scenario = Scenario(remembering: [theMacTheReaderTapped.id: aRememberedMac])

        // when
        let worktrees = try await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(worktrees == [aWorktree])
    }

    @Test
    func `given a Mac paired with before when it is read then the session is pinned to the stored key`() async throws {
        // given — a token without the key beside it would have to be spent on whoever answered,
        // which is exactly the trust the pairing bought and would be handed back on every reconnect.
        let scenario = Scenario(remembering: [theMacTheReaderTapped.id: aRememberedMac])

        // when
        _ = try await scenario.sut.worktrees(inProject: nil)

        // then — and the address is the one Bonjour answered with just now, never a stored one: the
        // system chooses the port, so a remembered `host:port` is wrong the first time the Mac
        // restarts.
        #expect(
            scenario.opened == [
                PairedMac(
                    instance: theMacTheReaderTapped.id,
                    name: theMacTheReaderTapped.name,
                    device: aRememberedMac.device,
                    address: whereTheMacIsNow,
                    fingerprint: aRememberedMac.fingerprint
                )
            ]
        )
    }

    @Test
    func `given a Mac never paired with when it is read then it says the phone has to pair`() async {
        // given — reachable when the Mac revoked this phone between the list being drawn and the row
        // being tapped. Said as a refusal because that is what it is, and because the caller that
        // reads it is the one that puts the pairing screens back.
        let scenario = Scenario(remembering: [:])

        // when - then
        await #expect(throws: ApiFailure.unauthorized) {
            try await scenario.sut.worktrees(inProject: nil)
        }
    }

    @Test
    func `given a Mac already reached when it is read again then Bonjour is not asked twice`() async throws {
        // given — the sidebar and an open diff both read, and a lookup per request would put an mDNS
        // round trip in front of every one of them.
        let scenario = Scenario(remembering: [theMacTheReaderTapped.id: aRememberedMac])
        _ = try await scenario.sut.worktrees(inProject: nil)

        // when
        _ = try await scenario.sut.worktrees(inProject: nil)

        // then — one lookup, and one session: a second connection would leak a delegate and a
        // connection pool every time the phone polls.
        #expect(scenario.addresses.lookups == 1)
        #expect(scenario.opened.count == 1)
    }

    // MARK: - Every route, because every route is forwarded by hand

    @Test
    func `given a remembered Mac when each route is read then each arrives as it was asked`() async throws {
        // given — eight methods that each open a connection and pass their arguments on is eight
        // chances to pass the wrong ones, and the compiler catches almost none of it: `start` and
        // `count` are both `Int`, a file and a worktree are both opaque identifiers, and `viewed` is
        // a bare `Bool`. A swap in any of them is a phone marking the wrong file read, or reading a
        // hundred lines from line twenty when it wanted twenty from line one hundred — and one of
        // them now deletes a checkout, where the wrong identifier is the wrong worktree taken off
        // the Mac and nothing to put it back.
        let scenario = Scenario(remembering: [theMacTheReaderTapped.id: aRememberedMac])
        let patch = WorktreePatch(alias: .set("the bridge"), isPinned: true)

        // when
        _ = try await scenario.sut.projects()
        _ = try await scenario.sut.worktrees(inProject: aProject)
        _ = try await scenario.sut.update(aWorktree.id, with: patch)
        try await scenario.sut.delete(aWorktree.id)
        _ = try await scenario.sut.changes(in: aWorktree.id)
        _ = try await scenario.sut.diffs(of: [aFile], in: aWorktree.id, contextLines: 3)
        _ = try await scenario.sut.lines(of: aFile, in: aWorktree.id, side: .old, start: 100, count: 20)
        try await scenario.sut.markViewed(true, file: aFile, contentHash: "8a1c0f2", in: aWorktree.id)

        // then — in order, with every argument where it was put.
        #expect(
            await scenario.mac.asked == [
                .projects,
                .worktrees(inProject: aProject),
                .update(aWorktree.id, patch),
                .delete(aWorktree.id),
                .changes(aWorktree.id),
                .diffs([aFile], aWorktree.id, 3),
                .lines(aFile, aWorktree.id, .old, 100, 20),
                .markViewed(true, aFile, "8a1c0f2", aWorktree.id)
            ]
        )
    }

    @Test
    func `given every route read in turn when they are read then one connection serves them all`() async throws {
        // given — the sidebar reads worktrees, an open diff reads lines and marks files. A connection
        // per call would be a `URLSession`, a delegate and a connection pool per request, and an mDNS
        // lookup in front of each one.
        let scenario = Scenario(remembering: [theMacTheReaderTapped.id: aRememberedMac])

        // when
        _ = try await scenario.sut.projects()
        _ = try await scenario.sut.changes(in: aWorktree.id)
        try await scenario.sut.markViewed(true, file: aFile, contentHash: "8a1c0f2", in: aWorktree.id)

        // then
        #expect(scenario.opened.count == 1)
        #expect(scenario.addresses.lookups == 1)
    }

    @Test(arguments: Route.allCases)
    func `given a Mac that refuses when any route is read then the refusal is what comes back`(
        route: Route
    ) async {
        // given — each of the eight wraps its own call, so each has its own `catch` and its own
        // chance to swallow one. A route that returned an empty answer instead of throwing would be
        // a screen reporting no projects, or no changes, on a Mac that refused to say — which reads
        // as *nothing to review* rather than as a fault, and is the quietest way this can go wrong.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            refusing: .rateLimited
        )

        // when - then
        await #expect(throws: ApiFailure.rateLimited) {
            try await route.read(from: scenario.sut)
        }
    }

    @Test
    func `given a Mac that refuses when a write is sent then the pairing is forgotten too`() async {
        // given — a revoked token refuses everything, not only the read the list happens to make
        // first. A phone that forgot its pairing on a refused read and kept it on a refused rename
        // would recover or not depending on which screen the reader was looking at.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            refusing: .unauthorized
        )

        // when
        _ = try? await scenario.sut.update(aWorktree.id, with: WorktreePatch(alias: .cleared, isPinned: nil))

        // then
        #expect(await scenario.macs.saved.isEmpty)
    }

    // MARK: - What a failure changes about what the phone believes

    @Test
    func `given a Mac that refuses the token when it is read then the pairing is forgotten`() async {
        // given — the Devices tab has a Revoke button, and this is what pressing it looks like from
        // here. Keeping the pairing would leave a row that opens a list which can only fail, with no
        // way back to the two credentials that would fix it.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            refusing: .unauthorized
        )

        // when
        _ = try? await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(await scenario.macs.saved.isEmpty)
    }

    @Test
    func `given a Mac that could not be reached when it is read then where it was is thrown away`() async {
        // given — the one situation that makes a resolved address wrong is the Mac having restarted,
        // slept or moved network, which is what an unreachable read means. Keeping it would be an app
        // that stays broken until it is force quit.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            refusing: .unreachable(diagnostic: "The request timed out.")
        )
        _ = try? await scenario.sut.worktrees(inProject: nil)

        // when
        _ = try? await scenario.sut.worktrees(inProject: nil)

        // then — asked again, rather than answered from a reading that has already been shown wrong.
        #expect(scenario.addresses.lookups == 2)
    }

    @Test
    func `given a Mac that could not be reached when it is read then the pairing survives`() async {
        // given — a Mac that is asleep has revoked nothing. Forgetting here would send the reader
        // through the pairing screens for a machine that will answer perfectly in a minute.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            refusing: .unreachable(diagnostic: "The request timed out.")
        )

        // when
        _ = try? await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(await scenario.macs.saved == [theMacTheReaderTapped.id: aRememberedMac])
    }

    @Test
    func `given a worktree that went away when it is read then nothing about the Mac changes`() async {
        // given — an agent removes one every day, and it says nothing about where the Mac is or
        // whether this phone may still talk to it. The exhaustive switch is what keeps a new refusal
        // from silently joining the two that do mean something.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            refusing: .worktreeGone
        )
        _ = try? await scenario.sut.worktrees(inProject: nil)

        // when
        _ = try? await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(scenario.addresses.lookups == 1)
        #expect(await scenario.macs.saved == [theMacTheReaderTapped.id: aRememberedMac])
    }

    // MARK: - The two things that stand between a tap and a request

    @Test
    func `given a Keychain that refuses when a Mac is read then it is not reported as unpaired`() async {
        // given — `errSecInteractionNotAllowed` is transient far more often than not, so this ends in
        // the sentence with *Try Again* under it. Reported as a refusal it would send the reader to
        // spend a code they did not need to spend, leaving a second device record on the Mac.
        let scenario = Scenario(keychainRefusing: .refused(status: -25308))

        // when - then
        await #expect(
            throws: ApiFailure.unreachable(
                diagnostic: "the Keychain would not hand over this Mac's key (OSStatus -25308)"
            )
        ) {
            try await scenario.sut.worktrees(inProject: nil)
        }
    }

    @Test
    func `given something that is not a pairing stored when a Mac is read then the phone pairs again`() async {
        // given — what 0.4.0's bare tokens look like from here, and anything else a future version
        // writes. There is nothing to retry: the bytes will not become a pairing.
        let scenario = Scenario(keychainRefusing: .unreadable)

        // when - then
        await #expect(throws: ApiFailure.unauthorized) {
            try await scenario.sut.worktrees(inProject: nil)
        }
    }

    @Test
    func `given a Mac that will not resolve when it is read then the system's own words survive`() async {
        // given — the screen writes its own sentence and prints this underneath in small print, so
        // what a resolver said has to arrive intact rather than becoming advice.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            resolving: .failure(.unreachable(diagnostic: "No route to host."))
        )

        // when - then
        await #expect(throws: ApiFailure.unreachable(diagnostic: "No route to host.")) {
            try await scenario.sut.worktrees(inProject: nil)
        }
    }

    @Test
    func `given local network access withheld when a Mac is read then the small print names it`() async {
        // given — the one refusal a reader can fix, and the sidebar's sentence does not offer to fix
        // it. Naming the setting in the diagnostic is the whole of what this layer can do about it;
        // the Mac list is the screen with the Settings button on it.
        let scenario = Scenario(
            remembering: [theMacTheReaderTapped.id: aRememberedMac],
            resolving: .failure(.localNetworkDenied)
        )

        // when - then
        await #expect(
            throws: ApiFailure.unreachable(diagnostic: "iOS is withholding local network access from Granita")
        ) {
            try await scenario.sut.worktrees(inProject: nil)
        }
    }
}

// MARK: -

private struct Scenario {

    let sut: RememberedMacRepository
    let macs: FakeRememberedMacStore
    let addresses: FakeBonjourResolver
    let mac: FakeMacBehindAPairing

    /// Every Mac a session was opened for, which is what the pin, the token and the address are
    /// asserted through: none of the three is readable off a repository once it exists.
    var opened: [PairedMac] { connections.all }

    private let connections: OpenedConnections

    init(
        remembering: [BonjourInstanceName: RememberedMac] = [:],
        keychainRefusing refusal: RememberedMacStoreFailure? = nil,
        resolving: Result<ServerAddress, ServerAddressResolutionFailure> = .success(whereTheMacIsNow),
        refusing readFailure: ApiFailure? = nil
    ) {
        macs = refusal.map(FakeRememberedMacStore.init(refusing:))
            ?? FakeRememberedMacStore(holding: remembering)
        addresses = FakeBonjourResolver(answering: resolving)
        let connections = OpenedConnections()
        self.connections = connections
        // One instance rather than one per connection, so a test can read what reached the Mac
        // without holding the repository the reconnection built. That the reconnection only ever
        // builds *one* is asserted separately, through `opened`.
        let mac = FakeMacBehindAPairing(answering: readFailure)
        self.mac = mac
        sut = RememberedMacRepository(
            reading: theMacTheReaderTapped,
            through: RememberedMacs(
                store: macs,
                addresses: addresses,
                connect: { pairing in
                    connections.opened(pairing)
                    return mac
                }
            )
        )
    }
}

/// Every Mac a session was opened for, in order.
///
/// A class rather than a `Mutex` on the scenario itself: a mutex is non-copyable, so a struct
/// holding one cannot be copied — and a scenario that cannot be copied is one the closure above
/// cannot capture from.
private final class OpenedConnections: Sendable {

    var all: [PairedMac] { macs.withLock { $0 } }

    private let macs = Mutex<[PairedMac]>([])

    func opened(_ mac: PairedMac) {
        macs.withLock { $0.append(mac) }
    }
}

/// A Mac behind a pairing, which records what it was asked rather than what it answered.
///
/// **Every route is recorded because every route is hand-forwarded.** Eight methods that each open a
/// connection and pass their arguments on is eight chances to pass the wrong ones, and the type
/// checker catches almost none of it: `start` and `count` are both `Int`, a file and a worktree are
/// both opaque identifiers, and `viewed` is a bare `Bool`. What a test can see is the request that
/// arrived, so that is what this keeps.
private actor FakeMacBehindAPairing: GranitaRepository {

    private(set) var asked: [MacRequest] = []

    private let answering: ApiFailure?

    init(answering: ApiFailure?) {
        self.answering = answering
    }

    func projects() async throws(ApiFailure) -> [Project] {
        try note(.projects)
        return []
    }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        try note(.worktrees(inProject: project))
        return [aWorktree]
    }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        try note(.update(worktree, patch))
        return aWorktree
    }

    func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        try note(.delete(worktree))
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        try note(.changes(worktree))
        return WorktreeChanges(revision: aWorktree.revision, stats: .zero, files: [], isTruncated: false)
    }

    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        try note(.diffs(files, worktree, contextLines))
        return []
    }

    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        try note(.lines(file, worktree, side, start, count))
        return FileLines(lines: [], eof: false)
    }

    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        try note(.markViewed(viewed, file, contentHash, worktree))
    }

    private func note(_ request: MacRequest) throws(ApiFailure) {
        asked.append(request)
        if let answering { throw answering }
    }
}

/// Every route, as something a test can call without caring what it answers.
///
/// It exists so the eight are covered by one `@Test(arguments:)` rather than by eight near-identical
/// bodies — and so that adding a ninth to `GranitaRepository` is a line here rather than the one
/// unwrapped route nobody noticed.
enum Route: CaseIterable, Sendable {

    case projects
    case worktrees
    case update
    case delete
    case changes
    case lines
    case diffs
    case markViewed

    func read(from repository: RememberedMacRepository) async throws(ApiFailure) {
        switch self {
        case .projects:
            _ = try await repository.projects()
        case .worktrees:
            _ = try await repository.worktrees(inProject: nil)
        case .update:
            _ = try await repository.update(aWorktree.id, with: WorktreePatch(alias: .cleared, isPinned: nil))
        case .delete:
            try await repository.delete(aWorktree.id)
        case .changes:
            _ = try await repository.changes(in: aWorktree.id)
        case .lines:
            _ = try await repository.lines(of: aFile, in: aWorktree.id, side: .old, start: 1, count: 20)
        case .diffs:
            _ = try await repository.diffs(of: [aFile], in: aWorktree.id, contextLines: 3)
        case .markViewed:
            try await repository.markViewed(true, file: aFile, contentHash: "8a1c0f2", in: aWorktree.id)
        }
    }
}

/// One request as it reached the Mac, arguments and all.
private enum MacRequest: Hashable, Sendable {
    case projects
    case worktrees(inProject: ProjectID?)
    case update(WorktreeID, WorktreePatch)
    case delete(WorktreeID)
    case changes(WorktreeID)
    case diffs([FileID], WorktreeID, Int)
    case lines(FileID, WorktreeID, DiffSide, Int, Int)
    case markViewed(Bool, FileID, String, WorktreeID)
}

private let theMacTheReaderTapped = DiscoveredServer(
    id: BonjourInstanceName(rawValue: "Davide's MacBook Pro"),
    name: "Davide's MacBook Pro"
)

private let aRememberedMac = RememberedMac(
    device: PairedDevice(
        token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
        deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
        serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
    ),
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
)

/// Deliberately not a port anything stored: the system picks one per launch, which is the reason a
/// pairing keeps no address at all.
private let whereTheMacIsNow = ServerAddress(host: "davides-macbook-pro.local", port: 61_022)

private let aProject = ProjectID(rawValue: "a1b2c3")

private let aFile = FileID(rawValue: "d4e5f6")

private let aWorktree = Worktree(
    id: WorktreeID(rawValue: "3f9c1a"),
    projectId: ProjectID(rawValue: "a1b2c3"),
    projectName: "Granita",
    branch: "main",
    isPrimary: true,
    isDetached: false,
    isLocked: false,
    hasUnbornHead: false,
    alias: nil,
    suggestedAlias: nil,
    displayName: "main",
    directoryName: "Granita",
    isPinned: false,
    stats: .zero,
    lastModified: Date(timeIntervalSince1970: 1_756_000_000),
    revision: "8a1c0f2"
)
