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
    private let hashedObjectIds: [String]
    private let anyFileDiff: Data
    private(set) var received: [GitCommand] = []

    init(
        outputs: [GitCommand: Data],
        failures: [GitCommand: GitError],
        hashedObjectIds: [String],
        anyFileDiff: Data = Data()
    ) {
        self.outputs = outputs
        self.failures = failures
        self.hashedObjectIds = hashedObjectIds
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
        if case .hashWorktreeFiles = command {
            return GitOutput(
                standardOutput: Data(hashedObjectIds.map { $0 + "\n" }.joined().utf8),
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
