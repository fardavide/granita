import Foundation
import Testing

@testable import ServerSessionsData

/// The half of the index that touches the disk: which files are read, how much of each, and what
/// is not re-read. Driven against a directory laid out the way `~/.claude` is.
@Suite("Session index")
struct SessionIndexTests {

    @Test
    func `given no agent has ever run here when refreshed then it says nothing rather than failing`(
    ) async throws {
        // given — plenty of Macs have never run Claude Code, and that is not a fault to report.
        let scenario = Scenario()
        defer { scenario.cleanUp() }

        // when
        await scenario.sut.refresh()

        // then
        #expect(await scenario.sut.suggestedAliases(for: [("/repo", nil)]).isEmpty)
    }

    @Test
    func `given a session transcript when refreshed then its worktree is named after it`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        scenario.write(
            project: "-repo-slice",
            session: "one.jsonl",
            records: [
                #"{"type":"user","cwd":"/repo/slice","message":{"role":"user","content":"Land the git client"}}"#
            ]
        )

        // when
        await scenario.sut.refresh()

        // then
        let aliases = await scenario.sut.suggestedAliases(for: [("/repo/slice", nil)])
        #expect(aliases["/repo/slice"] == "Land the git client")
    }

    @Test
    func `given a subagent transcript below a session when refreshed then it is not read`() async throws {
        // given — a session's own subagents write transcripts under it, sharing its working
        // directory, opening with a brief nobody typed. On this machine they outnumber the real
        // sessions ten to one.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        scenario.write(
            project: "-repo-slice",
            session: "one.jsonl",
            records: [
                #"{"type":"user","cwd":"/repo/slice","message":{"role":"user","content":"What Davide asked for"}}"#
            ]
        )
        scenario.write(
            project: "-repo-slice",
            session: "one/subagents/agent-a.jsonl",
            records: [
                #"{"type":"user","cwd":"/repo/slice","message":{"role":"user","content":"Search for usages"}}"#
            ]
        )

        // when
        await scenario.sut.refresh()

        // then
        let aliases = await scenario.sut.suggestedAliases(for: [("/repo/slice", nil)])
        #expect(aliases["/repo/slice"] == "What Davide asked for")
    }

    @Test
    func `given a transcript far larger than the chunks when refreshed then both ends are still read`(
    ) async throws {
        // given — these reach tens of megabytes, and the largest on this machine is 74. The title
        // is at the end and the request at the start, with padding between them that must never be
        // loaded.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let padding = Array(repeating:
            #"{"type":"assistant","cwd":"/repo","message":{"role":"assistant","content":"\#(String(repeating: "x", count: 500))"}}"#,
            count: 400
        )
        scenario.write(
            project: "-repo",
            session: "big.jsonl",
            records: [#"{"type":"user","cwd":"/repo","message":{"role":"user","content":"The opening request"}}"#]
                + padding
                + [#"{"type":"custom-title","customTitle":"The title at the end","sessionId":"s"}"#]
        )

        // when
        await scenario.sut.refresh()

        // then
        let aliases = await scenario.sut.suggestedAliases(for: [("/repo", nil)])
        #expect(aliases["/repo"] == "The title at the end")
    }

    @Test
    func `given a file that has not changed when refreshed twice then it is not read again`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        scenario.write(
            project: "-repo",
            session: "one.jsonl",
            records: [#"{"type":"user","cwd":"/repo","message":{"role":"user","content":"First"}}"#],
            modifiedAt: stamp
        )
        await scenario.sut.refresh()

        // when — the file is replaced with different content of the same length, under the same
        // timestamp. That pair is exactly what the cache claims is enough to skip a re-read.
        scenario.write(
            project: "-repo",
            session: "one.jsonl",
            records: [#"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Sec00"}}"#],
            modifiedAt: stamp
        )
        await scenario.sut.refresh()

        // then — a thousand transcripts re-read every thirty seconds is the cost this avoids.
        let aliases = await scenario.sut.suggestedAliases(for: [("/repo", nil)])
        #expect(aliases["/repo"] == "First")
    }

    @Test
    func `given a file that has changed when refreshed then the new label replaces the old one`(
    ) async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        scenario.write(
            project: "-repo",
            session: "one.jsonl",
            records: [#"{"type":"user","cwd":"/repo","message":{"role":"user","content":"First"}}"#]
        )
        await scenario.sut.refresh()

        // when
        scenario.write(
            project: "-repo",
            session: "one.jsonl",
            records: [
                #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"First"}}"#,
                #"{"type":"custom-title","customTitle":"Renamed since","sessionId":"s"}"#
            ]
        )
        await scenario.sut.refresh()

        // then
        let aliases = await scenario.sut.suggestedAliases(for: [("/repo", nil)])
        #expect(aliases["/repo"] == "Renamed since")
    }

    @Test
    func `given a file that is not a transcript when refreshed then it is ignored`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        scenario.write(project: "-repo", session: "notes.txt", records: ["not json at all"])

        // when
        await scenario.sut.refresh()

        // then
        #expect(await scenario.sut.suggestedAliases(for: [("/repo", nil)]).isEmpty)
    }

    @Test
    func `given no configured directory when the default is asked for then it is the agent's own`() {
        // given — `CLAUDE_CONFIG_DIR` is how a machine moves the whole thing, and reading
        // `~/.claude` regardless would find someone else's sessions or none at all.
        let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]

        // when
        let root = SessionIndex.defaultRootUrl().path(percentEncoded: false)

        // then
        if let configured, configured.isEmpty == false {
            #expect(root == URL(filePath: configured).path(percentEncoded: false))
        } else {
            // A directory URL carries a trailing separator, which is not part of the name.
            #expect(root.hasSuffix("/.claude/") || root.hasSuffix("/.claude"))
        }
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: SessionIndex
        let root: URL

        init() {
            root = URL.temporaryDirectory
                .appending(path: "granita-claude-\(UUID().uuidString)", directoryHint: .isDirectory)
            sut = SessionIndex(rootUrl: root)
        }

        func sessionUrl(project: String, session: String) -> URL {
            root.appending(path: "projects", directoryHint: .isDirectory)
                .appending(path: project, directoryHint: .isDirectory)
                .appending(path: session, directoryHint: .notDirectory)
        }

        func write(project: String, session: String, records: [String], modifiedAt: Date? = nil) {
            let url = sessionUrl(project: project, session: session)
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? Data(records.map { $0 + "\n" }.joined().utf8).write(to: url)
            if let modifiedAt {
                try? FileManager.default.setAttributes(
                    [.modificationDate: modifiedAt],
                    ofItemAtPath: url.path(percentEncoded: false)
                )
            }
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
