import CryptoKit
import Foundation

// CryptoKit for the reason given in `Identifiers.swift`: it is pure computation on both platforms,
// and the alternative is a hand-rolled SHA-256 in the one place where being subtly wrong cannot be
// seen by reading it. This file follows that precedent rather than setting a new one.

/// Hashes that say *what something is right now* rather than *which thing it is*.
///
/// The distinction from an identifier matters and is the whole design. An identifier is stable for
/// the life of a file so a phone can hold onto it; these move whenever the content moves, which is
/// what makes a file marked viewed become unviewed the moment the agent edits it again. Keying
/// viewed state on the path alone would leave a stale "you have read this" over a file that has
/// changed underneath the reader.
public enum ContentHash {

    /// What one file is: its status and its three object ids, in that order.
    ///
    /// The three ids are the side in the revision, the side in the index, and the side in the
    /// working tree, and all three are needed because a file can differ on any of them
    /// independently — staged and then edited again is a different state from either alone.
    public static func forFile(
        status: FileStatus,
        headObjectId: String,
        indexObjectId: String,
        worktreeObjectId: String
    ) -> String {
        hexadecimal(of: "\(status.rawValue)\(headObjectId)\(indexObjectId)\(worktreeObjectId)")
    }

    /// What a whole worktree is, over the bytes git reported its state as.
    ///
    /// Over the raw bytes rather than over anything parsed out of them, so that the comparison is
    /// with what git said and cannot drift as the parsing changes.
    public static func revision(ofStatusBytes bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    /// The object id git reports for a path that has no content on a side.
    public static let absentObjectId = String(repeating: "0", count: 40)

    private static func hexadecimal(of text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
