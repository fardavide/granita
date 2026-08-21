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

    /// SPEC §5.1's budget for one invocation.
    public static let defaultTimeout = Duration.seconds(10)

    /// Standard error is a sentence for a person, not a payload. A git that will not stop writing
    /// to it should not be able to fill this process's memory with the complaint.
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
        let overrides = Dictionary(uniqueKeysWithValues: GitInvocation.environmentOverrides.map {
            (Environment.Key(stringLiteral: $0.key), $0.value)
        })

        let terminationStatus: TerminationStatus
        let outcome: Outcome
        do {
            // Two shapes of the same call, because only one command reads standard input and the
            // input type is part of the execution's type rather than a value it carries.
            if let standardInput = GitInvocation.standardInput(for: command) {
                let result = try await Subprocess.run(
                    .path(FilePath(executablePath)),
                    arguments: Arguments(GitInvocation.arguments(for: command)),
                    environment: .inherit.updating(overrides),
                    workingDirectory: FilePath(location.path),
                    input: .data(standardInput),
                    output: .sequence,
                    error: .sequence,
                    body: { execution in try await drain(execution, command: command) }
                )
                terminationStatus = result.terminationStatus
                outcome = result.closureResult
            } else {
                let result = try await Subprocess.run(
                    .path(FilePath(executablePath)),
                    arguments: Arguments(GitInvocation.arguments(for: command)),
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
                guard GitInvocation.accepts(exitCode: code, from: command) else {
                    throw .commandFailed(command: command, exitCode: code, standardError: standardError)
                }
            case .signaled(let signal):
                throw .terminatedBySignal(command: command, signal: signal, standardError: standardError)
            }
        }

        return GitOutput(standardOutput: outcome.standardOutput, isTruncated: outcome.isTruncated)
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
                let read = try await Self.collect(execution.standardOutput, limit: outputLimitBytes)
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
    let timedOut: Bool
}
