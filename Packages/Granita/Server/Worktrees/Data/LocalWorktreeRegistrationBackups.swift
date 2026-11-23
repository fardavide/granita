import Darwin
import Foundation

import ServerGitDomain
import ServerWorktreesDomain

public struct LocalWorktreeRegistrationBackups: WorktreeRegistrationBackingUp {

    private static let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC

    public init() {}

    public func backUp(
        _ registrations: [WorktreeRegistrationName],
        in commonGitDirectory: RepositoryLocation
    ) throws(WorktreePruneError) {
        guard !registrations.isEmpty else { return }
        guard Set(registrations).count == registrations.count else { throw .unavailable }

        let common = try openCommonDirectory(commonGitDirectory)
        defer { _ = close(common) }
        let worktrees = try openDirectory("worktrees", under: common)
        defer { _ = close(worktrees) }

        // Preflight the whole batch before creating a backup or moving an entry.
        for registration in registrations {
            let entry = try openStaleRegistration(registration, under: worktrees)
            _ = close(entry)
        }

        let backupName = "granita-worktree-backups"
        guard mkdirat(common, backupName, 0o700) == 0 || errno == EEXIST else { throw .unavailable }
        let backups = try openDirectory(backupName, under: common)
        defer { _ = close(backups) }
        let batchName = UUID().uuidString
        guard mkdirat(backups, batchName, 0o700) == 0 else { throw .unavailable }
        let batch = try openDirectory(batchName, under: backups)
        defer { _ = close(batch) }

        var moved: [WorktreeRegistrationName] = []
        do throws(WorktreePruneError) {
            for registration in registrations {
                let entry = try openStaleRegistration(registration, under: worktrees)
                defer { _ = close(entry) }
                var original = stat()
                guard fstat(entry, &original) == 0 else { throw .unavailable }

                guard move(registration, from: worktrees, to: batch) else { throw .unavailable }
                moved.append(registration)

                // The source can be replaced between opening it and renaming it. The backup
                // must contain the directory just checked, or this batch needs to be rolled back.
                var saved = stat()
                guard fstatat(batch, registration.rawValue, &saved, AT_SYMLINK_NOFOLLOW) == 0,
                      original.st_dev == saved.st_dev, original.st_ino == saved.st_ino else {
                    throw .previewChanged
                }
            }
        } catch {
            var rolledBack = true
            for registration in moved.reversed() {
                if !move(registration, from: batch, to: worktrees) { rolledBack = false }
            }
            // A concurrent writer may have recreated a source name. Never overwrite it. The
            // original remains recoverable in this batch even when it could not be put back.
            if !rolledBack { throw .unavailable }
            throw error
        }
    }

    private func openCommonDirectory(_ location: RepositoryLocation) throws(WorktreePruneError) -> Int32 {
        let components = location.path.split(separator: "/")
        guard location.path.hasPrefix("/"), !components.isEmpty,
              components.allSatisfy({ $0 != "." && $0 != ".." }) else { throw .unavailable }

        var current = open("/", Self.directoryFlags)
        guard current >= 0 else { throw .unavailable }
        for component in components {
            let next = openat(current, String(component), Self.directoryFlags)
            _ = close(current)
            guard next >= 0 else { throw .unavailable }
            current = next
        }
        return current
    }

    private func openDirectory(_ name: String, under parent: Int32) throws(WorktreePruneError) -> Int32 {
        let descriptor = openat(parent, name, Self.directoryFlags)
        guard descriptor >= 0 else { throw .unavailable }
        return descriptor
    }

    private func openStaleRegistration(
        _ name: WorktreeRegistrationName,
        under worktrees: Int32
    ) throws(WorktreePruneError) -> Int32 {
        guard try containsExactName(name, in: worktrees) else { throw .previewChanged }
        let entry = try openDirectory(name.rawValue, under: worktrees)
        do throws(WorktreePruneError) {
            var status = stat()
            guard fstatat(entry, "locked", &status, AT_SYMLINK_NOFOLLOW) == -1, errno == ENOENT else {
                throw .previewChanged
            }
            let target = try gitdirPath(in: entry)
            // fstatat resolves relative links from the registration directory just as Git does.
            guard fstatat(entry, target, &status, AT_SYMLINK_NOFOLLOW) == -1, errno == ENOENT else {
                throw .previewChanged
            }
            return entry
        } catch {
            _ = close(entry)
            throw error
        }
    }

    private func containsExactName(
        _ name: WorktreeRegistrationName,
        in worktrees: Int32
    ) throws(WorktreePruneError) -> Bool {
        // An APFS lookup can resolve a differently cased or normalized name in the same folder.
        let descriptor = try openDirectory(".", under: worktrees)
        guard let entries = fdopendir(descriptor) else {
            _ = close(descriptor)
            throw .unavailable
        }
        defer { _ = closedir(entries) }
        while let entry = readdir(entries) {
            let length = Int(entry.pointee.d_namlen)
            let isMatch = withUnsafeBytes(of: entry.pointee.d_name) {
                $0.prefix(length).elementsEqual(name.rawValue.utf8)
            }
            if isMatch { return true }
        }
        return false
    }

    private func gitdirPath(in entry: Int32) throws(WorktreePruneError) -> String {
        let descriptor = openat(entry, "gitdir", O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw .unavailable }
        defer { _ = close(descriptor) }

        var status = stat()
        guard fstat(descriptor, &status) == 0,
              status.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              status.st_size > 0, status.st_size < Int(PATH_MAX) + 3 else { throw .unavailable }

        var bytes = [UInt8](repeating: 0, count: Int(PATH_MAX) + 3)
        let count = bytes.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
        guard count == status.st_size else { throw .unavailable }
        var link = bytes.prefix(count)
        while link.last == UInt8(ascii: "\n") || link.last == UInt8(ascii: "\r") {
            link = link.dropLast()
        }
        let disallowed = CharacterSet.controlCharacters.union(.newlines)
        guard let path = String(bytes: link, encoding: .utf8), path.hasSuffix("/.git"),
              path.rangeOfCharacter(from: disallowed) == nil else { throw .unavailable }
        return path
    }

    private func move(_ name: WorktreeRegistrationName, from source: Int32, to destination: Int32) -> Bool {
        renameatx_np(
            source, name.rawValue,
            destination, name.rawValue,
            UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
        ) == 0
    }
}
