---
description: Build and test Granita the sanctioned way — package tests, then both app targets.
---

Run these, in this order, and report the real output rather than a summary of it.

```bash
make test     # package test suite, on the host, no simulator
make build    # compile-check the package and both app targets, unsigned
```

`make help` lists everything else. The ones that matter day to day:

```bash
make project           # regenerate Granita.xcodeproj after editing project.yml
make fixtures          # rebuild the git fixture repos and the golden diff corpus
make icons             # regenerate both app icon sets from Art/icon/*.svg
make verify-generated  # what CI's "Generated files" job runs
make run               # run the backend in a terminal
```

## Rules

- **These are the sanctioned commands.** If one fails, that failure is the problem to solve — report
  it with the exact output and hand back. Do not reach past it to a raw `xcodebuild` or `swift`
  invocation to get a change through; that produces work that silently did not follow the project's
  rules.
- **Never hand-edit `project.pbxproj`.** Edit `project.yml` and run `make project`. The generated
  project is committed, so the regenerated result is part of the change.
- **`make build` builds unsigned deliberately.** A compile check needs no signed binary, and CI has
  no identity.
- **Verify before saying done.** "Builds and tests pass" is a claim; the command output is the
  evidence. If tests fail, say so and show them.

## Landing a change

`main` is PR-gated by the `protect-main` ruleset — squash only, linear history, all four checks
green, and no bypass for anyone including Davide.

```bash
git switch -c <type>/<slice>
git push -u origin <type>/<slice>
gh pr create --fill
gh pr checks --watch      # exits non-zero on failure; this is the gate
gh pr merge --squash
```

- Rebase onto `main` if the merge is refused as out of date — never merge `main` in, since linear
  history rejects the merge commit.
- `gh pr merge --admin` will fail. There is no bypass; the answer is to fix the red check.
- Do not arm auto-merge. Watch the checks, then merge explicitly.
