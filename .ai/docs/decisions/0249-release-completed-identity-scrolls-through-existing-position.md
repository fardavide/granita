# Release completed identity scrolls through the existing position

A completed identity request must stop owning later reading movement. Replacing its bound
`ScrollPosition` with a new empty value does not reliably achieve that in the observed native
framework. A measured later-file fixture accepts a 450 pt UIKit move from 5762 to 6212, then
`HostingScrollView.updateContext` restores 5762 during layout. The retained and freshly located
scroll views are the same object; the animation completion already ran. Other repetitions also
expose an invalid negative jump position. Neither failure is treated as legitimate rebasing or
an excuse to remove the physical-travel guard.

Completion instead sets `isPositionedByUser` on the existing bound value. Apple documents that
[writing this property](https://developer.apple.com/documentation/swiftui/scrollposition/ispositionedbyuser)
makes the scroll view behave as manually positioned; an actual gesture is not required. We keep
the existing destination guard, so an older completion cannot release a newer request. The next
explicit request still supplies its typed identity and top anchor. No content-offset positioning
is added to production.

This is an observed distinction between updating and replacing a framework value, not a promise
about its private storage. Creating a new value and setting the same public flag still fails two
of ten repetitions. Updating the existing value passes ten of ten, clears its observed identity
and preserves the exact 450 pt movement through horizontal scrolling. Public identity clearing
is also checked through a real same-file reselection behavior, rather than assumed from the API.

Several controls fail and are removed: asynchronous settlement, passive layout observation,
dispatching the same setter through the native event cycle, removing the modifier's preferred
anchor, and animating only the preparation move. Failures occur beyond the first repetition,
so app startup alone is not established as their cause. The original setup calls, five quiet
frames, three-second deadline, physical-travel checks and all image/motion assertions remain.

The original 65 interaction executions pass after removing every diagnostic callback, observer
and recorder. Two additional real-touch cases use the production file selector with three long
files: selecting the third file before vertical/horizontal reading, and reselecting that same
file after a real pan. Reselection must restore its first code line and viewport, so a pinned
header alone cannot hide a no-op. These focused cases pass. Final-source package tests, both
unsigned apps, generated files and optimized device Release compilation also pass. Both complete
instrumented iOS groups pass 1,168 cases; the native input group passes 22, with no skips or runtime
warnings. Their receipts and Unit share source digest
`7f071b25a8a8e140c7cf37ad229aec2d6d098860eceedf8f7e1f010e9ae3e8a2`.
The local Mac run remains red on images and is interrupted during its reader menu case, so it
provides no aggregate coverage verdict. Every required CI check must still pass before delivery.
