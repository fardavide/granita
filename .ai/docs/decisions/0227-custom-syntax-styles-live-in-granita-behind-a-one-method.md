# Custom syntax styles live in Granita, behind a one-method Highlightr fork

Issue [#103](https://github.com/fardavide/granita/issues/103) supersedes the earlier absence of
Accessible and GitHub. Granita now owns four light/dark CSS pairs: Accessible, Granita, Catppuccin
Latte/Mocha and GitHub. The first three bundled pairs remain unchanged.

**The dependency seam is a public `setTheme(with:)` method in
[`fardavide/Highlightr`](https://github.com/fardavide/Highlightr), tagged `2.3.1`.** Upstream 2.3.0
already parses a stylesheet string internally, but exposes only a name lookup in its private SwiftPM
bundle; the maintained successor has the same bundle-only surface. The fork makes that existing
parser callable and changes nothing else. Granita keeps the CSS in `ClientViewerUi`, where the lexer
already lives, rather than moving resource loading into Domain or vendoring the dependency.

**Every application-owned selector is declared once.** That is the direct repair for Highlightr's
dictionary parser, which made the original a11y and GitHub resources nondeterministic. The real lexer
test still derives every frozen preview palette from every stylesheet half.

**Community additions need genuine light and dark identities.** Catppuccin supplies Latte and Mocha;
GitHub publishes native light and dark variants. Dracula remains excluded despite its popularity
because it is dark-only, and inventing a light half would not be Dracula. The first Granita palette
cleared the numerical floor but read almost like unthemed code in a rendered diff, so contrast here
means both legibility against the card and visible separation between token roles. Its light half now
uses deeper, more chromatic violet, teal, rose and slate; its dark half keeps the pastel character in
brighter lavender, mint, rose and blue. Every token clears 4.5:1 on the actual white and `#1C1C1E`
cards. The same floor applies to every application-owned pair; legacy bundled colours remain unchanged
for compatibility.

