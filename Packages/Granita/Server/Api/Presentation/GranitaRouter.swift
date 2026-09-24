import Foundation
import Hummingbird

import CoreApiDomain
import CoreBrandingDomain
import CoreDiagnosticsDomain
import CoreDiffDomain
import CoreReviewDomain
import ServerApiDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

/// Everything the server wires together to answer a request.
public struct ApiDependencies: Sendable {

    /// Everything this Mac can be asked about its own worktrees.
    ///
    /// **The routes hold a reader rather than a registry and a service**, because the merged Mac
    /// app's window reads the same disk through the same type. What is left here is parsing a
    /// request, calling one method, and encoding the answer.
    public let reader: WorktreeReader
    public let store: any Store
    public let pairing: Pairing
    public let failedAttempts: FailedAttempts

    /// Where every refusal goes, so the Advanced panel can say why a phone is not getting in.
    public let connectionLog: any ConnectionLog

    /// Where every request goes, which is a different question and a different reader: the panel
    /// above is fifty coalesced attempts read on screen under pressure, and this is a line per
    /// request in the system log, read after the fact for its order.
    public let diagnostics: any Diagnostics

    public let serverVersion: String

    /// The stable Tailscale endpoint health offers to a phone for later remote reconnection.
    public let tailnetEndpoint: TailnetEndpoint?

    /// The hardware addresses health reports, so a phone can wake this Mac when it next sleeps.
    ///
    /// Read once at composition rather than per request: an interface list is a syscall, health is
    /// the route a browsing phone hits most often, and an address that changed since launch is one
    /// the phone re-reads on its next session anyway.
    public let wakeAddresses: [String]

    /// Whether a request has to prove who it is.
    ///
    /// Off only under `--insecure-http`, which exists so a TLS problem can never leave code
    /// unreviewable. A token over plaintext is a token anyone on the network already has.
    public let requiresAuthentication: Bool

    public init(
        reader: WorktreeReader,
        store: any Store,
        pairing: Pairing,
        failedAttempts: FailedAttempts,
        connectionLog: any ConnectionLog,
        diagnostics: any Diagnostics,
        serverVersion: String,
        wakeAddresses: [String],
        tailnetEndpoint: TailnetEndpoint?,
        requiresAuthentication: Bool
    ) {
        self.reader = reader
        self.store = store
        self.pairing = pairing
        self.failedAttempts = failedAttempts
        self.connectionLog = connectionLog
        self.diagnostics = diagnostics
        self.serverVersion = serverVersion
        self.wakeAddresses = wakeAddresses
        self.tailnetEndpoint = tailnetEndpoint
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

    public static func build(_ dependencies: ApiDependencies) -> Router<GranitaRequestContext> {
        let router = Router(context: GranitaRequestContext.self)

        // On the router rather than on the authenticated group below, because the requests worth
        // reading about are disproportionately the ones that never get that far: a phone that cannot
        // pair is asking `/v1/pair` and being refused.
        router.add(middleware: DiagnosticsMiddleware(diagnostics: dependencies.diagnostics))

        // Unauthenticated, deliberately, along with pairing: a phone that cannot yet prove who it
        // is still has to be able to find out whether it is talking to a Granita of a version it
        // understands.
        router.get("/v1/health") { _, _ in
            HealthResponse(
                serverVersion: dependencies.serverVersion,
                tailnetEndpoint: dependencies.tailnetEndpoint,
                wakeAddresses: dependencies.wakeAddresses
            )
        }

        // Unauthenticated by necessity and therefore rate limited by necessity: this is the one
        // route an attacker on the network may reach, and a two-minute code is short enough to be
        // worth guessing at network speed.
        router.post("/v1/pair") { request, context -> PairResponse in
            let source = context.source
            if await dependencies.failedAttempts.isBlocked(source: source) {
                await dependencies.connectionLog.record(source: source, outcome: .refused(.rateLimited))
                throw ApiError(.rateLimited, message: "too many failed attempts; wait a minute")
            }

            let body = try await decoded(PairRequest.self, from: request, context: context)
            do {
                let paired = try await dependencies.pairing.redeem(
                    code: body.code,
                    deviceName: body.deviceName,
                    platform: body.platform
                )
                await dependencies.failedAttempts.clear(source: source)
                await dependencies.connectionLog.record(
                    source: source,
                    outcome: .paired(device: body.deviceName, id: paired.deviceId)
                )
                return paired
            } catch let refused as PairingRefusal {
                throw await refusal(refused, from: source, dependencies: dependencies)
            }
        }

        let authenticated = router.group().add(middleware: AuthenticationMiddleware(dependencies: dependencies))

        authenticated.get("/v1/projects") { _, _ in
            await dependencies.reader.projects()
        }

        authenticated.get("/v1/worktrees") { request, _ in
            let filter = request.uri.queryParameters["projectID"].map { ProjectID(rawValue: String($0)) }
            return try await answering { try await dependencies.reader.worktrees(inProject: filter) }
        }

        // **It answers about the one worktree it wrote to, and that is the difference between a
        // rename taking a moment and taking minutes.** This used to read `worktrees(inProject: nil)`
        // and pick its own row out of it, which builds a change set — `status`, `diff`, a batched
        // `hash-object` — for every worktree of every enabled project. The phone applies a rename
        // optimistically now, so this reply is a correction rather than the thing the reader is
        // waiting on; it still has to arrive before they have moved on.
        authenticated.patch("/v1/worktrees/:worktreeId") { request, context -> Worktree in
            let id = try worktreeId(from: context)
            let patch = try await decoded(WorktreePatch.self, from: request, context: context)
            return try await answering { try await dependencies.reader.update(id, with: patch) }
        }

        // **The only route that destroys anything**, and the only one that writes to a repository
        // rather than to this Mac's own document. It is `worktree remove --force --force`, so the
        // uncommitted work the rest of this API exists to show is what goes with it — the phone's
        // confirmation is where that is said, and there is nothing further to undo it with here.
        //
        // **A lock does not refuse it, which reverses the call this route shipped with.** That call
        // read a lock as a person at the Mac saying do not remove this. In practice nobody sets one
        // by hand and Claude Code sets one on every worktree it creates, so the effect was a control
        // refused on essentially every row the phone offered it on — which is the outcome forcing was
        // chosen to avoid. The confirmation says the worktree is locked instead.
        //
        // The branch is left alone. What an agent leaves behind is a directory; a branch is cheap
        // and taking it would take unmerged commits with it.
        authenticated.delete("/v1/worktrees/:worktreeId") { _, context -> Response in
            let id = try worktreeId(from: context)
            try await answering { try await dependencies.reader.delete(id) }
            return Response(status: .noContent)
        }

        authenticated.get("/v1/worktrees/:worktreeId/changes") { _, context -> WorktreeChanges in
            let id = try worktreeId(from: context)
            return try await answering { try await dependencies.reader.changes(in: id) }
        }

        authenticated.get("/v1/worktrees/:worktreeId/diffs") { request, context -> [FileDiff] in
            let id = try worktreeId(from: context)
            let requested = (request.uri.queryParameters["fileIDs"] ?? "")
                .split(separator: ",")
                .map { FileID(rawValue: String($0)) }
            return try await answering {
                try await dependencies.reader.diffs(
                    of: requested,
                    in: id,
                    contextLines: contextLines(from: request)
                )
            }
        }

        authenticated.get("/v1/worktrees/:worktreeId/files/:fileId/diff") { request, context -> FileDiff in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            return try await answering {
                try await dependencies.reader.diff(
                    of: file,
                    in: id,
                    contextLines: contextLines(from: request)
                )
            }
        }

        authenticated.get("/v1/worktrees/:worktreeId/files/:fileId/lines") { request, context -> FileLines in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            let side = DiffSide(rawValue: request.uri.queryParameters["side"].map(String.init) ?? "new") ?? .new
            let start = request.uri.queryParameters["start"].flatMap { Int($0) } ?? 1
            let count = request.uri.queryParameters["count"].flatMap { Int($0) } ?? 100
            return try await answering {
                try await dependencies.reader.lines(
                    of: file,
                    in: id,
                    side: side,
                    start: start,
                    count: count
                )
            }
        }

        // **The one route that answers with bytes rather than with JSON**, because its subject is a
        // picture and a picture wrapped in base64 inside a JSON document is a third more wire and a
        // whole decode pass on the phone for nothing.
        //
        // Which sides exist is decided from the file's status on both ends — `ImageSides` is a `Core`
        // function precisely so the phone knows not to ask for the committed side of a file that has
        // just arrived. A phone that asks anyway gets git's own refusal rather than an empty picture.
        authenticated.get("/v1/worktrees/:worktreeId/files/:fileId/image") { request, context -> Response in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            let side = DiffSide(rawValue: request.uri.queryParameters["side"].map(String.init) ?? "new") ?? .new
            let picture = try await answering {
                try await dependencies.reader.image(of: file, in: id, side: side)
            }
            return Response(
                status: .ok,
                headers: [.contentType: picture.format.mediaType],
                body: ResponseBody(byteBuffer: ByteBuffer(bytes: picture.bytes))
            )
        }

        authenticated.post("/v1/worktrees/:worktreeId/files/:fileId/viewed") { request, context -> Response in
            let id = try worktreeId(from: context)
            let file = try fileId(from: context)
            let body = try await decoded(ViewedRequest.self, from: request, context: context)
            try await answering {
                try await dependencies.reader.markViewed(
                    body.viewed,
                    file: file,
                    contentHash: body.contentHash,
                    in: id,
                    at: Date()
                )
            }
            return Response(status: .noContent)
        }

        // MARK: - The review, which lives here and is read from a phone

        authenticated.get("/v1/worktrees/:worktreeId/review") { _, context -> ReviewRequest in
            let id = try worktreeId(from: context)
            return try await answering { ReviewRequest(comments: try await dependencies.reader.review(in: id)) }
        }

        authenticated.put("/v1/worktrees/:worktreeId/review") { request, context -> Response in
            let id = try worktreeId(from: context)
            let body = try await decoded(ReviewRequest.self, from: request, context: context)
            try await answering { try await dependencies.reader.putReview(body.comments, in: id) }
            return Response(status: .noContent)
        }

        authenticated.get("/v1/review-settings") { _, _ -> ReviewSettingsResponse in
            let settings = await dependencies.reader.reviewSettings()
            return ReviewSettingsResponse(
                openingLine: settings.openingLine,
                identifier: settings.identifier
            )
        }

        authenticated.patch("/v1/review-settings") { request, context -> ReviewSettingsResponse in
            let body = try await decoded(
                ReviewSettingsPatchRequest.self,
                from: request,
                context: context
            )
            let updated = try await answering {
                try await dependencies.reader.updateReviewSettings(
                    openingLine: body.openingLine,
                    identifier: body.identifier
                )
            }
            return ReviewSettingsResponse(
                openingLine: updated.openingLine,
                identifier: updated.identifier
            )
        }

        return router
    }

    // MARK: - The boundary

    /// Runs one read of this Mac and puts its refusal on the wire.
    ///
    /// **Every route goes through this, and that is the whole of what the routes now do about
    /// failure.** The reader refuses in this Mac's vocabulary because the window reading the same
    /// disk has no wire to put a code on; here each case becomes the code and the sentence it has
    /// always travelled with, in `ApiError.init(_ refusal:)`.
    /// Untyped in and typed out, which is the one place that trade is right.
    ///
    /// A handler closure is `throws` because that is the shape Hummingbird calls, so a typed
    /// parameter here infers `any Error` at every call site and the annotation costs more than it
    /// buys. **Nothing is lost**: the exhaustiveness that matters is in `ApiError.init(_ refusal:)`,
    /// which the compiler still checks case by case, and this only decides which errors reach it.
    private static func answering<Answer>(
        _ read: () async throws -> Answer
    ) async throws -> Answer {
        do {
            return try await read()
        } catch let refusal as WorktreeReadError {
            throw ApiError(refusal)
        }
    }

    private static func contextLines(from request: Request) -> Int {
        min(50, max(0, request.uri.queryParameters["context"].flatMap { Int($0) } ?? 3))
    }

    private static func worktreeId(from context: GranitaRequestContext) throws -> WorktreeID {
        guard let raw = context.parameters.get("worktreeId") else {
            throw ApiError(.badRequest, message: "no worktree was named")
        }
        return WorktreeID(rawValue: raw)
    }

    private static func fileId(from context: GranitaRequestContext) throws -> FileID {
        guard let raw = context.parameters.get("fileId") else {
            throw ApiError(.badRequest, message: "no file was named")
        }
        return FileID(rawValue: raw)
    }

    private static func decoded<Body: Decodable>(
        _ type: Body.Type,
        from request: Request,
        context: GranitaRequestContext
    ) async throws -> Body {
        do {
            return try await request.decode(as: Body.self, context: context)
        } catch {
            throw ApiError(.badRequest, message: "that request body could not be read")
        }
    }

    /// Records a refused pairing and says what to answer with.
    ///
    /// **The wire cannot tell the two refusals apart and the log must.** An unauthenticated caller
    /// that learns "that was a real code, just late" from "that was never a code" has an oracle for
    /// whether it is guessing in the right shape — so both come back as `pairingExpired`, while the
    /// Advanced panel, whose only reader is the person standing at the Mac, gets the difference.
    private static func refusal(
        _ error: PairingRefusal,
        from source: String,
        dependencies: ApiDependencies
    ) async -> ApiError {
        switch error {
        case .noSuchCode:
            await dependencies.failedAttempts.record(source: source)
            await dependencies.connectionLog.record(source: source, outcome: .refused(.pairingCodeUnknown))
            return ApiError(.pairingExpired, message: "that pairing code has expired or was already used")
        case .codeExpired:
            await dependencies.failedAttempts.record(source: source)
            await dependencies.connectionLog.record(source: source, outcome: .refused(.pairingCodeExpired))
            return ApiError(.pairingExpired, message: "that pairing code has expired or was already used")
        case .notRecordable(let reason):
            // Not the caller's fault and not counted against it: the code was right and this Mac
            // could not write the device down.
            await dependencies.connectionLog.record(
                source: source,
                outcome: .refused(.pairingNotRecordable(reason: reason))
            )
            return ApiError(.gitFailure, message: "could not record the pairing: \(reason)")
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
        context: GranitaRequestContext,
        next: (Request, GranitaRequestContext) async throws -> Response
    ) async throws -> Response {
        let source = context.source

        // A client that speaks a newer contract is refused before anything else looks at the
        // request, because everything after this point assumes it understands what it was sent.
        if let sent = request.headers[.init(Branding.apiVersionHeader)!].flatMap({ Int($0) }),
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
        await dependencies.connectionLog.record(
            source: source,
            outcome: .accepted(device: device.name, id: device.id)
        )
        return try await next(request, context)
    }
}
