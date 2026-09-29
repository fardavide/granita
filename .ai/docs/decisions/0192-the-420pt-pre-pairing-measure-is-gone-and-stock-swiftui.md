# The 420pt pre-pairing measure is gone, and stock SwiftUI lays those screens out

Design §1 clamped every screen before a paired Mac to a 420pt centred column with the navigation
container inside the clamp, so the large title came with the rows. §5 extended it to the viewfinder
and the six words. Both are reversed.

**What it looked like, which is what settled it.** On 4 September 2026 Davide ran the app in a Mac
window and sent three screenshots: the Mac list, the two credentials, and the six-word field. Each one
is a 420pt strip down the middle of a 1,300pt window with the rest of it bare white — the large title
floating at x=362 rather than at any edge, the two credential buttons stacked in the middle of an
empty room, the disclaimer under the field wrapping at 300pt with a thousand points of nothing beside
it. His call, verbatim: *no custom weird stuff, just regular SwiftUI components*.

**The argument the measure was made on has not stopped being true.** A 1,150pt row does pull its two
ends apart, name at one edge and chevron at the other, and that is a worse row than a 420pt one. It
lost to something the reader sees first: a window that looks like the app failed to lay itself out.
Between a compromised row and a broken-looking window, the window wins.

Two alternatives were put to Davide and both were refused as more hand-drawn layout rather than less:
painting the grouped background across the window so the column reads as a card in a room, and
releasing the measure only in a Mac window. The second would also have been a platform condition
inside a universal app, which is the shape of thing the design file exists to keep out.

**What went with it.** `ServerDiscoveryView.contentWidth`, `PairingSpineNavigation.contentWidth` and
the `hasLeftTheSpine` flag it was computed from, the `onAppear` that set the flag on both routes past
the spine, and the six navigation tests that asserted the measure through a sequence of pushes. The
navigation object keeps the one rule it still holds — a pairing that worked *replaces* the screens
that produced it — and the five snapshot suites that clamped their subject to match the app now render
it unclamped, which is why every pre-pairing baseline moved in one commit.

**The scanner's iPad card survives on its own terms.** §5's rejection of a full-bleed iPad viewfinder
stands, and nothing about it depended on the clamp: the preview is a 4:3 fit inside a padded column,
which is a card in any window. It is bigger than 420pt now and that costs nothing, because detection
reads the whole capture frame rather than the preview.

