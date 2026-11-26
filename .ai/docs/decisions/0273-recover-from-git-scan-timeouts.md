# Recover from Git scan timeouts

On 26 November 2026, local Git status and diff commands exceeded Granita's ten-second deadline in
several registered worktrees. A direct status read also reported a filesystem-monitor IPC failure.
Granita disables the monitor on its own Git invocations. The command override stays local to
each invocation so other tools can keep their repository setting.

The registry retries timed-out scans with increasing delay capped at thirty seconds. It retains
the previous successful scan and retries the affected checkout or project. A successful scan
publishes a recovered row. A failed open diff for that checkout reloads on recovery, including
when the content revision is the same. The existing Try Again control requests an immediate read.
The snapshot keeps the general Git failure code alongside the timeout detail for older readers.

The Mac's Copy Logs includes bounded, session-local Git failure summaries. It shares fixed
command names and error codes. Detailed stderr remains available in the Mac's system log.
