import Foundation

import ServerGitDomain

/// Answers the commands it was given answers for and refuses the rest.
///
/// An actor because it records what it was asked, and what it was asked is the assertion in the
/// tests that matter most here: which revision a comparison ran against, and whether a second
/// comparison was run at all.
actor FakeGitClient: GitClient {

    private let outputs: [GitCommand: Data]
    private let failures: [GitCommand: GitError]
    private let anyFileDiff: Data

    /// Paths this git refuses to hash, which is what a symlink pointing at a directory is.
    ///
    /// Modelled the way the real thing behaves, measured against `git 2.52`: the batch **fails
    /// whole**, with `fatal: Unable to hash <path>` and exit 128, however many good paths were in it.
    private let unhashablePaths: Set<String>

    private(set) var received: [GitCommand] = []

    init(
        outputs: [GitCommand: Data],
        failures: [GitCommand: GitError],
        unhashablePaths: Set<String> = [],
        anyFileDiff: Data = Data()
    ) {
        self.outputs = outputs
        self.failures = failures
        self.unhashablePaths = unhashablePaths
        self.anyFileDiff = anyFileDiff
    }

    func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        received.append(command)
        if let failure = failures[command] {
            throw failure
        }
        // Answered by kind rather than by value, because the paths this one carries are derived
        // from the change set rather than chosen by a test, and reproducing them in every `given`
        // would assert the derivation twice and the object ids not at all.
        //
        // **One id per path asked for, derived from the path**, so that a caller which falls back to
        // hashing paths one at a time gets the same answer it would have got in the batch — which is
        // the property the fallback exists to keep, and a fake handing out a fixed list by position
        // could not express.
        if case .hashWorktreeFiles(let paths) = command {
            let texts = paths.map(\.text)
            if let refused = texts.first(where: unhashablePaths.contains) {
                throw .commandFailed(
                    command: command,
                    exitCode: 128,
                    standardError: "fatal: Unable to hash \(refused)"
                )
            }
            return GitOutput(
                standardOutput: Data(texts.map { objectId(for: $0) + "\n" }.joined().utf8),
                isTruncated: false
            )
        }
        // Answered by kind for the same reason: the path a diff is asked for is chosen by the
        // caller under test, and a test that has to restate it asserts the plumbing twice.
        switch command {
        case .fileDiff, .untrackedFileDiff:
            return GitOutput(standardOutput: anyFileDiff, isTruncated: false)
        default:
            return GitOutput(standardOutput: outputs[command] ?? Data(), isTruncated: false)
        }
    }
}

/// Forty hex characters that depend only on the path, so two files never collide and one file
/// answers the same however it was asked for.
///
/// Deterministic rather than `hashValue`, which Swift seeds per process — a fake whose answers
/// change between runs is a test that passes for a reason nobody chose.
private func objectId(for path: String) -> String {
    var accumulated: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in path.utf8 {
        accumulated = (accumulated ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
    }
    return String(repeating: String(format: "%016lx", accumulated), count: 3).prefix(40).description
}
