import Foundation

import CoreDiffDomain
import ServerGitDomain

// Every format here is NUL-separated and is parsed from bytes rather than from lines, because a
// path on disk is bytes and a `-z` stream is the only form of these commands that does not quote,
// escape or truncate one. Two of them have records of variable width, which is where a reader that
// splits the whole buffer and walks it in fixed steps desynchronises for good.

/// One checkout, as `worktree list --porcelain -z` reports it.
public struct WorktreeRecord: Hashable, Sendable {

    public let location: RepositoryLocation

    /// The commit checked out, absent in a worktree whose HEAD is unborn.
    ///
    /// Absent rather than all zeroes: `worktree list` reports an unborn HEAD as forty zeroes on a
    /// line that is present like any other, so a reader checking whether the line exists concludes
    /// that a repository with no commits has one.
    public let head: String?

    /// The full ref, `refs/heads/…`. Absent when detached.
    public let branch: String?

    public let isBare: Bool
    public let isDetached: Bool
    public let isLocked: Bool
    public let isPrunable: Bool

    public init(
        location: RepositoryLocation,
        head: String?,
        branch: String?,
        isBare: Bool,
        isDetached: Bool,
        isLocked: Bool,
        isPrunable: Bool
    ) {
        self.location = location
        self.head = head
        self.branch = branch
        self.isBare = isBare
        self.isDetached = isDetached
        self.isLocked = isLocked
        self.isPrunable = isPrunable
    }
}

public enum WorktreeListParser {

    /// Attributes are one per NUL field and an empty field ends a record.
    ///
    /// The final record's terminator is the one most likely to be missing, and losing it loses a
    /// whole worktree rather than a field of one, so a record in hand at the end of the stream is
    /// emitted rather than discarded.
    public static func parse(_ output: Data) -> [WorktreeRecord] {
        var records: [WorktreeRecord] = []
        var current: Attributes?

        for field in output.split(separator: 0, omittingEmptySubsequences: false) {
            let text = String(decoding: field, as: UTF8.self)
            guard text.isEmpty == false else {
                if let attributes = current { records.append(attributes.record()) }
                current = nil
                continue
            }
            let keyword = text.prefix { $0 != " " }
            let value = String(text.dropFirst(keyword.count).dropFirst())
            switch keyword {
            case "worktree":
                if let attributes = current { records.append(attributes.record()) }
                current = Attributes(path: value)
            case "HEAD": current?.head = value == String(repeating: "0", count: 40) ? nil : value
            case "branch": current?.branch = value
            case "bare": current?.isBare = true
            case "detached": current?.isDetached = true
            // Both appear bare and with a reason after them, and both spellings mean the same
            // thing, so the presence of the keyword is what counts rather than its value.
            case "locked": current?.isLocked = true
            case "prunable": current?.isPrunable = true
            default: break
            }
        }
        if let attributes = current { records.append(attributes.record()) }
        return records
    }

    private struct Attributes {
        let path: String
        var head: String?
        var branch: String?
        var isBare = false
        var isDetached = false
        var isLocked = false
        var isPrunable = false

        func record() -> WorktreeRecord {
            WorktreeRecord(
                location: RepositoryLocation(path: path),
                head: head,
                branch: branch,
                isBare: isBare,
                isDetached: isDetached,
                isLocked: isLocked,
                isPrunable: isPrunable
            )
        }
    }
}

/// One changed path, as `diff <rev> -z -M --raw` reports it.
public struct RawChange: Hashable, Sendable {

    public let path: RepositoryRelativePath

    /// Set only for a rename.
    public let oldPath: RepositoryRelativePath?

    public let status: FileStatus

    /// The object on the revision's side, all zeroes when the file was added.
    public let oldObjectId: String

    /// All zeroes whenever the working tree's content is not in the object database yet, which is
    /// every unstaged edit — the worktree blob has to be hashed separately.
    public let newObjectId: String

    public let isSubmodule: Bool

    public init(
        path: RepositoryRelativePath,
        oldPath: RepositoryRelativePath?,
        status: FileStatus,
        oldObjectId: String,
        newObjectId: String,
        isSubmodule: Bool
    ) {
        self.path = path
        self.oldPath = oldPath
        self.status = status
        self.oldObjectId = oldObjectId
        self.newObjectId = newObjectId
        self.isSubmodule = isSubmodule
    }
}

public enum RawChangeParser {

    /// A metadata field beginning with `:`, then one path field — or, for a rename, two, old first.
    ///
    /// The record width therefore varies, so the fields are consumed one at a time and a rename
    /// takes an extra one. Splitting the buffer and walking it two at a time reads every path after
    /// the first rename against the wrong record.
    public static func parse(_ output: Data) -> [RawChange] {
        var changes: [RawChange] = []
        var fields = output.split(separator: 0, omittingEmptySubsequences: true).makeIterator()

        while let metadata = fields.next() {
            let parts = String(decoding: metadata, as: UTF8.self)
                .dropFirst()
                .split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 5, let letter = parts[4].first else { continue }
            guard let first = fields.next() else { break }

            // A rename or a copy carries a similarity score after the letter and a second path.
            let isPaired = letter == "R" || letter == "C"
            let second = isPaired ? fields.next() : nil
            if isPaired, second == nil { break }

            changes.append(RawChange(
                path: RepositoryRelativePath(bytes: Data(second ?? first)),
                oldPath: isPaired ? RepositoryRelativePath(bytes: Data(first)) : nil,
                status: status(for: letter),
                oldObjectId: String(parts[2]),
                newObjectId: String(parts[3]),
                isSubmodule: parts[0] == "160000" || parts[1] == "160000"
            ))
        }
        return changes
    }

    private static func status(for letter: Character) -> FileStatus {
        switch letter {
        case "A": .added
        case "D": .deleted
        case "R", "C": .renamed
        case "T": .typeChanged
        case "U": .conflicted
        default: .modified
        }
    }
}

/// How much one path changed by, as `diff <rev> -z -M --numstat` reports it.
public struct NumstatRecord: Hashable, Sendable {

    public let path: RepositoryRelativePath

    /// Absent for a binary file, where git writes a dash. Reading the dash as zero would claim the
    /// file did not change.
    public let insertions: Int?
    public let deletions: Int?

    public init(path: RepositoryRelativePath, insertions: Int?, deletions: Int?) {
        self.path = path
        self.insertions = insertions
        self.deletions = deletions
    }
}

public enum NumstatParser {

    /// `<added>TAB<deleted>TAB<path>` in one field, or `<added>TAB<deleted>TAB` followed by two
    /// more fields, old then new.
    ///
    /// **The trailing TAB is what marks a rename**, not an empty NUL field: SPEC §5.3 said the
    /// latter, was checked against the fixture, and was wrong. A reader looking for a zero-length
    /// field finds none and takes every rename for an ordinary record.
    public static func parse(_ output: Data) -> [NumstatRecord] {
        var records: [NumstatRecord] = []
        var fields = output.split(separator: 0, omittingEmptySubsequences: true).makeIterator()

        while let field = fields.next() {
            let text = String(decoding: field, as: UTF8.self)
            let parts = text.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }

            let path: RepositoryRelativePath
            if parts[2].isEmpty {
                // A rename: the old path is next, the new one after it, and it is the new one the
                // counts belong to.
                guard fields.next() != nil, let new = fields.next() else { break }
                path = RepositoryRelativePath(bytes: Data(new))
            } else {
                path = RepositoryRelativePath(bytes: Data(field.dropFirst(
                    parts[0].utf8.count + parts[1].utf8.count + 2
                )))
            }

            records.append(NumstatRecord(
                path: path,
                insertions: Int(parts[0]),
                deletions: Int(parts[1])
            ))
        }
        return records
    }
}

public enum StatusParser {

    /// Which paths are mid-merge, from `status --porcelain=v2 -z`.
    ///
    /// This command is read for conflicts and for the worktree's revision and for nothing else: it
    /// compares HEAD to the index and the index to the working tree, while the change set compares
    /// HEAD to the working tree, and the two detect renames differently often enough that mixing
    /// them produces files with no stats.
    ///
    /// The formats' widths differ and that is the whole difficulty. An unmerged record starts with
    /// `u` and carries four modes and three object ids; an ordinary one starts with `1` and carries
    /// three and two; a renamed one starts with `2` and spans a **second NUL field** holding the
    /// path it came from. A reader written for one shape consumes into the next record.
    public static func conflictedPaths(_ output: Data) -> Set<RepositoryRelativePath> {
        var conflicted: Set<RepositoryRelativePath> = []
        var fields = output.split(separator: 0, omittingEmptySubsequences: true).makeIterator()

        while let field = fields.next() {
            guard let kind = field.first else { continue }
            switch kind {
            case UInt8(ascii: "u"):
                if let path = path(in: field, afterTokens: 10) { conflicted.insert(path) }
            case UInt8(ascii: "2"):
                // The original path follows in its own field and belongs to this record.
                _ = fields.next()
            default:
                break
            }
        }
        return conflicted
    }

    /// The path is whatever follows the record's fixed tokens, and it may contain spaces.
    private static func path(in field: Data.SubSequence, afterTokens count: Int) -> RepositoryRelativePath? {
        var remaining = Data(field)
        for _ in 0..<count {
            guard let space = remaining.firstIndex(of: UInt8(ascii: " ")) else { return nil }
            remaining = Data(remaining[remaining.index(after: space)...])
        }
        return remaining.isEmpty ? nil : RepositoryRelativePath(bytes: remaining)
    }
}

public enum UntrackedPathParser {

    public static func parse(_ output: Data) -> [RepositoryRelativePath] {
        output.split(separator: 0, omittingEmptySubsequences: true)
            .map { RepositoryRelativePath(bytes: Data($0)) }
    }
}
