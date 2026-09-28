# Loading describes observed stages, and a receipt survives a refused refresh

On 13 September 2026 the return for [issue #82](https://github.com/fardavide/granita/issues/82)
kept Apple's stock activity indicator and added the facts the phone can observe: discovery,
pinned health verification, and waiting for the complete worktree response. The durable layout
and copy are in [design §8](../design.md). An unknown route stays unknown, including the legacy
fallback that has not completed pinned health; it cannot say the Mac is verified. Concurrent
routes advance to the furthest observed stage and never move backwards within an attempt.

Each read owns its progress, completion and elapsed clock. A replacement read cancels its
predecessor; late progress, errors and completion from that predecessor cannot mutate the new
attempt. Leaving the screen or opening a worktree cancels the read even when the iPad sidebar
remains visible. A late refusal after cancellation is still cancellation, rather than a failure
screen or a revoked pairing. The clock measures the whole attempt and freezes when it ends.
Ten seconds changes the explanation; it is neither a timeout nor a processing estimate.

Both running and completed elapsed labels use that attempt's supplied clock. The screen already
samples it once per second. A native independently running text timer ignored the supplied time;
an accessibility snapshot exposed it displaying 0:00 for an attempt that had lasted 42 seconds.
Using the same clock for the label and the long-wait threshold also keeps the elapsed value
available to VoiceOver on demand without announcing each tick.

A successful read keeps its arrival time and verified route. Refresh retains usable content and
its receipt, and a recoverable failure makes that content's age explicit above the rows. Retry
clears the old notice and shows stock activity while leaving those rows operable. Authorization
refusal replaces the content and opens this Mac's real pairing entry when Pair Again is pressed.
VoiceOver receives one polite announcement per stage, the actual arrival count, and a refresh
failure; the elapsed timer is available on demand rather than announced every second.

Fresh server profiling on five enabled projects and ten worktrees measured 5.843 seconds for a
complete read, with 5.828 seconds inside git calls. Change metadata took 3.438 seconds and status
2.153 seconds; enumeration took 0.054 seconds. A separate verified loopback health exchange took
0.0117 seconds including connection setup. These are different scopes, not a subtraction that
isolates remote latency. [The measurements and limits](../loading-profile-82.md) preserve both.
No optimization is selected from this sample: it neither reproduces the old 122.7-second run nor
isolates project count, worktree count and changed-file cost. The profiler makes a later controlled
comparison possible without replacing truthful loading feedback with an invented percentage.

