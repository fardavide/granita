# Cancelled resolution cannot publish a remembered connection

On 26 October 2026 a phone report showed local discovery being cancelled, followed by a request
to the saved Tailscale address, one immediate cancellation, and a second request that timed out
after 61 seconds. The phone could read health directly over the LAN, and returning to the Mac
list and selecting the Mac restored the connection. Those observations do not establish why
the first local lookup failed to finish.

Two deterministic repository tests reproduce a client defect independently of that unknown.
A cancelled resolver can report an unreachable result, which the remembered connection turns
into its saved fallback. A resolver that returns success after cancellation can also open and
cache a connection; the next read then reuses an answer from the cancelled attempt.

Cancellation is checked before handling a resolution failure, so it cannot select a fallback.
It is checked again after resolution and its observed route have been read. Connection creation
and cache storage follow that final check without an intervening suspension. Both paths throw
the existing cancellation failure; genuine resolution failures keep their existing fallback
behavior. The change adds no transport policy, discovery retry or timeout.

The regressions assert that cancellation opens no connection, and that a subsequent read resolves
afresh after a late successful answer. They use explicit resolver rendezvous rather than sleeps.
