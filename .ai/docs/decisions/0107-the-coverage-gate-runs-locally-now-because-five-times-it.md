# The coverage gate runs locally now, because five times it was read from a red pull request

**The measurement script always ran anywhere; nothing fetched `main`'s numbers or applied the
verdict.** So the only way to learn what the gate would say was to push and wait, and five times that
is exactly what happened — twenty minutes each to obtain a number that was computable in the working
tree the whole time. Davide named the waste directly; `make coverage` is the answer.

It is not an approximation of the gate. It fetches the last green `main` run's summary, runs
`.github/scripts/measure-coverage.sh`, and hands the result to the same `render` and `enforce` the
workflow calls — same predicates, same ratchet, same exit code and same message. Verified on
2026-08-24: the local numbers and the runner's agreed **to the line on all six rows**, twice.

**The baseline arrives as a new `coverage-summary` artifact**, a few hundred bytes beside the
existing `coverage-exports`, which is ~300 MB — and `gh run download` cannot fetch one file out of an
artifact, so without the small one every local check would pull all of it. Runs predating it fall
back to the big one rather than refusing, which is what keeps the target usable on the very branch
that adds it.

**What a tool cannot supply is what to cover, so the skill gained that too**, keyed to what a region
actually is: every `guard`/`if let` failure branch, every `??`, every new `case`, every computed
property or static factory asserted **directly** rather than incidentally, and every fallback a view
draws needing a snapshot subject of its own. Each was a real miss on this branch — `FileStoreLock`'s
refusals, `StoreLockHolder.sentence`, `.thisProcess`, and three `?? "another process"` strings
argued for in a comment and rendered by nothing.

