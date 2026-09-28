# Highlightr crashes on a language it does not know, so the set is read before it is asked

`Highlightr.highlight(_:as:)` assigns the result of `hljs.invokeMethod` to a **non-optional**
`JSValue`, and highlight.js v11 throws for an unregistered language — so the value is nil and the
assignment traps. The code around it reads `if result.isUndefined`, which is what v10 returned and is
why the hazard is invisible from the call site.

`supportedLanguages()` is therefore read once and checked before every call. **Nothing reaches it
today**: this build registers 192 grammars, which covers every name `LanguageHint` can produce. What
it protects is one more line in that table, or a Highlightr that ships the smaller common bundle.

It is also the only one of the highlighter's three refusals a rendered screen can reach, and it is
reachable for a real reason rather than a contrived one — the Mac names the language and the phone
carries the lexer, and the two are updated separately. `a-language-we-cannot-colour` photographs a
`.zig` file drawn plain beside its tints and markers, which is what puts that branch in the Snapshot
row's numerator. The other two — a JavaScript context that would not build, and a lexer that answered
with nothing — are written as one guard with it, because three branches for one outcome would be
three regions no baseline can enter.

