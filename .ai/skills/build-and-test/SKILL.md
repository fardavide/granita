---
name: build-and-test
description: Builds and tests Granita through its sanctioned commands and verifies the signed Mac app installed in Applications. Use when building, testing, installing a local Mac build, or preparing Granita for a PR.
when_to_use: Use when the user asks to build, test, verify, install a local Mac build, or prepare Granita for a PR.
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

### Installed Mac preflight

Before opening a pull request that updates Granita, get session approval for the Mac install and
restart. Name the app and the interruption to active reviews. Then follow this order.

1. Record the installed version and running Granita PIDs. Use `ditto` to make a rollback copy of
   `/Applications/Granita.app` at a fresh path. Verify that the backup has the installed version
   and passes `codesign --verify --deep --strict`.
2. Run `make run-mac` from the proposed revision. It builds and opens the worktree bundle at
   `.build/mac/Build/Products/Debug/Granita.app`. Check that bundle's version and signature before
   interrupting the installed app.
3. Send `SIGTERM` to the verified Granita PIDs and wait for exit. Before replacing the installed
   bundle, confirm that both the installed and worktree-built Granita processes have exited and
   that port 8737 is free. If an instance closes its listener but stays alive, resolve that
   process before continuing.
4. Move the old bundle aside and use `ditto` to install the complete signed build at
   `/Applications/Granita.app`. Verify the installed signature and version, then run
   `open /Applications/Granita.app`.
5. After launching the installed bundle, match the listener PID to the new process and check
   the version returned by `/v1/health`. Use `lsof -nP -a -iTCP:8737 -sTCP:LISTEN` to find the
   PID and `ps` to confirm that it started after the restart from
   `/Applications/Granita.app/Contents/MacOS/Granita`. Check
   `https://127.0.0.1:8737/v1/health` for the expected `serverVersion`. If relying on
   `curl --insecure` for the self-signed certificate, limit that check to loopback health
   without credentials. If the installed app cannot be verified, stop the failed instance
   and confirm its exit. Restore the rollback bundle and verify that the previous version is
   serving again.

Exercise the changed behavior on the installed build. For a change to the Mac server, exercise it
from a paired iPhone and report that result separately from the Mac health check.

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
- After package validation, run `make resolve` to regenerate the Xcode union lockfile at
  `Packages/Granita/Package.resolved`. Review resolver-produced changes; do not hand-edit or restore
  `Package.resolved` merely to clean the worktree.
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
