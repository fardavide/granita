# Control contextual offset adjustment during reading

The candidate keeps its existing typed scroll position and native animated identity requests.
Contextual offset adjustment is disabled only while that position is user-positioned. Initial
seeded programmatic positions retain their incoming adjustment policy. Changes to file entries,
code point size or split mode restore automatic adjustment for that transaction. The outer
conditional modifier runs first; inner value-scoped modifiers restore the automatic policy only
when their watched value changes. Animation fields, target identities and completion timing
stay intact.

The original later-file case sometimes accepts its native 450pt movement and then returns to
the selected header during a hosting scroll-view update, without changing content height.
This also reproduces on production `71c50ff` with both text-transition modifiers removed, so
the reset is not attributed to that rendering optimization. The existing user-positioned flag
alone does not reliably prevent it.

A default disabled-adjustment control passes ten complete repetitions and the selector's
native-animation/selected-header guard. An otherwise identical automatic-adjustment control
reproduces the reset. Narrow suppression confined to pin bookkeeping, completion, framework
position feedback, continuous transactions or the position modifier does not reliably prevent
it. Request-only optional-ID controls pass native preparation but make selection instantaneous
or land on the wrong header; the stronger selector test rejects them.

Broad adjustment suppression also changes font reflow. A temporary native-grid probe moves
typed line100 to122 under the ordinary policy and to72 when adjustment is disabled globally.
The earlier unconditional value-scoped candidate matches the ordinary result,122. Actual pitch changes18→25
and grid height2880→4000, so the comparison exercises real layout. This preserves an observed
baseline result; it does not repair font anchoring.

Additional paired probes also match the ordinary policy. Removing a stale-comment row moves
line100→102 while content height shrinks exactly44pt. Narrowing split rows across their fit
threshold changes160 paired rows into320 unified rows and moves new-line100→new-line50.
Both policies produce the same native metrics. These are baseline limitations, not repairs
or candidate-specific regressions.

An image-caption Dynamic Type probe supplies no layout-policy evidence. Its first form cannot
establish the required starting line after selection. Direct preparation establishes line100,
but changing the environment produces no growth in the live grid's content-coordinate origin
or total content height. The feasibility guard fails explicitly. Effective caption-height
changes outside the three watched values remain unverified; the list is not presented as an
exhaustive layout-input contract.

All temporary probes and fixture seams are removed. The earlier diagnostic source
`b7e11c8ca5ba09439e3a8a7623d57f562b1f415d1b9fba743265aacc8bbb6e75` passes ten complete
original later-file repetitions, the selector guard and all66 interaction executions. The
original65 executions retain their assertions, physical travel guards, image comparisons,
deadlines and motion bounds. The new test additionally requires visible native animation and
the selected last file's exact header image. Full instrumented validation and required remote
checks remain separate from these focused results.

The principal receipts are `granita-native-preparation-value-filtered-policy-20261028.xcresult`,
`granita-selector-value-filtered-policy-20261028.xcresult` and
`granita-collapse-interactions-value-filtered-policy-20261028.xcresult` under `/private/tmp`.
The public [value-scoped transaction API](https://developer.apple.com/documentation/swiftui/view/transaction(value:_:))
defines the changed-value transformation used here; no private scrolling API or pixel-offset
position is introduced.

Full instrumented group0 subsequently passes587 executions but fails both preselected-file iPad
snapshots. The previous viewed row is visible above the expected header. This disproves accepting
the unconditional disabled default based on the focused66-case result. The four modifiers are
removed for a matched ordinary-policy comparison: all56 reader snapshots pass, including both
failed iPad layouts. The conditional policy above then passes the same56 cases, ten full
later-file repetitions, the selector guard and all66 interaction cases at source
`0b4f700d2274896fcd4b18c89b70f4f593db7cd41375cb2fa366c62db25299d2`.
The current receipts use `user-policy-20261028.xcresult` rather than `value-filtered-policy`.
The corrected source subsequently passes package tests, both unsigned Debug and Release apps,
all1,169 instrumented iOS cases and22 native UI cases. All four successful coverage collectors
have the same source digest. The local Mac collector reports image differences and stalls in
its reader-menu case; it is interrupted and supplies no successful Mac receipt or aggregate
coverage verdict. Existing baselines, assertions and numeric gates remain unchanged. Required
remote checks remain the delivery gate.

[CI 387](https://github.com/fardavide/granita/actions/runs/40746642387), at `638a113`, passes
group0 and native input coverage but still fails original collapse bounds and the new selector
guard in group1. This disproves treating the local native results as a complete motion repair.
The local build uses Xcode27.1 (`27A9275`); CI uses Xcode27.0 (`27A266a`). The remaining cause
requires measurement on CI's toolchain; this difference alone does not establish causality.
