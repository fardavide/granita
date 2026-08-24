import Foundation

import ServerGitDomain

/// Answers with what it was handed, or refuses with what it was handed.
///
/// Its own copy rather than the worktree suite's, because SwiftPM test targets cannot import each
/// other and the alternative is shipping test doubles in the product. This one is far smaller: the
/// subject here wraps a client rather than interrogating one, so what a test needs is an answer and
/// a refusal, not a table of commands.
actor FakeGitClient: GitClient {

    private(set) var received: [GitCommand] = []

    private let output: GitOutput
    private let failure: GitError?

    init(output: GitOutput, failure: GitError?) {
        self.output = output
        self.failure = failure
    }

    func run(_ command: GitCommand, in location: RepositoryLocation) throws(GitError) -> GitOutput {
        received.append(command)
        if let failure {
            throw failure
        }
        return output
    }
}
