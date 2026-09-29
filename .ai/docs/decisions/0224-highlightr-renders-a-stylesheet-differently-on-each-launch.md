# Highlightr renders a stylesheet differently on each launch, and it took two of five themes off the list

Issue [#70](https://github.com/fardavide/granita/issues/70)'s design return specified five theme pairs
behind a published filter: both halves in the bundle, each half legible on our card, every colour past
4.5:1 there, and mean chroma at or below Xcode's. **Three ship.** *Accessible* and *GitHub* are absent,
and the criterion that removed them is not in the return because it is not a property of the CSS — it
is a property of the library that reads it.

**`Highlightr.Theme` keys CSS rules by selector in a `Dictionary`, understands neither `@media` blocks
nor descendant selectors, and reduces `.hljs-meta .hljs-keyword` onto the bare `.hljs-keyword`.** So a
stylesheet declaring one role more than once with different values has no defined answer: the winner
falls out of a dictionary iteration order Swift randomises per process. `a11y-light` states
`.hljs-keyword{color:#7928a1}` and then `.hljs-keyword{font-weight:700}`, and redeclares comment, string
and type inside `@media (-ms-high-contrast:active)`; `github` has three declarations reducing to
`.hljs-keyword` and two to `.hljs-string`.

**It was observed before it was explained**, which is the only reason it was caught at all. Lexing the
sample in two separate processes returned two different palettes for *Accessible*, and a third run
moved *GitHub*'s keyword. Reading the CSS had already produced two wrong conclusions before that —
first that only bare duplicate selectors collide, then that descendant selectors never do — and both
survived a plausible-sounding argument. The stable three were then confirmed by four consecutive runs.

**What this costs.** *Accessible* was the pair the return argued hardest for, being the only one drawn
against a contrast target, and `SPEC.md` §10's colourblind-safe palette had been flagged as possibly
one setting with it. That option is gone until either Highlightr's parser improves or Granita ships the
stylesheet itself.

**What it buys.** The filter now has a fifth criterion that is checkable and that no amount of reading
the CSS would have produced: *the stylesheet renders the same colours on every launch.* Any future pair
has to pass it, and `CodeThemePaletteTests` is where it fails if one does not — the palettes are frozen
in `CodeTheme` and asserted against the real lexer, so a stylesheet that starts disagreeing with the
table says so in a test rather than in a preview that lies.

**The two general lessons.** A dependency's documented data is not its behaviour, and a table frozen
from a dependency needs a test that re-derives it rather than a comment claiming it was checked. And
a non-deterministic failure looked exactly like a mis-transcribed constant for three rounds: the tell
was two runs of the same unchanged code disagreeing, not anything in the values themselves.

