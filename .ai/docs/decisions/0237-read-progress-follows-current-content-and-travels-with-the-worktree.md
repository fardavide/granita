# Read progress follows current content and travels with the worktree

The 29 September 2026 design return puts one viewed-file fraction beside the file selector's title
and another under each worktree's age. The Mac already builds each worktree's change set while listing
it; handing the stored marks into that build makes the count of matching content hashes available
without another git process. Counting stored marks directly was rejected because a mark whose file
changed must expire, and deriving every row on the client was rejected because the client has only
the open worktree's change set.

The wire field is optional. An older Mac omits it, and the client keeps that row's old second line
instead of drawing a false zero. A successful local mark changes both displays immediately; a refused
mark rolls both back with the existing alert. Re-reading every worktree after each mark was rejected
because it rebuilds every change set on every tap. The next ordinary list read replaces the local
count with the Mac's current answer. The screen calls, including the quiet finished row and the
zero-state rule, are in [`design-read-progress.md`](../design-read-progress.md).

Davide's follow-up the same day put the fraction in the diff's Files toolbar button too, including
zero. The original returned call left the button as a file total, but that hid progress while the
reader was actually in the diff. The button still opens the selector, and the model derives its title
from the same listing used by the selector so optimistic marks and rollbacks change both together.
