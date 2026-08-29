import Foundation
import HummingbirdTesting
import Testing

import ClientConnectionData
import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain
import CoreDiffDomain
import ServerApiPresentation

/// The phone's real client against the Mac's real routes, in one process.
///
/// Every other suite here proves one half. This one is the only place the two meet, and it is the
/// point of putting the wire contract in `Core`: a payload named on both sides cannot be proven by a
/// test that only ever sees one of them. Nothing is faked below the router — the git client runs the
/// real binary, the store writes a real document — and nothing is faked above it either, because the
/// client under test is the one the app ships. The transport is the single substitution, and it is
/// the one thing on the path that is not about the contract.
@Suite("Wire round trip", .serialized)
struct WireRoundTripTests {

    @Test
    func `given a running Mac when the phone reads its health then the two agree on the contract`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }

        // when
        let health = try await scenario.application.test(.router) { client in
            try await HttpServerPairing(macAt: macAddress, transport: RouterTransport.over(client)).health()
        }

        // then
        #expect(health.name == Branding.productName)
        #expect(health.compatibility == .sameContract)
    }

    @Test
    func `given an offered pairing when the phone spends it then it gets a usable token back`() async throws {
        // given — the Mac's own pairing, offered exactly as the Devices tab will offer it.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let offered = await scenario.pairing.invite()

        // when — pair, then immediately use what pairing returned on a route that requires it.
        let worktrees = try await scenario.application.test(.router) { client in
            let paired = try await HttpServerPairing(macAt: macAddress, transport: RouterTransport.over(client))
                .pair(with: offered.code, as: PairingDevice(name: "Davide's iPhone", platform: "iOS"))
            return try await HttpGranitaRepository(
                macAt: macAddress,
                token: paired.token,
                transport: RouterTransport.over(client)
            )
            .worktrees(inProject: nil)
        }

        // then — a token the Mac did not accept would have been `unauthorized` rather than a list.
        #expect(worktrees.isEmpty == false)
    }

    @Test
    func `given the six words instead of the code when the phone spends them then they pair the same slot`() async throws {
        // given — the fallback for when there is no camera, which is a second credential rather than
        // a rendering of the first.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }
        let offered = await scenario.pairing.invite()

        // when
        let paired = try await scenario.application.test(.router) { client in
            try await HttpServerPairing(macAt: macAddress, transport: RouterTransport.over(client))
                .pair(with: offered.spokenCode, as: PairingDevice(name: "Davide's iPad", platform: "iPadOS"))
        }

        // then
        #expect(paired.token.rawValue.isEmpty == false)
        #expect(paired.serverInstanceId.rawValue.isEmpty == false)
    }

    @Test
    func `given a code nobody issued when the phone spends it then it is expired and nothing more`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when
        let failure = try await scenario.application.test(.router) { client in
            await #expect(throws: ApiFailure.pairingExpired) {
                try await HttpServerPairing(macAt: macAddress, transport: RouterTransport.over(client))
                    .pair(with: "invented", as: PairingDevice(name: "Somebody's phone", platform: "iOS"))
            }
        }

        // then — the whole round trip, not just this side's mapping: the Mac answers 401 with a code
        // and the phone turns it into the one state it is allowed to have.
        #expect(failure == .pairingExpired)
    }

    @Test
    func `given no token at all when the phone reads a route then it is turned away`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.application.test(.router) { client in
            await #expect(throws: ApiFailure.unauthorized) {
                try await HttpGranitaRepository(
                    macAt: macAddress,
                    token: PairingToken(rawValue: "not a token this Mac issued"),
                    transport: RouterTransport.over(client)
                )
                .projects()
            }
        }
    }

    // MARK: - The partial update, which is the reason the contract has one definition

    @Test
    func `given an alias set from the phone when it is cleared then the Mac actually drops it`() async throws {
        // given — the absent-versus-null trap, end to end. The phone's encoder writes an explicit
        // null and the Mac's decoder has to read that as "clear it" rather than as "leave it alone".
        // Two implementations of one rule is a coin flip, and the symptom is a name the reader has
        // just deleted quietly coming back.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        let outcome = try await scenario.application.test(.router) { client in
            let repository = HttpGranitaRepository(
                macAt: macAddress,
                token: PairingToken(rawValue: "unused when authentication is off"),
                transport: RouterTransport.over(client)
            )
            let worktree = try #require(try await repository.worktrees(inProject: nil).first)

            let named = try await repository.update(
                worktree.id,
                with: WorktreePatch(alias: .set("the bridge slice"), isPinned: true)
            )
            let pinnedOnly = try await repository.update(
                worktree.id,
                with: WorktreePatch(alias: .unchanged, isPinned: false)
            )
            let cleared = try await repository.update(
                worktree.id,
                with: WorktreePatch(alias: .cleared, isPinned: nil)
            )
            return (named: named, pinnedOnly: pinnedOnly, cleared: cleared)
        }

        // then
        #expect(outcome.named.alias == "the bridge slice")
        #expect(outcome.named.isPinned)
        // Absent means unchanged: pinning must not take the name away with it.
        #expect(outcome.pinnedOnly.alias == "the bridge slice")
        #expect(outcome.pinnedOnly.isPinned == false)
        // Null means clear, and the pin the previous request set has to survive it.
        #expect(outcome.cleared.alias == nil)
        #expect(outcome.cleared.isPinned == false)
    }

    // MARK: - The read routes, over whatever git actually says

    @Test
    func `given a worktree with changes when the phone reads them then the stats and the files arrive`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when
        let read = try await scenario.application.test(.router) { client in
            let repository = HttpGranitaRepository(
                macAt: macAddress,
                token: PairingToken(rawValue: "unused when authentication is off"),
                transport: RouterTransport.over(client)
            )
            let worktree = try #require(try await repository.worktrees(inProject: nil).first)
            let changes = try await repository.changes(in: worktree.id)
            let file = try #require(changes.files.first)
            let diffs = try await repository.diffs(of: [file.id], in: worktree.id, contextLines: 3)
            let lines = try await repository.lines(
                of: file.id,
                in: worktree.id,
                side: .new,
                start: 1,
                count: 5
            )
            return (changes: changes, diffs: diffs, lines: lines)
        }

        // then — the timestamps, the identifiers and the nested diff models all decoded, which is
        // the part a per-side test cannot claim: an ISO 8601 date the phone read as 1970 would have
        // decoded without complaint.
        #expect(read.changes.revision.isEmpty == false)
        #expect(read.changes.stats.filesChanged > 0)
        #expect(read.diffs.count == 1)
        #expect(read.diffs.first?.file.id == read.changes.files.first?.id)
        #expect(read.lines.lines.isEmpty == false)
    }

    // MARK: - The one route that destroys something

    @Test
    func `given a worktree the phone deletes when it is listed again then the Mac agrees it is gone`(
    ) async throws {
        // given — the phone's own client against the Mac's own router, over a repository this test
        // owns. A DELETE with no body in either direction is a shape neither side had before, and
        // the per-side tests each prove their half of it against their own idea of the other.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location, requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when
        let remaining = try await scenario.application.test(.router) { client in
            let mac = HttpGranitaRepository(
                macAt: macAddress,
                token: PairingToken(rawValue: "unused when authentication is off"),
                transport: RouterTransport.over(client)
            )
            let doomed = try #require(try await mac.worktrees(inProject: nil).first { $0.isPrimary == false })
            try await mac.delete(doomed.id)
            return try await mac.worktrees(inProject: nil)
        }

        // then
        #expect(remaining.map(\.isPrimary) == [true])
        #expect(try repository.worktreePaths() == [repository.location.path])
    }

    @Test
    func `given the primary checkout when the phone asks to delete it then the refusal arrives typed`(
    ) async throws {
        // given — a code the phone branches on rather than a status or a git sentence it can only
        // print, which is the whole reason this code was added to the contract.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location, requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when
        let refusal = try await scenario.application.test(.router) { client in
            let mac = HttpGranitaRepository(
                macAt: macAddress,
                token: PairingToken(rawValue: "unused when authentication is off"),
                transport: RouterTransport.over(client)
            )
            let primary = try #require(try await mac.worktrees(inProject: nil).first(where: \.isPrimary))
            do throws(ApiFailure) {
                try await mac.delete(primary.id)
                return ApiFailure?.none
            } catch {
                return error
            }
        }

        // then — and the Mac's own sentence with it, which is the only thing that says *which* of
        // the two refusals it was.
        #expect(refusal == .worktreeNotDeletable(
            message: "that is the project's own checkout rather than one of its worktrees"
        ))
    }

    @Test
    func `given a worktree when the phone reads it then its timestamp is the one the Mac wrote`() async throws {
        // given — both ends now say ISO 8601 rather than inheriting it. A default that moved on one
        // side would show every worktree as modified in 1970, and nothing would fail to decode.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when
        let worktree = try await scenario.application.test(.router) { client in
            try #require(
                try await HttpGranitaRepository(
                    macAt: macAddress,
                    token: PairingToken(rawValue: "unused when authentication is off"),
                    transport: RouterTransport.over(client)
                )
                .worktrees(inProject: nil)
                .first
            )
        }

        // then
        #expect(worktree.lastModified.timeIntervalSince1970 > 1_700_000_000)
    }
}

// MARK: -

/// Where the Mac is, as far as the client is concerned. The transport never dials it — the router is
/// in this process — but the client builds every route against it, so the paths and queries under
/// test are the ones the app would send.
private let macAddress = URL(string: "https://davides-macbook-pro.local:59144")!
