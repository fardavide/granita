# A failure carries a diagnostic, not advice

`DiscoveryState.failed` used to carry `error.localizedDescription`, and the discovery screen put it
in the one line a reader acts on. That handed the screen's advice to Network.framework, which writes
"The operation couldn't be completed" — true of every failure there has ever been, actionable in
none of them.

The payload is now labelled a **diagnostic** and rendered at the bottom in small monospaced
selectable print, with the raw `NWError` code appended, while the description above it is ours and
fixed. The code is the only part of that string anyone can act on, and the reader of this app is the
developer of it.

Rejected: hiding the diagnostic behind a disclosure, which is a tap to reveal four words nobody can
use; and an alert, which demands an answer to a question the reader was not asked and leaves the
same empty screen behind it. This is a state of the screen, not an interruption.

### A defunct connection while *waiting* now reports searching, not failure

The design asks for policy errors to be routed away from the failure state and rendered as a
refusal. Applied literally to the waiting path that would re-open the bug 0.0.4 fixed: a defunct
connection is the code that means *either* a refusal seen by a browser that was not the app's first
*or* a process that has just been resumed, and telling those apart is what the death counting is
for. Reporting it as either verdict from the waiting path reaches the screen ahead of the counting.

So the waiting path stays silent on that one code and reports searching, which is what is actually
true; the death path still counts, and three deaths in a row is still a refusal. The literal reading
of the design would have accused a reader of a setting they did not change, which is the exact
failure `BrowserRestartPolicy` exists to prevent.

