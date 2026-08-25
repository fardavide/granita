import Foundation

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain

/// The read API of one Mac, over a session pinned to that Mac's key.
///
/// Every address here is an opaque identifier the Mac resolves against its own registry of
/// explicitly-enabled projects. Nothing in this file builds a filesystem path, and nothing accepts
/// one — that rule is the security boundary rather than a convention.
///
/// SPEC §8's single-file diff route is deliberately not called: `/diffs` with one identifier is the
/// same answer through the same code, and a second way to ask a question is a second place for it to
/// be answered differently.
public struct HttpGranitaRepository: GranitaRepository {

    private let client: GranitaHttpClient

    public init(macAt baseUrl: URL, token: PairingToken, transport: any HttpTransport) {
        client = GranitaHttpClient(baseUrl: baseUrl, transport: transport, authorization: .bearer(token))
    }

    /// Built from the pairing the handshake came back with.
    ///
    /// The address and the token travel together because they arrived together, and turning a host
    /// and a port into a URL is this layer's job rather than the composition root's — it is the only
    /// layer that knows the scheme is `https`, and the only one with a test that can watch where a
    /// request actually went. The pairing route two files over is addressed the same way and for the
    /// same reasons.
    ///
    /// A host that will not go into a URL addresses nothing rather than trapping, which surfaces as
    /// a Mac that did not answer — the closest true thing this app can say about a name it cannot
    /// dial. **An IPv6 address is not one of those**, and used to be: what a v6 literal costs a URL
    /// is on the address this is built through.
    public init(mac pairing: PairedMac, transport: any HttpTransport) {
        self.init(
            macAt: pairing.address.httpsUrl ?? URL(filePath: "/nowhere"),
            token: pairing.device.token,
            transport: transport
        )
    }

    public func projects() async throws(ApiFailure) -> [Project] {
        try await client.get("/v1/projects", returning: [Project].self)
    }

    public func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        // Omitted rather than sent empty: an empty value asks for the worktrees of a project whose
        // identifier is the empty string, which is a different question with a different answer.
        //
        // `projectID`, not `projectId`. The no-consecutive-uppercase rule governs the identifiers
        // this project defines; a query parameter both halves already agree on is not one of them.
        let query = project.map { [URLQueryItem(name: "projectID", value: $0.rawValue)] } ?? []
        return try await client.get("/v1/worktrees", query: query, returning: [Worktree].self)
    }

    public func update(
        _ worktree: WorktreeID,
        with patch: WorktreePatch
    ) async throws(ApiFailure) -> Worktree {
        try await client.patch(
            "/v1/worktrees/\(worktree.rawValue)",
            body: patch,
            returning: Worktree.self
        )
    }

    public func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        try await client.get("/v1/worktrees/\(worktree.rawValue)/changes", returning: WorktreeChanges.self)
    }

    public func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        try await client.get(
            "/v1/worktrees/\(worktree.rawValue)/diffs",
            query: [
                URLQueryItem(name: "fileIDs", value: files.map(\.rawValue).joined(separator: ",")),
                URLQueryItem(name: "context", value: String(contextLines))
            ],
            returning: [FileDiff].self
        )
    }

    public func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        try await client.get(
            "/v1/worktrees/\(worktree.rawValue)/files/\(file.rawValue)/lines",
            query: [
                URLQueryItem(name: "side", value: side.rawValue),
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "count", value: String(count))
            ],
            returning: FileLines.self
        )
    }

    public func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        try await client.post(
            "/v1/worktrees/\(worktree.rawValue)/files/\(file.rawValue)/viewed",
            body: ViewedRequest(viewed: viewed, contentHash: contentHash)
        )
    }
}
