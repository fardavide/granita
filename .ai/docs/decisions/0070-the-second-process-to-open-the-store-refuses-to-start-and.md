# The second process to open the store refuses to start, and names the first

SPEC §9 asks for a lock file beside the document so a standalone `granita-server` and the menu bar
app cannot both hold it, and says the second one refuses "with a clear message". The review left the
held case undrawn on purpose and said why — refuse, or serve read-only, is a product question rather
than a drawing. Davide answered on 22 August 2026: **refuse.**

Read-only is the option it beat, and it loses on a specific failure rather than on principle. Both
processes read the same document to decide what is enabled; a read-only second process would go on
answering with a snapshot the first one has since changed, so the phone would be served a stale
answer to the one question that is the security boundary — which projects are visible. Neither the
phone nor the reader is told which process answered. A refusal is legible; a quiet disagreement about
what is enabled is not.

The refusal **names the process holding the lock**, and that is the part worth writing down. "Another
copy of Granita is already running" is a sentence with no next action, and the case that produces it
is usually a `granita-server` left in a terminal behind a window. A process identifier can be looked
up and killed.

