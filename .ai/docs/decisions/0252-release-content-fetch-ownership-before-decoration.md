# Release content-fetch ownership before decoration

A content batch owns its in-flight IDs through repository fetching and publication of ready
entries. Its lexical cleanup ends before asynchronous syntax highlighting and image loading.
Those later operations keep their existing stale-result guards. No new generation counter,
public API or snapshot preparation path is introduced.

[CI 387](https://github.com/fardavide/granita/actions/runs/40746642387) fails the Mac snapshot
subject that reads a remote Mac while this Mac is blocked: all five expected ready entries
remain awaiting. There is no captured image mismatch for this failure. Merely extending the
readiness timeout cannot resolve the ownership race.

The mounted screen starts loading, and its reading callback starts a content batch. That batch
publishes ready entries, then awaits highlighting. Previously its deferred in-flight cleanup
still held the IDs. A second load resets entries to placeholders, but its awaited reading
request deduplicates against those IDs and returns. Completing the older highlight releases
the IDs without republishing or refetching the new placeholders.

Two controlled tests hold the first highlight after verifying ready source content. Reloading
at that point reproduces the failure; the no-reload control passes. With the lexical ownership
repair, both cases finish with all five ready entries and every expected line highlight. The
holding fake uses an owned cancellation-aware stream, and the tests join their tasks. Request
counts and intermediate placeholder states are diagnostic attachments rather than required
implementation details.

The two controlled cases, all157 related model tests and the complete package suite pass
locally. The original Mac snapshot setup, readiness deadline and assertions remain unchanged.
Native Mac confirmation and required remote checks remain pending.

[CI 388](https://github.com/fardavide/granita/actions/runs/40757911022), at `287a651`, subsequently
passes the complete Mac snapshot suite and package tests. The original readiness fixture and
assertions are retained. Its remaining iOS motion failures are a separate investigation.
