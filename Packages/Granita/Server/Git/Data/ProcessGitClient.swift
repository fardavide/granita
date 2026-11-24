import Foundation
import Subprocess
import System

import ServerGitDomain

/// Runs the git binary.
///
/// Deliberately a subprocess rather than a library binding: git is the source of truth for what a
/// worktree is and for what the index holds, and a binding diverges exactly there. The cost is that
/// three things about running a child process have to be right, and each of them fails in a way
/// that looks like something else — see ``drain(_:command:)`` and ``run(_:in:)``.
public struct ProcessGitClient: GitClient {

    /// SPEC §5.4's ceiling on a single file's diff. Beyond it the client shows a prefix and says so.
    public static let defaultOutputLimitBytes = 2 * 1024 * 1024

    /// The ceiling for printing one committed file whole, which is a different question from a diff.
    ///
    /// **A prefix is a usable answer for a diff and a useless one for a blob.** Everything else here
    /// is read to be parsed line by line, so cutting it off costs the tail; `show <rev>:<path>` is
    /// read to be handed over intact — as a picture to draw, or as the file context expansion splices
    /// from — and a prefix of either is wrong rather than short. Granita's own iPad baselines are
    /// 6.4 MB apiece, so the diff ceiling would have cut every one of them in half.
    ///
    /// It has to stay **above** `WorktreeLimits.maximumImageBytes`, which is what the product refuses
    /// at: the service can only tell a picture over budget from a picture that was trimmed if nothing
    /// inside the budget is ever trimmed.
    public static let fileContentLimitBytes = 16 * 1024 * 1024

    /// SPEC §5.1's budget for one invocation.
    public static let defaultTimeout = Duration.seconds(10)

    /// Bound git's diagnostics and verbose prune reports independently of standard output.
    private static let standardErrorLimitBytes = 64 * 1024

    /// How long a torn-down process is given to exit before it is killed.
    private static let terminationGrace = Duration.milliseconds(500)

    private let executablePath: String
    private let outputLimitBytes: Int
    private let timeout: Duration

    public init(executablePath: String, outputLimitBytes: Int, timeout: Duration) {
        self.executablePath = executablePath
        self.outputLimitBytes = outputLimitBytes
        self.timeout = timeout
    }

    public func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        switch command {
        case .untrackedRenameStats(_, let destinations, _):
            return try await runWithScratchIndex(command, tracking: destinations, in: location)
        case .renamedFileDiff(_, let destination, _, _):
            return try await runWithScratchIndex(command, tracking: [destination], in: location)
        case .version, .isInsideWorkTree, .repositoryRoot, .gitDirectory, .commonGitDirectory,
             .currentBranch, .headCommit, .worktrees, .untrackedPaths, .worktreeStatus, .trackedChanges,
             .trackedStats, .fileDiff, .untrackedFileDiff, .fileContent, .removeWorktree,
             .previewWorktreePrune, .hashWorktreeFiles:
            return try await invoke(
                command,
                in: location,
                arguments: GitInvocation.arguments(for: command),
                input: GitInvocation.standardInput(for: command),
                environment: GitInvocation.environmentOverrides(for: command)
            )
        }
    }

    private func runWithScratchIndex(
        _ command: GitCommand,
        tracking destinations: [RepositoryRelativePath],
        in location: RepositoryLocation
    ) async throws(GitError) -> GitOutput {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "granita-rename-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw .gitUnavailable(reason: "Cannot create a temporary index directory: \(error)")
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        var environment = GitInvocation.environmentOverrides(for: command)
        environment["GIT_INDEX_FILE"] = directory.appending(path: "index").path
        environment["GIT_NO_LAZY_FETCH"] = "1"
        let emptyBlob = try await invoke(
            command,
            in: location,
            arguments: GitInvocation.emptyBlobArguments,
            input: Data(),
            environment: environment,
            requiresZeroExit: true
        )
        guard !emptyBlob.isTruncated else {
            throw .gitUnavailable(reason: "Git truncated the empty blob identifier for the temporary index")
        }
        let objectId = String(decoding: emptyBlob.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .newlines)

        // An index entry with empty content and no cached stat data makes git compare the
        // destination's current working bytes. update-index writes only the private index.
        _ = try await invoke(
            command,
            in: location,
            arguments: GitInvocation.scratchIndexArguments,
            input: GitInvocation.scratchIndexInput(tracking: destinations, emptyBlob: objectId),
            environment: environment,
            requiresZeroExit: true
        )
        return try await invoke(
            command,
            in: location,
            arguments: GitInvocation.arguments(for: command),
            input: nil,
            environment: environment
        )
    }

    private func invoke(
        _ command: GitCommand,
        in location: RepositoryLocation,
        arguments rawArguments: [[UInt8]],
        input: Data?,
        environment: [String: String?],
        requiresZeroExit: Bool = false
    ) async throws(GitError) -> GitOutput {
        let arguments = Arguments(Self.terminated(rawArguments))
        let overrides = Dictionary(uniqueKeysWithValues: environment.map {
            (Environment.Key(stringLiteral: $0.key), $0.value)
        })

        let terminationStatus: TerminationStatus
        let outcome: Outcome
        do {
            // The input type is part of the execution's type.
            if let input {
                let result = try await Subprocess.run(
                    .path(FilePath(executablePath)),
                    arguments: arguments,
                    environment: .inherit.updating(overrides),
                    workingDirectory: FilePath(location.path),
                    input: .data(input),
                    output: .sequence,
                    error: .sequence,
                    body: { execution in try await drain(execution, command: command) }
                )
                terminationStatus = result.terminationStatus
                outcome = result.closureResult
            } else {
                let result = try await Subprocess.run(
                    .path(FilePath(executablePath)),
                    arguments: arguments,
                    environment: .inherit.updating(overrides),
                    workingDirectory: FilePath(location.path),
                    input: .none,
                    output: .sequence,
                    error: .sequence,
                    body: { execution in try await drain(execution, command: command) }
                )
                terminationStatus = result.terminationStatus
                outcome = result.closureResult
            }
        } catch let error as SubprocessError {
            throw Self.mapped(error, location: location)
        } catch {
            throw .gitUnavailable(reason: "\(error)")
        }

        if outcome.timedOut {
            throw .timedOut(command: command)
        }

        let standardError = String(decoding: outcome.standardError, as: UTF8.self)
        // A truncated run was torn down on purpose, so its termination status describes our own
        // signal rather than anything git decided. Judging it would turn every large diff into a
        // failure.
        if outcome.isTruncated == false {
            switch terminationStatus {
            case .exited(let code):
                guard requiresZeroExit ? code == 0 : GitInvocation.accepts(exitCode: code, from: command) else {
                    throw .commandFailed(command: command, exitCode: code, standardError: standardError)
                }
            case .signaled(let signal):
                throw .terminatedBySignal(command: command, signal: signal, standardError: standardError)
            }
        }

        return GitOutput(
            standardOutput: outcome.standardOutput,
            isTruncated: outcome.isTruncated,
            standardError: standardError,
            isStandardErrorTruncated: outcome.isStandardErrorTruncated
        )
    }

    /// The argument vector with a zero byte on the end of every element.
    ///
    /// **The byte-array form of `Arguments` hands each element straight to `strdup`, which reads on
    /// until it meets a zero byte.** A Swift array carries its length beside it and nothing after
    /// it, so an element without a terminator is copied out of the array and on into whatever the
    /// allocator happened to leave next to it — the argument git receives is the one we built plus a
    /// run of unrelated bytes, and which arguments it happens to and on which run depends on the
    /// heap.
    ///
    /// **It is a silent corruption in the one place it matters most.** Everything after `--` is a
    /// pathspec, and a pathspec that matches nothing makes git print nothing, write nothing to
    /// standard error and exit 0 — which reads exactly like a file with no changes. Measured on a
    /// real worktree of ten changed files: two of them served an empty diff on every request, while
    /// the change set that named them was correct, because the commands that build it carry no path.
    ///
    /// The string form is safe — Swift hands a `String` to a C API already terminated — so this is
    /// only needed because paths are bytes. Terminating twice would be harmless in the other
    /// direction; `strdup` stops at the first zero either way.
    static func terminated(_ arguments: [[UInt8]]) -> [[UInt8]] {
        arguments.map { $0 + [0] }
    }

    /// Reads both streams at once and holds the clock over them.
    ///
    /// Both, concurrently, because a macOS pipe buffers 64 KiB and the cap above permits two
    /// megabytes: draining standard output to its end before touching standard error leaves git
    /// blocked writing a complaint nobody is reading, and the app blocked waiting for an exit that
    /// cannot happen. That is a hard hang on exactly the large diffs the guards exist for.
    private func drain<Input: InputProtocol>(
        _ execution: Execution<Input, SequenceOutput, SequenceOutput>,
        command: GitCommand
    ) async throws -> Outcome {
        try await withThrowingTaskGroup(of: Drained.self, returning: Outcome.self) { group in
            group.addTask {
                let read = try await Self.collect(
                    execution.standardOutput,
                    limit: GitInvocation.outputLimitBytes(for: command, whenDiffing: outputLimitBytes)
                )
                if read.isTruncated {
                    // Stopping the read is only half of enforcing the cap. Git is still writing,
                    // and a pipe nobody empties blocks it forever, so the process goes too.
                    await execution.teardown(using: [
                        .gracefulShutDown(allowedDurationToNextStep: Self.terminationGrace)
                    ])
                }
                return .standardOutput(read)
            }
            group.addTask {
                .standardError(try await Self.collect(
                    execution.standardError,
                    limit: Self.standardErrorLimitBytes
                ))
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return .timerStopped
                }
                // Never to the process group: a child spawned by the standard process API inherits
                // this process's own group, so signalling the group signals the menu bar app.
                await execution.teardown(using: [
                    .gracefulShutDown(allowedDurationToNextStep: Self.terminationGrace)
                ])
                return .timedOut
            }

            var standardOutput: Read?
            var standardError: Read?
            var timedOut = false
            while let drained = try await group.next() {
                switch drained {
                case .standardOutput(let read): standardOutput = read
                case .standardError(let read): standardError = read
                case .timedOut: timedOut = true
                case .timerStopped: break
                }
                if standardOutput != nil, standardError != nil {
                    group.cancelAll()
                }
            }

            return Outcome(
                standardOutput: standardOutput?.bytes ?? Data(),
                isTruncated: standardOutput?.isTruncated ?? false,
                standardError: standardError?.bytes ?? Data(),
                isStandardErrorTruncated: standardError?.isTruncated ?? false,
                timedOut: timedOut
            )
        }
    }

    private static func collect(_ stream: SubprocessOutputSequence, limit: Int) async throws -> Read {
        var bytes = Data()
        for try await buffer in stream {
            buffer.withUnsafeBytes { bytes.append(contentsOf: $0) }
            // Strictly more, so output that lands exactly on the limit is complete rather than
            // reported as a prefix of itself.
            if bytes.count > limit {
                return Read(bytes: Data(bytes.prefix(limit)), isTruncated: true)
            }
        }
        return Read(bytes: bytes, isTruncated: false)
    }

    private static func mapped(_ error: SubprocessError, location: RepositoryLocation) -> GitError {
        if error.code == .failedToChangeWorkingDirectory {
            return .workingDirectoryUnreadable(location: location, reason: error.description)
        }
        return .gitUnavailable(reason: error.description)
    }
}

/// What one stream produced, and whether that is all of it.
private struct Read: Sendable {
    let bytes: Data
    let isTruncated: Bool
}

private enum Drained: Sendable {
    case standardOutput(Read)
    case standardError(Read)
    case timedOut
    case timerStopped
}

private struct Outcome: Sendable {
    let standardOutput: Data
    let isTruncated: Bool
    let standardError: Data
    let isStandardErrorTruncated: Bool
    let timedOut: Bool
}
