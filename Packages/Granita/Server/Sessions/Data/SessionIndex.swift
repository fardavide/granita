import Foundation

/// One transcript, reduced to the three things a worktree's name needs.
struct IndexedSession: Hashable, Sendable {
    let workingDirectory: String
    let branch: String?
    let label: String?
    let modifiedAt: Date
}

/// A worktree, as far as matching is concerned.
struct MatchableWorktree: Hashable, Sendable {
    let path: String
    let branch: String?
}

enum SessionMatching {

    /// Names every worktree from the sessions that ran in it.
    ///
    /// Decided over the whole set at once, because each session belongs to **one** worktree — the
    /// closest one containing it. Asking per worktree cannot get this right: every worktree an agent
    /// creates lives under the checkout it branched from, so the outer one contains all of them and
    /// would take the name of whatever was last done in any of them.
    ///
    /// Three rules, each because the obvious version is wrong:
    ///
    /// * **Containment, not equality** — an agent started in a subdirectory records that
    ///   subdirectory, and that is the common case rather than the exception.
    /// * **Containment stops at a separator**, or `/repo/slice` claims `/repo/slice-two`.
    /// * **Branch first, then recency** — one directory used across two branches is exactly where
    ///   the newest session is the wrong one.
    static func labels(
        for worktrees: [MatchableWorktree],
        among sessions: [IndexedSession]
    ) -> [String: String] {
        var byWorktree: [String: [IndexedSession]] = [:]
        for session in sessions {
            let owner = worktrees
                .filter { contains($0.path, session.workingDirectory) }
                .max { $0.path.count < $1.path.count }
            guard let owner else { continue }
            byWorktree[owner.path, default: []].append(session)
        }

        var labels: [String: String] = [:]
        for worktree in worktrees {
            let candidates = byWorktree[worktree.path] ?? []
            let onThisBranch = worktree.branch.map { branch in
                candidates.filter { $0.branch == branch }
            } ?? []
            let considered = onThisBranch.isEmpty ? candidates : onThisBranch
            let best = considered
                .filter { $0.label != nil }
                .max { $0.modifiedAt < $1.modifiedAt }
            if let label = best?.label {
                labels[worktree.path] = label
            }
        }
        return labels
    }

    /// Whether `directory` is the worktree itself or something inside it.
    private static func contains(_ worktree: String, _ directory: String) -> Bool {
        directory == worktree || directory.hasPrefix(worktree.hasSuffix("/") ? worktree : worktree + "/")
    }
}

/// The agent's own transcripts, read for the names they suggest.
///
/// Best effort throughout, and never in the way of a request: a worktree with no session is an
/// ordinary worktree, and this whole feature failing means worktrees are named after their branches
/// instead. Everything expensive about it is avoided rather than optimised — the head and tail of
/// each file rather than the file, and a cache keyed on what would have to change for a re-read to
/// say anything new.
public actor SessionIndex {

    /// SPEC §7's chunk size, at each end.
    private static let chunkBytes = 64 * 1024

    private let rootUrl: URL
    private var cache: [URL: CacheEntry] = [:]
    private var sessions: [IndexedSession] = []

    public init(rootUrl: URL) {
        self.rootUrl = rootUrl
    }

    /// `CLAUDE_CONFIG_DIR` when it is set, else `~/.claude`.
    public static func defaultRootUrl() -> URL {
        if let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], configured.isEmpty == false {
            return URL(filePath: configured)
        }
        return URL(filePath: NSHomeDirectory()).appending(path: ".claude", directoryHint: .isDirectory)
    }

    /// Re-reads whatever changed. A missing directory is silence, not an error: plenty of Macs have
    /// never run the agent.
    public func refresh() {
        let projects = rootUrl.appending(path: "projects", directoryHint: .isDirectory)
        guard let directories = try? FileManager.default.contentsOfDirectory(
            at: projects,
            includingPropertiesForKeys: nil
        ) else {
            sessions = []
            return
        }

        var found: [IndexedSession] = []
        var refreshed: [URL: CacheEntry] = [:]
        for directory in directories {
            // Exactly one level down. Below a session lie its subagents' own transcripts, which
            // share its working directory and open with a brief nobody typed — pulling those in
            // buries every real session under a label it did not choose.
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            )) ?? []

            for file in files where file.pathExtension == "jsonl" {
                guard let values = try? file.resourceValues(
                    forKeys: [.contentModificationDateKey, .fileSizeKey]
                ),
                    let modifiedAt = values.contentModificationDate,
                    let size = values.fileSize
                else { continue }

                if let cached = cache[file], cached.modifiedAt == modifiedAt, cached.size == size {
                    refreshed[file] = cached
                    if let session = cached.session { found.append(session) }
                    continue
                }

                let session = read(file, size: size, modifiedAt: modifiedAt)
                refreshed[file] = CacheEntry(modifiedAt: modifiedAt, size: size, session: session)
                if let session { found.append(session) }
            }
        }

        cache = refreshed
        sessions = found
    }

    /// A name for each of these worktrees, for those that have one.
    public func suggestedAliases(for worktrees: [(path: String, branch: String?)]) -> [String: String] {
        SessionMatching.labels(
            for: worktrees.map { MatchableWorktree(path: $0.path, branch: $0.branch) },
            among: sessions
        )
    }

    private func read(_ file: URL, size: Int, modifiedAt: Date) -> IndexedSession? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }

        var head = (try? handle.read(upToCount: Self.chunkBytes)) ?? Data()
        var tail = Data()
        if size > Self.chunkBytes {
            try? handle.seek(toOffset: UInt64(max(0, size - Self.chunkBytes)))
            tail = (try? handle.readToEnd()) ?? Data()
            // The head's last line and the tail's first are both cut mid-record. Dropping them here
            // rather than in the parser keeps "this chunk came from the middle of a file" a fact
            // about reading rather than something every reader has to remember.
            if let lastNewline = head.lastIndex(of: UInt8(ascii: "\n")) {
                head = Data(head[..<lastNewline])
            }
            if let firstNewline = tail.firstIndex(of: UInt8(ascii: "\n")) {
                tail = Data(tail[tail.index(after: firstNewline)...])
            }
        }

        guard let transcript = SessionTranscript.read(head: head, tail: tail) else { return nil }
        return IndexedSession(
            workingDirectory: transcript.workingDirectory,
            branch: transcript.branch,
            label: transcript.label,
            modifiedAt: modifiedAt
        )
    }

    private struct CacheEntry {
        let modifiedAt: Date
        let size: Int
        let session: IndexedSession?
    }
}
