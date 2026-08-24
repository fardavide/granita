import Foundation
import Testing

import ServerStoreDomain
@testable import ServerStoreData

/// The lock file SPEC §9 asks for, beside the document it protects.
///
/// **`flock` rather than a pid file whose contents decide.** A pid written to a file outlives the
/// process that wrote it — a Granita that crashed leaves a lock nobody can take, and the usual
/// repair for that is to check whether the process still exists, which races. The kernel already
/// answers this exactly: a `flock` is released when the descriptor closes, and a descriptor closes
/// when the process dies however it dies. What the file's *contents* are for is naming the holder,
/// which is a message rather than a decision.
@Suite("File store lock")
struct FileStoreLockTests {

    @Test
    func `given nobody holds the lock when it is taken then it is acquired`() async {
        // given
        let scenario = Scenario()
        defer { scenario.cleanUp() }

        // when
        let outcome = await scenario.sut.acquire()

        // then
        #expect(outcome == .acquired)
    }

    @Test
    func `given one process holds the lock when a second asks then it is refused and told who has it`(
    ) async {
        // given — the whole point of SPEC §9's line, and the branch a composition root could never
        // be asked about.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let first = scenario.lock(processIdentifier: 4213, processName: "granita-server")
        #expect(await first.acquire() == .acquired)

        // when
        let outcome = await scenario.sut.acquire()

        // then — named rather than counted. A process identifier can be looked up and quit; "another
        // Granita is running" is a sentence a reader can do nothing with.
        #expect(outcome == .heldBy(StoreLockHolder(processIdentifier: 4213, processName: "granita-server")))
    }

    @Test
    func `given a lock file left behind by a process that is gone when it is taken then it is acquired`(
    ) async {
        // given — a Granita that crashed. The file is still there and still names a process that no
        // longer exists, and this is the case a pid file gets wrong: the kernel released the lock
        // when the descriptor closed, so the contents are stale and the lock is free.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        scenario.writeStaleLockFile(processIdentifier: 999_999, processName: "granita-server")

        // when
        let outcome = await scenario.sut.acquire()

        // then
        #expect(outcome == .acquired)
    }

    @Test
    func `given the lock file cannot be read when a second process is refused then it still says so`(
    ) async {
        // given — the refusal must survive an unreadable holder, because the alternative is a
        // second Granita deciding it may write the document after all.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        let first = scenario.lock(processIdentifier: 4213, processName: "granita-server")
        #expect(await first.acquire() == .acquired)
        scenario.corruptLockFileContents()

        // when
        let outcome = await scenario.sut.acquire()

        // then — refused, with whatever can honestly be said about the holder.
        #expect(outcome != .acquired)
    }

    @Test
    func `given the same process asks twice when the lock is taken again then it stays acquired`() async {
        // given — the Mac app asks once, but a rebind after waking must never be able to lose the
        // lock to itself.
        let scenario = Scenario()
        defer { scenario.cleanUp() }
        #expect(await scenario.sut.acquire() == .acquired)

        // when
        let outcome = await scenario.sut.acquire()

        // then
        #expect(outcome == .acquired)
    }

    @Test
    func `given a folder the lock cannot be written in when it is taken then it refuses`() async {
        // given — the store's folder is a file, so neither the directory nor the lock beside it can
        // be created. Refusing is the honest answer rather than proceeding: this process cannot
        // show that nobody else holds the document, and serving anyway would be a guess about the
        // one thing the lock exists to settle.
        let scenario = Scenario()
        defer { scenario.cleanUp() }

        // when
        let outcome = await scenario.lockBesideAFile().acquire()

        // then
        #expect(outcome == .heldBy(nil))
    }

    // MARK: - What the refusal is allowed to say

    @Test
    func `given a holder when a refusal is drawn then it names the process and its identifier`() {
        // given — both halves, because neither is enough alone: a name does not say *which*
        // granita-server, and a bare number is something a reader has to go and resolve first.
        let holder = StoreLockHolder(processIdentifier: 4213, processName: "granita-server")

        // then — spelled out rather than rebuilt from the same expression, since three surfaces
        // read this one string and a test that recomputes it cannot see it change.
        #expect(holder.sentence == "granita-server (process 4213)")
    }

    @Test
    func `given this very process when it describes itself then it carries a real name and identifier`(
    ) {
        // given - when — the factory both composition roots use, so neither has to know how to ask
        // `ProcessInfo`.
        let holder = StoreLockHolder.thisProcess

        // then — asserted against the running process rather than against a literal, which is the
        // only thing a test can honestly say about it.
        #expect(holder.processIdentifier == ProcessInfo.processInfo.processIdentifier)
        #expect(holder.processName == ProcessInfo.processInfo.processName)
        #expect(holder.processName.isEmpty == false)
    }

    // MARK: -

    private struct Scenario {

        let sut: FileStoreLock
        let storeUrl: URL

        init() {
            let directory = URL.temporaryDirectory
                .appending(path: "granita-lock-\(UUID().uuidString)", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storeUrl = directory.appending(path: "granita.json", directoryHint: .notDirectory)
            sut = FileStoreLock(besideStoreAt: storeUrl, holder: StoreLockHolder(
                processIdentifier: 1234,
                processName: "Granita"
            ))
        }

        /// Another process, standing in for one. The holder is a value rather than something read
        /// from `ProcessInfo`, precisely so a test can be two processes without being two.
        func lock(processIdentifier: Int32, processName: String) -> FileStoreLock {
            FileStoreLock(besideStoreAt: storeUrl, holder: StoreLockHolder(
                processIdentifier: processIdentifier,
                processName: processName
            ))
        }

        /// A store whose containing folder is an ordinary file, so nothing can be created beside it.
        func lockBesideAFile() -> FileStoreLock {
            let file = storeUrl.deletingLastPathComponent()
                .appending(path: "a-file", directoryHint: .notDirectory)
            try? Data("not a directory".utf8).write(to: file)
            return FileStoreLock(
                besideStoreAt: file.appending(path: "granita.json", directoryHint: .notDirectory),
                holder: StoreLockHolder(processIdentifier: 1234, processName: "Granita")
            )
        }

        func writeStaleLockFile(processIdentifier: Int32, processName: String) {
            let holder = StoreLockHolder(processIdentifier: processIdentifier, processName: processName)
            try? JSONEncoder().encode(holder).write(to: lockUrl)
        }

        func corruptLockFileContents() {
            try? Data("not json".utf8).write(to: lockUrl)
        }

        private var lockUrl: URL {
            storeUrl.deletingLastPathComponent().appending(path: "granita.lock", directoryHint: .notDirectory)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: storeUrl.deletingLastPathComponent())
        }
    }
}
