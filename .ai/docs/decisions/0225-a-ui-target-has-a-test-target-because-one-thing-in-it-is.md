# A Ui target has a test target, because one thing in it is not a view

`Package.swift` has said since the module graph was written that a Ui target has no test target —
"there is nothing in one a test would want to reach" — and `ClientViewerUiTests` now exists.

**The rule's own reason is what admits the exception.** The sentence is about stateless views.
`HighlightrSyntaxHighlighter` is an actor wrapping a JavaScript engine, and the frozen palettes it is
measured against are a fact about that engine's bundled stylesheets — a table that can rot silently
when a dependency updates, which is exactly what belongs behind the suite that runs on every change.

**Moving the highlighter to `ClientViewerData` was the alternative and it is worse.** It is where an
actor wrapping an external dependency would belong, and it would have got a test target for free — but
`lines(of:)` returns `AttributedString`s carrying SwiftUI `Color`s, so `Data` would have had to import
SwiftUI. A framework leak into the data layer is a larger hole than a test target on a module holding
one actor.

