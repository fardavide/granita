# Syntax highlighting is built without a design, and the palette is Xcode's

`design.md` §4 had no highlighting section at all — the diff review saw the edge of it, rejecting an
underline for the changed run because "it collides with whatever the syntax highlighter does", and
never drew the two together. `design-handoff`'s rule is that no pull request touching a screen opens
before its frames exist, so the ordinary answer here was to write a prompt and wait.

Davide waived it on 4 September 2026, in one sentence: *"We don't really need design for syntax
highlighting."* So the calls below are this repository's own rather than a return, and they are
written into `design.md` §4 for the same reason a return would be — the prose is what survives once
nobody remembers which of these was argued for.

**Xcode's own stylesheets, `xcode` in light and `xcode-dark` in dark.** The design language is
Apple's throughout and the phone is lying beside the Mac the diff came from, so the colours that
already mean *keyword* and *string* to this reader are the ones Xcode gave them. They are also the
most muted of the credible pairs, which is what the section they sit in depends on: a row already
carries an add or remove tint and a word-diff background at three times it, and §4's whole argument
is that those stay the loudest thing in the row.

Rejected: GitHub's pair, which is what a diff normally looks like and is more saturated, so it
competes with exactly those tints. Rejected: Atom One, Highlightr's own default, which matches
nothing else the reader sees. Deferred rather than rejected: making it a setting, which is
[#70](https://github.com/fardavide/granita/issues/70) and needs a Settings surface the phone does not
have.

**The theme's base colour is kept and its font is dropped.** `.hljs` declares `#000` in light and
`white` in dark, which are `UIColor.label` to the byte in both — so plain code inside a highlighted
file and plain code inside a refused one are the same colour, which matters because one screen mixes
them. The font is Courier at 14pt and every row's height is computed from the code point size, so
keeping it would break the grid the gutter is aligned to. Per-token background colours are dropped
with it: three highlight.js classes declare one, and they would sit under the word-diff background
`SPEC.md` §10 makes the strongest thing in the row.

