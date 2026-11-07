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
    private let yields: Bool
    private var active = 0
    private(set) var maximumActive = 0

    init(output: GitOutput, failure: GitError?, yields: Bool = false) {
        self.output = output
        self.failure = failure
        self.yields = yields
    }

    func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        received.append(command)
        active += 1
        maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        if yields {
            for _ in 0..<10 { await Task.yield() }
        }
        if let failure {
            throw failure
        }
        return output
    }
}
