import CoreServices
import Darwin
import Foundation
import Testing

import ServerGitDomain
import ServerWorktreesDomain
@testable import ServerWatchData

@Suite("Filesystem worktree observation")
struct FileSystemWorktreeObservationSourceTests {

    @Test(.timeLimit(.minutes(1)))
    func `given a watched folder when a source file changes then its path arrives`() async throws {
        // given
        let scenario = try Scenario()
        defer {
            do { try FileManager.default.removeItem(at: scenario.folder) }
            catch { Issue.record("Could not remove observation fixture: \(error)") }
        }
        var events = try await scenario.sut.events(watching: [
            scenario.location
        ]).makeAsyncIterator()
        let changed = scenario.folder.appending(path: "Reader.swift")
        let expected = RepositoryLocation(path: scenario.location.path + "/Reader.swift")

        // when
        try Data("let revision = 42\n".utf8).write(to: changed)
        var received = false
        while let event = await events.next() {
            if case .changed(let locations) = event,
               locations.contains(where: { $0.path.hasSuffix("/Reader.swift") }) {
                received = locations.contains(expected)
                break
            }
        }
        await scenario.sut.stop()

        // then
        #expect(received)
    }

    @Test(arguments: [
        FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs),
        FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped),
        FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped),
        FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged),
        FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped),
        FSEventStreamEventFlags(kFSEventStreamEventFlagMount),
        FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount)
    ])
    func `given event loss or changed roots when decoding then inventory must be reconciled`(
        _ flags: FSEventStreamEventFlags
    ) {
        // given - when
        let event = FileSystemWorktreeObservationSource.decode(
            paths: [RepositoryLocation(path: "/project/Reader.swift")],
            flags: [flags]
        )

        // then
        #expect(event == .rescanRequired)
    }

    @Test
    func `given a full event buffer when more paths arrive then reconciliation survives the overflow`() async {
        // given
        let events = AsyncStream.makeStream(of: WorktreeObservationEvent.self, bufferingPolicy: .bufferingNewest(1))
        FileSystemWorktreeObservationSource.send(
            .changed([RepositoryLocation(path: "/project/First.swift")]), to: events.continuation
        )

        // when
        FileSystemWorktreeObservationSource.send(
            .changed([RepositoryLocation(path: "/project/Latest.swift")]), to: events.continuation
        )
        var iterator = events.stream.makeAsyncIterator()
        let received = await iterator.next()
        events.continuation.finish()

        // then
        #expect(received == .rescanRequired)
    }

    private struct Scenario {
        let sut: FileSystemWorktreeObservationSource
        let folder: URL
        let location: RepositoryLocation

        init() throws {
            let created = FileManager.default.temporaryDirectory
                .appending(path: "granita-observation-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: created, withIntermediateDirectories: true)
            let resolved = try #require(realpath(created.path, nil))
            defer { free(resolved) }
            folder = created
            location = RepositoryLocation(path: String(cString: resolved))
            sut = FileSystemWorktreeObservationSource()
        }
    }
}
