# The Projects row costs two different amounts, and the expensive half is filled in rather than dropped

Design §4 draws the trailing figure as two lines — `4 worktrees` over `2 with changes` — and says it
comes from `Project.worktreeCount` and `dirtyWorktreeCount`, "which already exist". They do. What
the review could not know is that the second one had not been timed yet, and when it was, on 22
August 2026, the answer was **122.7 seconds** across ten real repositories. That measurement killed
the menu bar count. It arrives at this tab too, and the review's own sentence says why it must:
the figure is "what reconciles this tab with the number in the menu bar", and there is no number in
the menu bar.

**So the cheap question was measured before anything was decided.** `WorktreeRegistry.projects()`
builds a whole change set per worktree — every changed path, its stats, its revision, a hash of every
changed file — to evaluate one boolean. Git can answer "is anything different here" with one
invocation. On 23 August 2026, against Davide's `bandlab-android` monorepo and its sixteen worktrees:

| | wall clock, warm |
|---|---|
| `git status --porcelain`, per worktree | **16.7 s** for sixteen |
| `git diff-index --quiet HEAD`, per worktree | 8.0 s for sixteen |
| `git worktree list --porcelain -z`, whole project | **0.014 s** |

Two orders of magnitude cheaper than the change set, and still about a second per worktree. One
monorepo alone is longer than anybody waits for a settings pane.

**Davide chose to fill it in progressively**, on 23 August 2026, over dropping the second line
entirely and over computing both before drawing. So the tab reads the store and the worktree counts,
draws the whole list, and *then* walks the visible projects asking the cheap question, each answer
landing in the row it belongs to. What that beats:

- **Dropping `2 with changes`.** It was the recommendation and it lost on what the line is for: the
  worktree count says how much is behind a switch, and only the second line says whether there is
  anything to read. A row that cannot answer that is a row about filing rather than about work.
- **Computing both before drawing.** A pane that is blank for a minute on ten repositories, every
  time it is opened.

**Three things make the progressive fill honest rather than merely deferred.** The second line is
drawn as `checking…` rather than left absent, so nothing below it moves when the answer lands — this
is a list a reader is aiming a switch at. The expensive question is asked **only of projects that are
switched on**, because a switched-off row says `not visible` and has nowhere to put a count. And the
walk is cancelled with the tab's own `.task`, so leaving Projects stops the git invocations rather
than running them into a list nobody is looking at.

**The cheap question is `worktreeStatus`, a command the vocabulary already had**, so no case was
added to `GitCommand`. `status` prints nothing at all when there is nothing to report, which makes
the boolean "did it print". It agrees with the change set by construction rather than by coincidence,
because it is the same command with the same untracked mode — and that matters: `diff-index --quiet`
is faster and answers *no* for a worktree holding nothing but new files, which is precisely what an
agent leaves behind.

