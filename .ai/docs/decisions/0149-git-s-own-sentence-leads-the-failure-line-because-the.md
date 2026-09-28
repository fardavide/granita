# Git's own sentence leads the failure line, because the unified log truncates

A failed invocation logged `"\(command) failed: \(error)"`, and `GitCommand` carries its paths. Eleven
of them, rendered as `RepositoryRelativePath(bytes: 36 bytes)` and then repeated inside the error's
own `commandFailed(command:)`, ran past the unified log's kilobyte limit **before reaching git's
standard error** — the one part written for a person, and the part `swift-style` says a git failure
exists to carry.

The line leads with git's sentence and trails the command, and `RepositoryRelativePath` describes
itself as the path. Measured rather than reasoned: the symlink above had to be reproduced by hand
because its stderr never reached the log.

