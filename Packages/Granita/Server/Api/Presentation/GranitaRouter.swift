import Foundation
import Hummingbird

import CoreBrandingDomain
import CoreDiffDomain
import ServerApiDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

/// Everything the server wires together to answer a request.
public struct ApiDependencies: Sendable {

    public let registry: WorktreeRegistry
    public let service: WorktreeService
    public let store: any Store
    public let pairing: Pairing
    public let failedAttempts: FailedAttempts

    /// Where every refusal goes, so the Advanced panel can say why a phone is not getting in.
    public let connectionLog: any ConnectionLog

    public let serverVersion: String

    /// Whether a request has to prove who it is.
    ///
    /// Off only under `--insecure-http`, which exists so a TLS problem can never leave code
    /// unreviewable. A token over plaintext is a token anyone on the network already has.
    public let requiresAuthentication: Bool

    public init(
        registry: WorktreeRegistry,
        service: WorktreeService,
        store: any Store,
        pairing: Pairing,
        failedAttempts: FailedAttempts,
        connectionLog: any ConnectionLog,
        serverVersion: String,
        requiresAuthentication: Bool
    ) {
        self.registry = registry
        self.service = service
        self.store = store
        self.pairing = pairing
        self.failedAttempts = failedAttempts
        self.connectionLog = connectionLog
        self.serverVersion = serverVersion
        self.requiresAuthentication = requiresAuthentication
    }
}

/// Builds the HTTP surface.
///
/// Routes live here rather than in the composition root so they can be exercised in-process by the
/// test client — no port bound, no TLS identity, no Bonjour — while the composition root keeps the
/// job of deciding what implementations they run against.
public enum GranitaRouter {

    /// The version of this contract. A client that sends a newer one is refused outright rather
    /// than served something it will misread, because the two apps ship independently and skew is
    /// guaranteed rather than possible.
    public static let apiVersion = 1

    /// SPEC §8's ceiling on one batched request, so a client cannot ask for a hundred diffs and
    /// spawn a hundred git processes.
    private static let maximumBatchedFiles = 20

    /// At most this many git processes at once. The point of batching is to stop a forty-file
    /// worktree being forty-one round trips; it is not to run forty subprocesses.
    private static let concurrentGitProcesses = 4

    public static func build(_ dependencies: ApiDependencies) -> Router<BasicRequestContext> {
        let router = Router()

        // Unauthenticated, deliberately, along with pairing: a phone that cannot yet prove who it
        // is still has to be able to find out whether it is talking to a Granita of a version it
        // understands.
        router.get("/v1/health") { _, _ in
            HealthResponse(serverVersion: dependencies.serverVersion)
        }

        router.post("/v1/pair") { request, context -> PairResponse in
            let body = try await decoded(PairRequest.self, from: request, context: context)
            return try await dependencies.pairing.redeem(
                code: body.code,
                deviceName: body.deviceName,
                platform: body.platform
            )
        }

        let authenticated = router.group().add(middleware: AuthenticationMiddleware(dependencies: dependencies))

        authenticated.get("/v1/projects") { _, _ in
            await dependencies.registry.projects()
        }

        authenticated.get("/v1/worktrees") { request, _ in
            let filter = request.uri.queryParameters["projectID"].map { ProjectID(rawValue: String($0)) }
            return try await dependencies.registry.worktrees(inProject: filter)
        }

        authenticated.patch("/v1/worktrees/:worktreeId") { request, context -> Worktree in
            let id = try worktreeId(from: context)
            let patch = try await decoded(WorktreePatch.self, from: request, context: context)
            _ = try await dependencies.registry.resolve(id)

            do {
                switch patch.alias {
                case .unchanged: break
                case .cleared: try await dependencies.store.setAlias(nil, for: id)
                case .set(let alias): try await dependencies.store.setAlias(alias, for: id)
                }
                if let isPinned = patch.isPinned {
                    try await dependencies.store.setPinned(isPinned, for: id)
                }
            } catch {
                throw ApiError(.badRequest, message: "could not save that: \(error)")
            }

            let worktrees = try await dependencies.registry.worktrees(inProject: nil)
            guard let updated = worktrees.first(where: { $0.id == id }) else {
                throw ApiError(.worktreeGone, message: "that worktree is no longer there")
            }
            return updated
        }

        authenticated.get("/v1/worktrees/:worktreeId/changes") { request, context -> ChangesResponse in
            let id = try worktreeId(from: context)
            let resolved = try await dependencies.registry.resolve(id)
            let changes = try await changeSet(at: resolved.location, dependencies: dependencies)
            return ChangesResponse(
                revision: changes.revision,
                stats: changes.stats,
                files: changes.files,
                isTruncated: changes.isTruncated
            )
        }

        authenticated.get("/v1/worktrees/:worktreeId/diffs") { request, context -> [FileDiff] in
            let id = try worktreeId(from: context)
            let resolved = try await dependencies.registry.resolve(id)
            let lines = contextLines(from: request)

            let requested = (request.uri.queryParameters["fileIDs"] ?? "")
                .split(separator: ",")
                .map { FileID(rawValue: String($0)) }
            guard requested.count <= maximumBatchedFiles else {
                throw ApiError(.tooLarge, message: "at most \(maximumBatchedFiles) files at a time")
            }

            let changes = try await changeSet(at: resolved.location, dependencies: dependencies)
            return try await diffs(
                for: requested,
                in: changes,
                at: resolved.location,
                contextLines: lines,
                dependencies: dependencies
            )
        }

        authenticated.get("/v1/worktrees/:worktreeId/files/:fileId/diff") { request, context -> FileDiff in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            let resolved = try await dependencies.registry.resolve(id)
            let changes = try await changeSet(at: resolved.location, dependencies: dependencies)
            let produced = try await diffs(
                for: [file],
                in: changes,
                at: resolved.location,
                contextLines: contextLines(from: request),
                dependencies: dependencies
            )
            guard let only = produced.first else {
                throw ApiError(.fileGone, message: "that file is not in this worktree's changes")
            }
            return only
        }

        authenticated.get("/v1/worktrees/:worktreeId/files/:fileId/lines") { request, context -> LinesResponse in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            let resolved = try await dependencies.registry.resolve(id)
            let changes = try await changeSet(at: resolved.location, dependencies: dependencies)
            guard let path = changes.paths[file] else {
                throw ApiError(.fileGone, message: "that file is not in this worktree's changes")
            }

            let side = DiffSide(rawValue: request.uri.queryParameters["side"].map(String.init) ?? "new") ?? .new
            // A rename has two paths and the committed side only exists at the old one, so asking
            // for `HEAD:<new path>` fails outright rather than returning nothing.
            let readFrom = side == .old ? (changes.oldPaths[file] ?? path) : path
            let start = request.uri.queryParameters["start"].flatMap { Int($0) } ?? 1
            let count = min(500, request.uri.queryParameters["count"].flatMap { Int($0) } ?? 100)

            do {
                let read = try await dependencies.service.lines(
                    of: readFrom,
                    side: side,
                    start: start,
                    count: count,
                    in: resolved.location
                )
                return LinesResponse(lines: read.lines, eof: read.isAtEnd)
            } catch {
                throw gitFailure(error)
            }
        }

        authenticated.post("/v1/worktrees/:worktreeId/files/:fileId/viewed") { request, context -> Response in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            let body = try await decoded(ViewedRequest.self, from: request, context: context)
            let resolved = try await dependencies.registry.resolve(id)
            let changes = try await changeSet(at: resolved.location, dependencies: dependencies)

            guard let current = changes.files.first(where: { $0.id == file }) else {
                throw ApiError(.fileGone, message: "that file is not in this worktree's changes")
            }
            // Refused rather than applied: marking a version nobody read as read is the one way
            // this feature can actively mislead someone.
            guard current.contentHash == body.contentHash else {
                throw ApiError(.staleContentHash, message: "that file has changed since you read it")
            }

            do {
                try await dependencies.store.setViewed(body.viewed, file: file, contentHash: body.contentHash)
            } catch {
                throw ApiError(.badRequest, message: "could not save that: \(error)")
            }
            return Response(status: .noContent)
        }

        return router
    }

    // MARK: - Shared work

    private static func changeSet(
        at location: RepositoryLocation,
        dependencies: ApiDependencies
    ) async throws -> WorktreeChangeSet {
        do {
            let viewed = await dependencies.store.state().viewed
            return try await dependencies.service.changeSet(in: location, viewed: viewed)
        } catch {
            throw gitFailure(error)
        }
    }

    /// Computes several files' diffs at once, four git processes at a time.
    private static func diffs(
        for requested: [FileID],
        in changes: WorktreeChangeSet,
        at location: RepositoryLocation,
        contextLines: Int,
        dependencies: ApiDependencies
    ) async throws -> [FileDiff] {
        let wanted = changes.files.filter { requested.contains($0.id) }
        var produced: [FileID: FileDiff] = [:]

        try await withThrowingTaskGroup(of: (FileID, FileDiff)?.self) { group in
            var pending = wanted.makeIterator()
            var running = 0

            func addNext() -> Bool {
                guard let file = pending.next(), let path = changes.paths[file.id] else { return false }
                group.addTask {
                    let diff = try await dependencies.service.fileDiff(
                        for: file,
                        at: path,
                        in: location,
                        contextLines: contextLines
                    )
                    return (file.id, diff)
                }
                return true
            }

            while running < concurrentGitProcesses, addNext() { running += 1 }
            while let finished = try await group.next() {
                if let finished { produced[finished.0] = finished.1 }
                _ = addNext()
            }
        }

        // In the order the client asked for, so a prefetch of the next five files arrives in the
        // order it will scroll through them.
        return requested.compactMap { produced[$0] }
    }

    private static func contextLines(from request: Request) -> Int {
        min(50, max(0, request.uri.queryParameters["context"].flatMap { Int($0) } ?? 3))
    }

    private static func worktreeId(from context: BasicRequestContext) throws -> WorktreeID {
        guard let raw = context.parameters.get("worktreeId") else {
            throw ApiError(.badRequest, message: "no worktree was named")
        }
        return WorktreeID(rawValue: raw)
    }

    private static func fileId(from context: BasicRequestContext) throws -> FileID {
        guard let raw = context.parameters.get("fileId") else {
            throw ApiError(.badRequest, message: "no file was named")
        }
        return FileID(rawValue: raw)
    }

    private static func decoded<Body: Decodable>(
        _ type: Body.Type,
        from request: Request,
        context: BasicRequestContext
    ) async throws -> Body {
        do {
            return try await request.decode(as: Body.self, context: context)
        } catch {
            throw ApiError(.badRequest, message: "that request body could not be read")
        }
    }

    /// Which code the phone is shown when git refuses.
    ///
    /// Not private, because the mapping *is* the contract: each of these puts a different screen in
    /// front of a reader, and contriving five separate HTTP failures to exercise five branches
    /// tests the plumbing rather than the mapping.
    static func gitFailure(_ error: any Error) -> ApiError {
        guard let error = error as? GitError else {
            return ApiError(.gitFailure, message: "\(error)")
        }
        switch error {
        case .gitUnavailable(let reason):
            return ApiError(.gitFailure, message: "git could not be run: \(reason)")
        case .workingDirectoryUnreadable:
            return ApiError(.worktreeGone, message: "that worktree's directory is no longer there")
        case .commandFailed(_, let exitCode, let standardError):
            // git's own words, verbatim. Nothing else makes this readable from a phone.
            return ApiError(.gitFailure, message: "git exited \(exitCode): \(standardError)")
        case .terminatedBySignal(_, let signal, let standardError):
            return ApiError(.gitFailure, message: "git died on signal \(signal): \(standardError)")
        case .timedOut:
            return ApiError(.gitFailure, message: "git took too long and was stopped")
        }
    }
}

/// Bearer on every route but health and pairing.
struct AuthenticationMiddleware: RouterMiddleware {

    let dependencies: ApiDependencies

    func handle(
        _ request: Request,
        context: BasicRequestContext,
        next: (Request, BasicRequestContext) async throws -> Response
    ) async throws -> Response {
        let source = request.head.authority ?? "unknown"

        // A client that speaks a newer contract is refused before anything else looks at the
        // request, because everything after this point assumes it understands what it was sent.
        if let sent = request.headers[.init("X-Granita-Api-Version")!].flatMap({ Int($0) }),
           sent > GranitaRouter.apiVersion {
            await dependencies.connectionLog.record(
                source: source,
                outcome: .refused(.unsupportedApiVersion(sent: sent))
            )
            throw ApiError(.unsupportedApiVersion, message: "this Mac serves version \(GranitaRouter.apiVersion)")
        }

        guard dependencies.requiresAuthentication else {
            return try await next(request, context)
        }

        if await dependencies.failedAttempts.isBlocked(source: source) {
            await dependencies.connectionLog.record(source: source, outcome: .refused(.rateLimited))
            throw ApiError(.rateLimited, message: "too many failed attempts; wait a minute")
        }

        let offered = request.headers[.authorization]?
            .split(separator: " ", maxSplits: 1)
            .last
            .map(String.init)

        let devices = await dependencies.store.state().devices
        guard let offered,
              let device = devices.first(where: { TokenHash.matches(TokenHash.of(offered), $0.tokenHash) })
        else {
            await dependencies.failedAttempts.record(source: source)
            await dependencies.connectionLog.record(
                source: source,
                outcome: .refused(offered == nil ? .noToken : .unknownToken)
            )
            throw ApiError(.unauthorized, message: "pair this device first")
        }

        await dependencies.failedAttempts.clear(source: source)
        await dependencies.connectionLog.record(source: source, outcome: .accepted(device: device.name))
        return try await next(request, context)
    }
}
