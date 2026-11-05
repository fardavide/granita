# Recover the main coverage baseline after a cache miss

The Coverage job restores its cache, then runs the existing baseline-retrieval helper for pull
requests before reporting or enforcement. A cache hit remains local; a miss downloads the last
successful main run's saved summary. Retrieval failure stops the job. The job grants read access
to Actions artifacts and supplies its existing GitHub token to the helper.

[The diagnostic retry](https://github.com/fardavide/granita/actions/runs/41991535563) passed all
functional suites on the unchanged reconnection commit, but its report explicitly said no baseline
existed and nothing was enforced. Manual runs also do not replace the pull request's required
checks. A green workflow alone was therefore insufficient evidence of a passing PR coverage gate.

A workflow regression starts with an empty cache and runs the real acquisition, report and
enforcement commands against a controlled GitHub CLI. It covers both an available saved baseline
with four regressing Unit/All values and failed artifact retrieval. Before the workflow correction,
both cases failed and 140 tooling tests passed; afterwards all 142 pass.

Coverage predicates, scopes, numeric ratchets, the first-main-run bootstrap, and all native
interaction assertions remain unchanged. The two original remote interaction failures did not
reproduce in 68 focused local executions, 582 instrumented shard executions or the full diagnostic
retry. Their cause remains unverified; no rendering repair is claimed. Required PR CI must run
again with baseline recovery enabled.
