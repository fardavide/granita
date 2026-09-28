# Remembered routes race verified HTTPS rather than waiting for Bonjour

On 12 September 2026 Davide confirmed the TLS correction works on his phone but estimated opening
his Mac over cellular took over thirty seconds, possibly a minute. The local resolver can spend
five seconds on each of four Bonjour attempts, plus two-, five- and eight-second wake waits, before
the old remembered connection even tries its saved tailnet address. This is a code-derived delay,
not a new phone measurement.

For a remembered Mac with a tailnet endpoint, start pinned HTTPS health immediately. Physical Wi-Fi
availability permits a concurrent local discovery/wake route; on cellular that route is skipped.
The first completed pinned HTTPS health exchange wins and cancels the losing route. A resolved
Bonjour address alone is not sufficient. Cancelling a losing lookup must not send wake packets.
Wi-Fi availability is not proof the Mac is nearby, and no location or Bluetooth permission is added.
First pairing remains local and neither the Tailscale application nor server identity is changed.

Pinned probe sessions are reused per fingerprint with both native inactivity and resource deadlines
set to five seconds. Source-reading sessions keep their existing limits: a busy server must not lose
an otherwise valid large worktree response merely because health probes need a shorter bound.
The existing best-effort metadata refresh uses a bounded pinned session too.

The phone journal records typed semantic discovery/verification stages and typed HTTP method timing,
with monotonic elapsed durations and explicit success, failure, cancellation or skip outcomes. These
are phone-observed intervals, not isolated server processing measurements; credentials, bodies and
source remain excluded. The loading animation and large-worktree performance investigation are
tracked separately in [issue #82](https://github.com/fardavide/granita/issues/82), not implemented here.

