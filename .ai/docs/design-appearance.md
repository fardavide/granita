# The app's appearance, and the colours the code is lexed in

The design return of 19 September 2026, drawn against 0.15.1 for issue
[#70](https://github.com/fardavide/granita/issues/70) and built in 0.16.0. **The frames were never
archived**, because the return was built in the session it arrived in and
[`design/README.md`](design/README.md) keeps drawings only while they are waiting on one — so this
document is the whole record. The original is in the Claude Design project at
`https://claude.ai/design/p/7a8bd161-884b-4993-9c88-0b09f1cd625e`.

It extends the sheet [`design-review-settings.md`](design-review-settings.md) drew, which had already
reserved the place: *"The highlighting theme, when #70 lands, is a fourth section and is this phone's,
not the Mac's."*

## The rule the whole return is drawn from

**The reader is choosing a drawing, so every surface shows the drawing and none shows a name on its
own.**

That is also what makes this section the only one on the sheet that cannot fail: nothing it displays
is fetched, computed at open, or capable of being stale. There is no queued state, no amber dot, no
disabled spelling, and no version of it waiting for anything. The three sections above it are that
Mac's; these two rows are this device's.

## Both halves are on screen at all times

The question the ask was written around — how does a reader see the half of a pair their phone is not
currently showing — has a one-line answer, and it comes out of the code rather than out of a layout.
`SyntaxHighlighter.highlight(_:as:for:)` has taken the appearance as a parameter since 0.8.0, so
drawing the half this phone is not in has never required the phone to be in it.

So **the reader never toggles anything**: every theme, everywhere it appears, is two small samples
side by side, light on the left and dark on the right, in both appearances and at both forced
settings. The half the phone is currently drawing carries *in use* under it — without that marker the
reader sees two swatches and cannot tell which one is their screen.

> Rejected: a segmented light/dark preview toggle. It is a third picker on a screen that already has
> two, and it makes comparison a memory exercise — the two halves are never on screen together, which
> is the only thing that makes a pair judgeable.
>
> Rejected: previewing *only* the half the appearance is not showing. Cheaper, and asymmetric — the
> reader cannot tell whether the visible half is the one they are looking at or a second opinion
> about it.

**What it costs is nothing, because neither sample is lexed.** Each half is five frozen colours
lifted from the real stylesheets and held to them by a test, so a list of themes is a list of
drawings rather than a list of stylesheet swaps on the actor the diff in front of the reader also
needs. Colour is the only property the highlighter keeps, so for this three-line sample five colours
per half is not a summary of the stylesheet — it **is** the stylesheet.

## Three things at `main` that decided the section before it was drawn

- **The app-appearance row is one modifier, and the re-lex is already wired.** `WorktreeDiffScreen`
  reads `@Environment(\.colorScheme)` and turns it into the lexer's appearance one line later, inside
  a `.task(id:)` that re-runs when it changes. A `preferredColorScheme` at the scene root costs one
  line and the diff re-colours itself for free — the same path a sunset already takes.
- **Granita throws the stylesheet's background away, and that is what disqualifies most of the 271.**
  `lines(of:)` keeps `.foregroundColor` and drops everything else on purpose, because a theme's
  background would sit under the word-diff background. So every stylesheet is judged on *our* card —
  `secondarySystemGroupedBackground` — rather than on its own. **This is the correctness argument,
  and the return makes it in preference to the muted-palette taste argument the ask had offered.**
- **The cache key has five parts and none of them was the theme.** The colours are baked into what
  comes back, so a theme change with the key unchanged hands the reader the old colours for every
  file already lexed. The theme is a sixth part of the question exactly as the appearance is a fifth.

> **The section has three rows since 0.19.0.** *Code size* joined it, with a push of its own; the
> calls are in [`design-code-size.md`](design-code-size.md) and the footer below now reads *"None of
> them changes what a review says"* rather than *"Neither"*. Everything else in this document stands.

## One section, two rows, seven pairs, and a push

`APPEARANCE`, fourth on the sheet, below the receipt. Row one is the three-segment System / Light /
Dark picker at 52pt, exactly as the comment-label row above it is. Row two is one 132pt cell: *Code
colours*, its value, a chevron, and under them the chosen pair drawn in both halves. 272pt for the
section with its header and footer.

**The section goes fourth rather than beside the controls it resembles** so the three built sections
keep their positions to the point and their nine baselines keep their meaning.

**One section rather than two, and the footer is why**: *"Kept on this iPhone. Neither changes what a
review says, so other devices reading `<Mac>` are unaffected."* Two sections would need that sentence
twice or leave one of them without it. They also belong together because the appearance row decides
which half of the pair the reader is looking at, and the *in use* marker is only legible as an answer
to the control directly above it.

**The app-appearance modifier belongs on the `WindowGroup`'s content, not on the sheet** — otherwise
a forced Light leaves the diff behind it dark. `PairingScannerView`'s own `.dark` survives untouched
inside that root, because the innermost non-nil value wins; it is worth one baseline, being the only
place in the app where two of these modifiers are in one hierarchy.

**Nothing marks the default in the section**, and that is deliberate: the sheet's rule is that a
default is told by a sentence or by an absence, and a value the reader can always choose back from a
seven-row list needs neither. The word *Default* appears once, in the list, beside the row it belongs
to. There is no *Reset* row and no badge here.

**Both samples carry a hairline in both appearances**, and it is the separator colour rather than a
new one. In light the light half is white on a white card; in dark the dark half is `#1C1C1E` on a
`#1C1C1E` card — whichever appearance you are in, one of the two would otherwise have no edge, and
the one without an edge is always the one the reader is currently living in.

## A curated pair, by name

**One name, one pair, from a table Granita writes.** The measurement settles it rather than the
instinct: a pairing table has to exist in either design — 40 of 271 pair by name and Granita's own
default is not one of them — so independent light and dark choices do not avoid the table, they only
stop using it. What free choice buys instead is 271 × 271 combinations, of which the great majority
are broken in a way the reader cannot predict: we drop the stylesheet's background, so a dark
stylesheet asked for in light appearance paints pale grey on white.

> Rejected: two independent lists. The honesty wanted from them is delivered by the preview rather
> than by the control — a reader looking at *Light: solarized-light* and *Dark: nord* has been shown
> two strings. Once each row carries its sample, the pair row carries both samples anyway, so
> independent choice adds a second control and subtracts nothing from what is visible. Kept as the
> escape hatch it deserves to be: if the table ever refuses a combination someone wants, the fix is
> one more row, which is a data change and a test.

## Seven pairs, from two stylesheet sources

The first three pairs remain the exact Highlightr resources readers already had. The other four are
Granita-owned, deterministic CSS: one declaration per token role, no media queries and no descendant
selectors for Highlightr's parser to flatten. Every colour in those four clears 4.5:1 on the actual
card; the minimum contrast per pair is shown below.

| In the app | Stylesheets | Why it is here |
|---|---|---|
| Xcode | `xcode`, `xcode-dark` | Default, shipped since 0.8.0 |
| Atom One | `atom-one-light`, `atom-one-dark` | Highlightr's own default, and the one a reader is most likely to recognise |
| Stack Overflow | `stackoverflow-light`, `stackoverflow-dark` | The quietest bundled pair |
| Accessible | `accessible-light`, `accessible-dark` | Clean transcription of the a11y palette; minima 4.55:1 light, 8.56:1 dark |
| Granita | `granita-light`, `granita-dark` | Product palette: vivid violet, mint, rose and slate with pastel dark-mode accents; deliberately distinct from plain code, with minima 5.32:1 light and 8.44:1 dark |
| Catppuccin | `catppuccin-latte`, `catppuccin-mocha` | Recognisable Latte/Mocha colours, mapped to readable roles; minima 4.91:1 light, 7.35:1 dark |
| GitHub | `github-light`, `github-dark` | GitHub's native light/dark vocabulary without unstable duplicate selectors; minima 4.55:1 light, 5.53:1 dark |

**A theme is a row of data**: a display name, two stylesheet names, and five colours per half —
comment, keyword, plain, string, type. The five are not a summary of the stylesheet, they are the
five classes the sample uses, and they are what every preview in the app is drawn from. They cost one
lexer pass each at build time and none at runtime.

**They cannot rot silently.** One test lexes the sample with the real `HighlightrSyntaxHighlighter`,
once per half, and asserts the colours that come back are the frozen ones. It fails the day
Highlightr ships a changed stylesheet — which is the failure mode a hand-kept palette otherwise has
and never announces.

### Thrown out, with the reason

- **Solarized**, and it is the interesting one. It pairs cleanly by name and its chroma is the lowest
  of any candidate, and it fails anyway: its comment grey `#93A1A1` is about 2.4:1 on white. On its
  own cream background it is fine. **We discard that background, so we break it.** The exclusion is
  caused by our own rule, and the only way to admit it is per-file backgrounds — a bigger design, and
  one that fights the diff's tints.
- **Dracula, Nord, Monokai.** Dark with no light sibling, so admitting them means *we* invent their
  light half — a pairing nobody who asked for Dracula asked for. Two of the three also fail the
  chroma test on their own.
- **`1c-light`**, light with no dark sibling. **`xcode-dusk`**, a third Xcode that pairs with nothing
  and would make the default's own name ambiguous in the list.

**A theme that is not in the table is not in the app.** None of these ships as a greyed row — that is
the *absent* state the never-ship-a-dead-control rule permits, and it is the right one here.

## The base colour is overridden to `label`

A run the lexer did not classify gets the stylesheet's base colour. **Mapping that one colour to
nothing lets the row's own `.primary` through**, which is a comparison inside the `enumerateAttribute`
block that already runs.

On Xcode it is a no-op — `#000000` and `#FFFFFF` are already `label` to the byte, which is what
`design.md` §4 relies on. On every other theme it is what keeps a file the lexer refused and a file it
accepted drawing their plain text identically, one scroll apart. **It does not rescue a theme whose
classified colours are wrong on our card**; that is the filter's job, not this one's.

## The chooser: five rows, ten drawings, one tap

A stock grouped list with a checkmark, pushed onto the sheet's own `NavigationStack`. Each row is the
theme's name and its pair drawn exactly as the section draws it — same sample, same two cards, same
order — so choosing is comparing the thing you will get rather than reading five names and finding
out afterwards.

**A row is 112pt, so five rows and a header are 602pt in the phone's 698pt of content**: the whole
list, its footer, and about 96pt of daylight. That number is the honest ceiling on the shortlist — a
sixth pair lands on the home indicator and a seventh is a scroll.

> Rejected: an inline picker. Five rows at 112pt is 560pt of section, four times the three sections
> above it put together, and the receipt would leave the screen. Rejected: a menu, which shows one
> name at a time and cannot carry a drawing at all.

What the row deliberately does not have: **no per-row captions** — *Light* and *Dark* under every
sample is the same two words five times, and the cards say it by being white and near-black; **no
live lexing and no stylesheet swap**; **no Apply and no confirmation**, since choosing is instant and
reversible and the diff re-lexes on the way back; **nothing disabled**.

**A push inside the sheet is right where a push in the sidebar was wrong**: inside the sheet the back
button has nothing else to mean.

## Two monospaced blocks, and they are about different things

The receipt is a document — prose, a rule, a label, a fence — and it is grey on grey because nothing
in it is coloured. The sample is source, three lines, and its entire content is colour. **They are as
alike as a paragraph and a paint chip.** What keeps them from competing is size: the receipt is four
lines at 11.5pt across the full card, the sample is two 142pt cards at 10pt. Nothing in the sample is
meant to be read.

## Where the sheet now scrolls

**The phone, at Large: the default state fits to the point and an edited one does not.** 788pt of
sheet under the navigation bar; the default state is 788pt of content. An edited opening line wraps to
a second line and brings the 44pt *Reset* row with it — 849pt, which is 61pt of overflow plus the 34pt
bottom inset, so the sheet scrolls by 95. The receipt stays above the fold either way; what goes under
it is the appearance footer, then the samples.

**The iPad, at Large: it does not fit in any state, and the return leaves it.** Roughly 680pt of
content into 564pt of sheet, about 120pt below the fold. Growing the form sheet to 700pt would buy one
release and the next setting would put it back; a form sheet is a scroll surface, and the cheap answer
does not re-pin six baselines.

## VoiceOver

The section is **two elements**: a picker with three options, and a button whose label is *"Code
colours, Xcode"* and whose value is *"light and dark preview"*. **The samples are decorative and the
two cards are not focusable** — a screen reader has no use for nine coloured tokens. The list it
pushes to reads five names, one marked default and one selected.

## Flagged for `SPEC.md` and for a later round

- **§10's colourblind-safe palette now has a candidate and a conflict.** It does not exist in code,
  and *Accessible* is the nearest thing to it in the bundle. But §10's palette is about the diff's add
  and remove tints rather than about the lexer, and a reader who needs one almost certainly needs
  both. Worth deciding whether the two settings are one setting before either is built.
- **The Mac's reader window will want this table and must not own it.** `CodeTheme` lands in the
  client's domain, where the phone's answer belongs. When the Mac's window gains highlighting it
  should read the same table and keep its own choice — two devices, two answers, one list. The moment
  it becomes a synced setting, this section acquires the failure state it currently cannot have.
- **A theme change re-lexes every visible file and nothing measures it.** It is the path an appearance
  change already takes, so it is not new — but `verification.md` still records Highlightr's throughput
  as unmeasured on a device, and this setting makes that flip deliberate and repeatable rather than
  twice a day.

## What was built, and the four places it departs from the frames

All of it is built. Four calls were made differently, and the first is the one that matters.

### 1. Seven pairs ship — four use stylesheets Granita owns

**Highlightr does not render a stylesheet the way the stylesheet reads.** Its `Theme` keys CSS rules by
selector in a `Dictionary`, understands neither `@media` blocks nor descendant selectors, and reduces
`.hljs-meta .hljs-keyword` onto the bare `.hljs-keyword`. So when a stylesheet declares one of the five
roles more than once with different values, **which declaration wins is decided by a dictionary
iteration order Swift randomises per process** — the colours change between launches.

That is a property of the library reading CSS rather than of highlight.js itself. The original
Accessible and GitHub resources failed it in separate processes, so Granita now owns clean
transcriptions of both. The same route supplies the new Granita and Catppuccin pairs.

| Pair | Verdict | Why |
|---|---|---|
| Xcode | ships | No duplicate declaration for any role |
| Atom One | ships | Only `.hljs-link` is duplicated, which no role uses |
| Stack Overflow | ships | Clean, and the only pair with four distinct colours in **both** halves |
| Accessible | ships, Granita-owned | Clean a11y transcription; every role clears 4.5:1 |
| Granita | ships, Granita-owned | Pastel product palette, tuned against both actual cards |
| Catppuccin | ships, Granita-owned | Latte and Mocha are genuine community light/dark flavours |
| GitHub | ships, Granita-owned | Clean transcription of GitHub's native light/dark vocabulary |

The application-owned resources are loaded through the same parser as the bundled ones. The frozen
preview test lexes every half through the real engine, so the preview and diff cannot drift apart.

### 1b. The filter, restated

Measured 19 September 2026 across all 271 stylesheets, prompted by Davide asking whether more themes
could be added. The original bundle survey remains useful context, but application-owned additions
now have a stricter contract:

1. **Both halves exist as a pair.** Unchanged, and it is what rules out Dracula, Nord, Monokai and
   Night Owl.
2. **Every role renders the same colour on every launch.** `CodeThemePaletteTests` enforces this.
3. **New application-owned colours clear 4.5:1 on our card.** The three legacy bundled pairs remain
   unchanged even where a muted comment falls below it.
4. **Chroma is reported, not gated.** Xcode was taken as the reference and is not the floor.

| Pair | chroma vs Xcode | comment | other roles | |
|---|---|---|---|---|
| `gradient` | 1.41× | 3.5:1 | 3.9:1 | the only genuinely colourful pair in the bundle |
| `paraiso` | 1.08× | 4.8:1 | 2.2:1 | |
| **Xcode** | 1.00× | 3.8:1 | 5.9:1 | **ships**, default |
| `kimbie` | 0.98× | 3.8:1 | 2.2:1 | |
| **Stack Overflow** | 0.94× | 5.2:1 | 4.9:1 | **ships**, and the best-contrasting pair available |
| `nnfx` | 0.92× | 5.8:1 | 4.2:1 | |
| `tokyo-night` | 0.72× | 2.7:1 | 5.6:1 | the modern one, and less colourful than Xcode |
| **Atom One** | 0.70× | 2.6:1 | 3.2:1 | **ships**, and the weakest of the three |

**Solarized was excluded for the wrong reason, and the right reason is stronger.** The return says its
comment grey is "about 2.4:1 on white"; on our card it measures **3.2:1**, better than Atom One's 2.6:1,
so contrast never disqualified it. What disqualifies it is criterion 2: `solarized-light` declares
`.hljs-keyword` as `#6c71c4` and `.hljs-meta .hljs-keyword` as `#d33682`, and Highlightr's stripper
splits the descendant selector onto the same key. It is the same defect as `github` and `a11y`, and it
was hiding behind a contrast figure that does not reproduce.

**Atom One stays, on a stated basis rather than as an exception.** Davide's call, 19 September 2026. It
is the lowest-contrast pair on the list, and the criterion it was said to pass is one nothing passes.

**None of the five unshipped pairs ships**, also Davide's call: `tokyo-night` was the only honest
addition and buys no colour, `gradient` buys colour and costs contrast, and `paraiso`, `kimbie` and
`nnfx` are neither modern nor colourful. The route to a modern colourful pair, and to bringing
*Accessible* back, is [#103](https://github.com/fardavide/granita/issues/103) — Granita shipping its own
stylesheet.

### 2. A role that collapses into plain is recorded as the plain colour

The frames assumed five distinct colours per half. Three of the six shipped halves have only four,
because `xcode-dark` does not colour the class `Bool` arrives in. Where a role collapses, the frozen
palette stores **the plain colour**, because that is exactly what the diff draws — the base override
turns the stylesheet's base into no colour at all and the row's own `.primary` draws it. The preview
and the file therefore agree, which is the only property the table has to have.

**The frames' colour values are indicative and the shipped ones are not theirs.** The return said so
itself. The largest gap is Xcode's light comment: the frames draw a slate `#5D6C79`, and `xcode.min.css`
says green `#007400`.

### 3. The base colour is probed with the language in hand, not with `nil`

The return left open how cleanly Highlightr exposes the base colour. It does not expose it at all —
`Theme` publishes `themeBackgroundColor` and keeps the `.hljs` foreground private — so the actor asks
the lexer for a single space, which no grammar classifies, once per stylesheet and language.

**Probing with `nil` is the trap**, and it was measured: `nil` asks Highlightr to *detect* a language,
detection over one space picks something arbitrary whose top-level scope can carry a class of its own,
and the "base" then comes back as that class's colour — which strips it from every run legitimately
using it.

### 4. The footer says *this device*, not *this iPhone*

The frames quote *"Kept on this iPhone."* The same view is the iPad's form sheet, where that sentence
is false. The rest of it is the return's wording unchanged.

### And the sheet's title is now *Settings*

Implied by the frames rather than stated: 3a titles the sheet *Settings* and the chooser's back button
reads *‹ Settings*. It held one subject when it shipped and holds two now.

## The two calls the return itself flags as most worth overruling

- **Five is the reviewer's number, not a measurement.** The filter is measurable and the count is not:
  twelve pairs would pass it if twelve cleared 4.5:1 on our card, and the list would become a scroll.
  A dozen changes the screen from one glance to two, and changes nothing about the drawing.
  > **The hypothetical is unreachable and the count was never the constraint.** Eight pairs in the
  > whole bundle render stably, five once the unshipped ones are excluded on Davide's call — so the
  > chooser could not become a scroll from this bundle however generous the bar. What limits the list is
  > the supply of stylesheets Highlightr parses deterministically, not the room on the screen.
- **Excluding Solarized will be the unpopular one.** It has the strongest following and the cleanest
  naming, and it fails on a comment grey that only fails because we discard its background.
  > **It does not fail on that.** Its comment measures 3.2:1 on our card rather than the 2.4:1 claimed,
  > which is better than shipped Atom One. It fails because `solarized-light` gives `.hljs-keyword` two
  > different colours once Highlightr splits its descendant selectors — the same defect as `github`.
