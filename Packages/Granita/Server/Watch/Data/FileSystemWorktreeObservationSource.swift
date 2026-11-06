import CoreServices
import Dispatch
import Foundation

import ServerGitDomain
import ServerWorktreesDomain

public actor FileSystemWorktreeObservationSource: WorktreeObservationSource {
    private var session: Session = .stopped

    public init() {}

    public func events(
        watching locations: [RepositoryLocation]
    ) async throws(WorktreeObservationError) -> AsyncStream<WorktreeObservationEvent> {
        await stop()
        let pair = AsyncStream.makeStream(of: WorktreeObservationEvent.self, bufferingPolicy: .bufferingNewest(64))
        let callback = FileSystemEventCallback(continuation: pair.continuation)
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(callback).toOpaque(),
            retain: { pointer in
                guard let pointer else { return nil }
                _ = Unmanaged<FileSystemEventCallback>.fromOpaque(pointer).retain()
                return pointer
            },
            release: { pointer in
                guard let pointer else { return }
                Unmanaged<FileSystemEventCallback>.fromOpaque(pointer).release()
            },
            copyDescription: nil
        )
        guard let reference = FSEventStreamCreate(
            nil,
            { _, context, count, paths, flags, _ in
                guard let context else { return }
                let callback = Unmanaged<FileSystemEventCallback>.fromOpaque(context).takeUnretainedValue()
                // Without UseCFTypes, FSEvents documents this buffer as count C-string pointers.
                let strings = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
                FileSystemWorktreeObservationSource.send(FileSystemWorktreeObservationSource.decode(
                    paths: (0..<count).map { RepositoryLocation(path: String(cString: strings[$0])) },
                    flags: Array(UnsafeBufferPointer(start: flags, count: count))
                ), to: callback.continuation)
            },
            &context,
            locations.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.05,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        ) else {
            pair.continuation.finish()
            throw .couldNotCreateStream
        }
        let native = FileSystemEventSession(reference: reference, callback: callback)
        FSEventStreamSetDispatchQueue(reference, native.queue)
        guard FSEventStreamStart(reference) else {
            pair.continuation.finish()
            throw .couldNotStartStream
        }

        let id = UUID()
        session = .watching(id, native)
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.stop(id) }
        }
        return pair.stream
    }

    public func stop() async {
        let previous = session
        session = .stopped
        if case .watching(_, let native) = previous {
            native.callback.continuation.finish()
        }
    }

    static func decode(
        paths: [RepositoryLocation],
        flags: [FSEventStreamEventFlags]
    ) -> WorktreeObservationEvent {
        let rescan = FSEventStreamEventFlags(
            kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
                | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagRootChanged
                | kFSEventStreamEventFlagEventIdsWrapped | kFSEventStreamEventFlagMount
                | kFSEventStreamEventFlagUnmount
        )
        return flags.contains(where: { $0 & rescan != 0 }) ? .rescanRequired : .changed(paths)
    }

    static func send(
        _ event: WorktreeObservationEvent,
        to continuation: AsyncStream<WorktreeObservationEvent>.Continuation
    ) {
        if case .dropped = continuation.yield(event) {
            continuation.yield(.rescanRequired)
        }
    }

    private func stop(_ id: UUID) async {
        guard case .watching(let current, _) = session, current == id else { return }
        await stop()
    }

    private enum Session {
        case stopped
        case watching(UUID, FileSystemEventSession)
    }
}

private final class FileSystemEventCallback: Sendable {
    let continuation: AsyncStream<WorktreeObservationEvent>.Continuation

    init(continuation: AsyncStream<WorktreeObservationEvent>.Continuation) {
        self.continuation = continuation
    }
}

private final class FileSystemEventSession: @unchecked Sendable { // The owning actor controls the immutable C handle and stops callbacks before release.
    let queue = DispatchQueue(label: "dev.fardavide.granita.worktree-observation", qos: .utility)
    let reference: FSEventStreamRef
    let callback: FileSystemEventCallback

    init(reference: FSEventStreamRef, callback: FileSystemEventCallback) {
        self.reference = reference
        self.callback = callback
    }

    deinit {
        FSEventStreamStop(reference)
        FSEventStreamInvalidate(reference)
        FSEventStreamRelease(reference)
    }
}
