# The menu bar count costs 122.7 seconds, so there is no menu bar count

The design review declined to draw the dirty-worktree count until someone had timed it, and offered
two branches: tens of milliseconds meant cache it and refresh on a slow timer, seconds meant put the
number behind opening the menu and leave the label as the icon alone. It was measured on 22 August
2026 against ten of Davide's real repositories — 38 worktrees, one Android monorepo carrying 16 of
them — by serving them and reading `/v1/projects`, which is `WorktreeRegistry.projects()` plus a JSON
encode.

**122.7 seconds.** Neither branch survives. A menu that computes this on open is a menu that does not
open, and a cache on a slow timer would keep 38 git processes running for two minutes out of every
period, on a laptop, for a number nobody asked for.

So the count is not built. What it beat was the third option, which was to build it anyway behind a
cache and a spinner — that spends the worst cost this app has on the one surface that is supposed to
be glanced at, and SPEC §9's own framing is that the menu bar answers whether the phone can read this
Mac. The symbol already answers that.

**The number is not the finding; the shape of the question is.** `projects()` computes a whole change
set per worktree — every changed path, its stats and its revision — in order to evaluate
`files.isEmpty == false`. Git can answer "is anything different here" without producing any of it.
The count becomes affordable the day something asks the cheap question, and that is a change to the
git layer rather than to the menu, so it is not in this slice.

Recorded rather than left in a commit message because it is a measurement, and the next session to
look at the menu bar will otherwise re-open it exactly as this one nearly did.

