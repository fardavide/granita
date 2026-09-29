# The theme filter was published as four criteria and enforced as one, and the sheet said otherwise

0.16.0 recorded a filter for `CodeTheme`: both halves in the bundle, each legible on our card, every
colour past 4.5:1 there, and mean chroma at or below Xcode's. **Two of those four are false of the
table that shipped**, and nothing in the code enforced either. Measured 19 September 2026 across all
271 stylesheets, when Davide asked whether more themes could be added.

- **4.5:1 is met by nothing.** `xcode-dark` draws comments at 3.8:1 and `atom-one` at 2.6:1 on our own
  card. Stack Overflow is the only pair in the bundle that comes close, at 5.2:1 and 4.9:1.
- **Xcode is no chroma ceiling.** It is the second most saturated of the eight stable pairs, so "at or
  below Xcode's" admits almost everything rather than restricting anything.
- **Solarized was excluded on a figure that does not reproduce.** Its comment measures 3.2:1 rather
  than the 2.4:1 claimed — better than the Atom One that shipped. Its real fault is the stability
  criterion: `.hljs-keyword` gets two colours once Highlightr splits `.hljs-meta .hljs-keyword` onto
  the bare class. The same defect as `github`, and a stronger reason than the one recorded.

**So stability is the only criterion that has ever excluded anything**, and it is the only one with a
test behind it. Contrast and chroma are now reported per pair rather than asserted as gates, with
comments reported apart from the other roles — every stylesheet in the bundle dims comments
deliberately, and 4.5:1 is WCAG's threshold for body text rather than for a class meant to recede.
Atom One stays on that stated basis rather than as an exception; Davide's call.

**Two lessons, and the first is the one that cost the release.** A criterion nobody wrote a test for is
a comment, and this one was worse than a comment because it was a comment that read like a
measurement — it had a number in it. The stability criterion survived precisely because it acquired a
test. And a filter is only as good as its arithmetic: the contrast figures here were wrong twice before
they were right, first by merging two classes into one role and then by merging two halves' ratios into
one dictionary, which silently reported every pair as its better half.

**What it changes about adding themes.** Eight pairs in the bundle render stably and five are
unshipped, none of them both modern and colourful: `tokyo-night` is modern and less colourful than
Xcode, `gradient` is colourful and the second-lowest contrast available. The themes a reader would
name — Dracula, Nord, Monokai, Night Owl — are dark-only *and* unstable, and a dark-tuned palette
measures 1.0–2.9:1 on a white card, so none can serve both halves either. None of the five ships;
[#103](https://github.com/fardavide/granita/issues/103) is the route that does not depend on what
Highlightr bundles.

