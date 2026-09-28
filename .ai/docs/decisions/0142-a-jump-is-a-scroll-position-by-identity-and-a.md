# A jump is a scroll position by identity, and a `ScrollViewReader` could not do it

Tapping a file in §3's selector has to move §4's scroll, and the first build did the obvious thing: a
`ScrollViewReader` and `proxy.scrollTo(id, anchor: .top)` from a watch on the chosen file. **The
baseline came back with the first file still at the top.** The stack is lazy, so at the moment that
watch fires the row being scrolled to has not been created, and there is nothing to scroll to.

`scrollPosition(id:anchor:)` over a `scrollTargetLayout()` applies during layout instead, which is the
one place the answer exists. It is still identity rather than an offset, which is `SPEC.md` §10's rule
and not a detail.

**Two things the photograph decided that reading did not.** The first fixture for it was 0.2.0's
three-file change set, and the recorded baseline was byte-identical to the one beside it — that change
set fits on one screen, so a jump that worked and a jump that did nothing photograph the same. The
subject is a seven-file set now, with a control render beside it that asked for no jump, and the pair
is what makes the claim. And the assignment is skipped when the scroll is already where it is going:
animating it anyway re-ran the transition from where it had landed, and the shutter caught a different
offset on each run.

The model says *go here*, once, and the view holds *here is where we are*. They are separate because
feeding a scroll position back into the model makes every frame of an ordinary scroll a write — and
the target is cleared by the view once it has moved, so tapping the same row twice is a change again
rather than a value set to itself.

