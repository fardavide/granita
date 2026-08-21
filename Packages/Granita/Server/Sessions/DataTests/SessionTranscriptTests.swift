import Foundation
import Testing

@testable import ServerSessionsData

/// The findings behind these are at the top of `SessionTranscript`. They were taken from the real
/// transcripts on this machine rather than from the specification, and three of them contradict it.
@Suite("Session transcript")
struct SessionTranscriptTests {

    // MARK: - Where the working directory comes from

    @Test
    func `given leading records that carry no working directory when read then a later one is used`() {
        // given — SPEC §7 says `cwd` is on every record. It is not: the queue, title, prompt and
        // link records carry none, and one of them is routinely the first line of the file.
        let transcript = lines([
            #"{"type":"queue-operation","operation":"add","sessionId":"s"}"#,
            #"{"type":"last-prompt","lastPrompt":"go on","sessionId":"s"}"#,
            #"{"type":"user","cwd":"/repo/slice","gitBranch":"worktree-slice","message":{"role":"user","content":"Fix the parser"}}"#
        ])

        // when
        let read = SessionTranscript.read(head: transcript, tail: Data())

        // then
        #expect(read?.workingDirectory == "/repo/slice")
        #expect(read?.branch == "worktree-slice")
    }

    @Test
    func `given a transcript with no working directory anywhere when read then there is nothing to match`() {
        // given
        let transcript = lines([#"{"type":"queue-operation","operation":"add","sessionId":"s"}"#])

        // when - then — a file that never names a directory cannot be attached to a worktree, and
        // guessing from the directory name under `projects/` is what §7 forbids.
        #expect(SessionTranscript.read(head: transcript, tail: Data()) == nil)
    }

    // MARK: - What the label is

    @Test
    func `given an explicit title when read then it wins over the first thing that was asked`() {
        // given
        let head = lines([
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Fix the parser"}}"#
        ])
        let tail = lines([#"{"type":"custom-title","customTitle":"Diff parser rewrite","sessionId":"s"}"#])

        // when
        let read = SessionTranscript.read(head: head, tail: tail)

        // then — a title is the one thing in a transcript a person wrote to describe the work.
        #expect(read?.label == "Diff parser rewrite")
    }

    @Test
    func `given no title when read then the first thing that was asked becomes the label`() {
        // given
        let head = lines([
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Fix the parser"}}"#,
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"now the tests"}}"#
        ])

        // when
        let read = SessionTranscript.read(head: head, tail: Data())

        // then — the first request names the task; the most recent one names whatever it has got
        // down to by now, which makes a worse name for the worktree as a whole.
        #expect(read?.label == "Fix the parser")
    }

    @Test
    func `given an injected block as the first user record when read then it is not the label`() {
        // given — a task notification and a system reminder arrive as user records that nobody
        // typed, and one of them is often the first in the file.
        let head = lines([
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"<task-notification>\ndone\n</task-notification>"}}"#,
            #"{"type":"user","cwd":"/repo","isMeta":true,"message":{"role":"user","content":"Caveat: the messages below"}}"#,
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Add the file selector"}}"#
        ])

        // when
        let read = SessionTranscript.read(head: head, tail: Data())

        // then
        #expect(read?.label == "Add the file selector")
    }

    @Test
    func `given a subagent's own turn when read then it is not mistaken for the session's task`() {
        // given
        let head = lines([
            #"{"type":"user","cwd":"/repo","isSidechain":true,"message":{"role":"user","content":"Search for usages"}}"#,
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Land the git client"}}"#
        ])

        // when
        let read = SessionTranscript.read(head: head, tail: Data())

        // then
        #expect(read?.label == "Land the git client")
    }

    @Test
    func `given a tool result when read then it is not mistaken for something a person asked`() {
        // given — a tool's output comes back as a user record carrying `toolUseResult`.
        let head = lines([
            #"{"type":"user","cwd":"/repo","toolUseResult":{"stdout":"ok"},"message":{"role":"user","content":"ok"}}"#,
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Write the store"}}"#
        ])

        // when - then
        #expect(SessionTranscript.read(head: head, tail: Data())?.label == "Write the store")
    }

    // MARK: - What reaches the network

    @Test
    func `given a long request when read then the label stops at sixty characters on a word`() {
        // given — this text goes over the LAN as a worktree's name, so its length is a privacy
        // decision rather than a layout one.
        let request = "Refactor the entire persistence layer to use the new store protocol and migrate everything"
        let head = lines([
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":"\#(request)"}}"#
        ])

        // when
        let label = try? #require(SessionTranscript.read(head: head, tail: Data())?.label)

        // then
        let label60 = try? #require(label)
        #expect((label60?.count ?? 0) <= 60)
        #expect(label60?.hasSuffix(" ") == false)
        #expect(label60?.hasPrefix("Refactor the entire persistence layer") == true)
    }

    @Test
    func `given a request written over several lines with markdown when read then it is one plain line`() {
        // given
        let head = lines([
            ##"{"type":"user","cwd":"/repo","message":{"role":"user","content":"# Heading\n\nUse `**bold**` and *emphasis*\nacross lines"}}"##
        ])

        // when
        let label = SessionTranscript.read(head: head, tail: Data())?.label

        // then — a worktree's name is one line in a list, and markdown in it reads as noise.
        #expect(label?.contains("\n") == false)
        #expect(label?.contains("#") == false)
        #expect(label?.contains("*") == false)
        #expect(label?.contains("`") == false)
    }

    @Test
    func `given content that arrived as blocks rather than a string when read then its text is found`() {
        // given
        let head = lines([
            #"{"type":"user","cwd":"/repo","message":{"role":"user","content":[{"type":"text","text":"Add pinning"}]}}"#
        ])

        // when - then
        #expect(SessionTranscript.read(head: head, tail: Data())?.label == "Add pinning")
    }

    // MARK: - Reading a file that is tens of megabytes

    @Test
    func `given a chunk that begins mid-record when read then the broken record is discarded`() {
        // given — the tail chunk starts 64 KB from the end, which lands in the middle of a line
        // far more often than not.
        let head = lines([#"{"type":"user","cwd":"/repo","message":{"role":"user","content":"Start"}}"#])
        var tail = Data(#"tle":"Broken","sessionId":"s"}"# .utf8)
        tail.append(UInt8(ascii: "\n"))
        tail.append(contentsOf: lines([#"{"type":"custom-title","customTitle":"Whole","sessionId":"s"}"#]))

        // when
        let read = SessionTranscript.read(head: head, tail: tail)

        // then — feeding the fragment to a decoder is the failure §7 warns about, and it is silent:
        // the fragment simply does not parse and whatever it said is lost either way.
        #expect(read?.label == "Whole")
    }
}

private func lines(_ records: [String]) -> Data {
    Data(records.map { $0 + "\n" }.joined().utf8)
}
