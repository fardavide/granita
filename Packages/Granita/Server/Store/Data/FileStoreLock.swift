import Foundation

import ServerStoreDomain

/// SPEC §9's lock file, beside the document it protects.
///
/// **`flock` rather than a pid file whose contents decide who holds it.** A pid written to a file
/// outlives the process that wrote it, so a Granita that crashed would leave a lock nobody can take
/// — and the usual repair, checking whether that process still exists, races against the identifier
/// being reused. The kernel already answers this exactly: a `flock` is released when the descriptor
/// closes, and a descriptor closes when the process dies however it dies. So the *decision* is the
/// kernel's and the file's contents are only a message: who to name in the refusal.
///
/// **The descriptor is never closed on purpose.** Holding it open for the life of the process is
/// what holds the lock; releasing it at the end of a function would be a lock that answers a
/// question about a moment that has already passed.
///
/// An actor because the descriptor is mutable state that two callers could otherwise open twice —
/// and the second open, in this very process, is a lock this process would then be refused by
/// itself.
public actor FileStoreLock: StoreLocking {

    /// Beside the document rather than inside it: the document is replaced atomically, and a lock
    /// living in a file that is periodically swapped out underneath the descriptor holding it is a
    /// lock that quietly stops meaning anything.
    public static let fileName = "granita.lock"

    private let lockUrl: URL
    private let holder: StoreLockHolder
    private var descriptor: Int32?

    /// The holder is handed in rather than read from `ProcessInfo` here, which is what lets a test
    /// be two processes without being two — and keeps the one fact each composition root knows
    /// about itself in the root.
    public init(besideStoreAt storeUrl: URL, holder: StoreLockHolder) {
        lockUrl = storeUrl
            .deletingLastPathComponent()
            .appending(path: Self.fileName, directoryHint: .notDirectory)
        self.holder = holder
    }

    public func acquire() -> StoreLockOutcome {
        // Already ours. A rebind after waking asks again, and a lock that could be lost to the
        // process already holding it would turn a wake into a refusal.
        guard descriptor == nil else { return .acquired }

        // First run: nothing has created the Application Support folder yet, and the store itself
        // does not exist until something is written to it.
        try? FileManager.default.createDirectory(
            at: lockUrl.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let opened = open(lockUrl.path(percentEncoded: false), O_CREAT | O_RDWR, 0o644)
        guard opened >= 0 else {
            // The folder is not writable. Refusing is the honest answer: this process cannot show
            // that nobody else holds the document, and proceeding would be a guess.
            return .heldBy(nil)
        }

        guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
            close(opened)
            return .heldBy(readHolder())
        }

        descriptor = opened
        write(holder, to: opened)
        return .acquired
    }

    /// Who the file says has it, or nothing when it cannot say.
    ///
    /// Failing to a name rather than to a decision: the refusal has already been decided by the
    /// kernel above, and everything here only affects the sentence a reader is shown.
    private func readHolder() -> StoreLockHolder? {
        guard let data = try? Data(contentsOf: lockUrl) else { return nil }
        return try? JSONDecoder().decode(StoreLockHolder.self, from: data)
    }

    /// Truncated first, because the previous holder's line is longer than some replacements and a
    /// partial overwrite leaves a file that decodes to the wrong process.
    private func write(_ holder: StoreLockHolder, to descriptor: Int32) {
        guard let data = try? JSONEncoder().encode(holder) else { return }
        ftruncate(descriptor, 0)
        lseek(descriptor, 0, SEEK_SET)
        data.withUnsafeBytes { buffer in
            _ = Darwin.write(descriptor, buffer.baseAddress, buffer.count)
        }
    }
}
