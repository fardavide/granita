---
name: build-and-test
description: Builds and tests Granita through its sanctioned package, app, and coverage commands. Use when the user asks to build, test, verify, or prepare Granita for a PR.
when_to_use: Use when the user asks to build, test, verify, or prepare Granita for a PR.
user-invocable: true
---

Run each command bare, one per call. Never pipe a build or test run through `grep`, `tail` or `head`
to read its result — the exit status becomes the filter's. Read the captured output instead.

## Every change

```bash
make test     # package test suite, on the host, no simulator
make build    # compile-check the package and both app targets, unsigned
```

Report the real output, not a summary of it.

## Before opening a pull request

If the change adds code:

```bash
make coverage # the same verdict CI gives — main's baseline, the same script, the same predicates
```

Diagnose a fallen row by reading `build/coverage/{unit,snapshot,all}.json`, which it leaves behind.
Do not estimate which file moved. Query those files with `jq`, never an interpreter. See the
`swift-testing` skill for what to cover as you write it.

If the change touches a screen:

```bash
make snapshots-ios  # phone baselines; run twice when adding a state — the first run writes, the second verifies
```

Then run both apps, whichever half the change touched:

```bash
make run-mac           # the menu bar server, signed for this machine
make run-client-mac    # the Client on macOS — the one that can press things
```

Press the control the change adds. See the `design` skill's dead-control rule.

## Before diagnosing any symptom

Establish which versions are running. The two halves ship separately and a stale server answers a
new client's routes with 404.

```bash
pgrep -fl -i granita
defaults read /Applications/Granita.app/Contents/Info CFBundleShortVersionString
```

## Other commands

`make help` lists everything. The ones that matter day to day:

```bash
make project           # regenerate Granita.xcodeproj after editing project.yml
make fixtures          # rebuild the git fixture repos and the golden diff corpus
make icons             # regenerate both app icon sets from Art/icon/*.svg
make verify-generated  # what CI's "Generated files" job runs
make run               # run the backend in a terminal
```

## Rules

- Use these commands only. When one fails, report its exact output and hand back; never substitute a
  raw `xcodebuild` or `swift` invocation.
- Never hand-edit `project.pbxproj`. Edit `project.yml`, run `make project`, and commit the
  regenerated project.
- Never hand-edit `Packages/Granita/Package.resolved`. Different resolvers write different graphs
  into it; check its diff before committing and drop churn that is not part of the change.
- Leave `make build` unsigned.
- Show the output before claiming a command passed. If tests fail, say so and quote them.
- Run the apps before opening the pull request, not after a bug report.

## Landing a change

`main` is PR-gated by the `protect-main` ruleset: squash only, linear history, all **seven** required
checks green, no bypass for anyone including Davide.

```bash
git switch -c <type>/<slice>
git push -u origin <type>/<slice>
gh pr create --fill
gh pr checks --watch      # exits non-zero on failure; this is the gate
gh pr merge --squash
```

- When the merge is refused as out of date, update the branch through GitHub:

  ```bash
  gh api -X PUT /repos/fardavide/granita/pulls/<n>/update-branch
  ```

- Never rebase or force-push a branch that is already on the remote with checks attached. It discards
  the checks and can clobber another push. Rebase local work only.
- Never run `gh pr merge --admin`. Fix the red check.
- Never arm auto-merge. Watch the checks, then merge explicitly.
