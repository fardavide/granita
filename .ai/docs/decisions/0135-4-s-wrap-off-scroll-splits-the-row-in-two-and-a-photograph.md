# §4's wrap-off scroll splits the row in two, and a photograph is what said so

The first attempt at design §4's diff line was one view holding both halves — the number column and
the code — with the code at `fixedSize(horizontal: true)` so that it runs past the trailing edge
rather than truncating at it, which is what wrap-off means. It compiled, it read correctly, and the
baseline came back with **the gutter off the leading edge of the screen**: a row wider than its
container is centred in it, so forcing the code's width pushes the numbers out of the frame in the
one direction nothing can scroll back to.

The deeper version of the same thing is the reason it cannot be repaired by an alignment. `SPEC.md`
§10 says long lines "scroll horizontally within the file **with the gutter pinned**", and a gutter
inside the row is inside whatever scrolls the row. So the two halves cannot be one view:

- the number column is a fixed-width stack outside the horizontal scroll;
- the code is a stack inside it;
- and the two are separate view trees that must agree on every row's height, which means the height
  is stated once rather than left to two text engines to arrive at.

That is a bigger change than a layout fix and it decides what the file section, the sticky header and
the estimated heights are all built on, so it is recorded rather than rushed. **The row and its five
baselines were taken back out** — a view that lays out wrongly is worse committed than absent, and
the measurement is the part worth keeping.

What the photograph did confirm, and what the rewrite has to preserve: the tints and the word
segments are right. A deletion at 10% red under an addition at 10% green, the changed run at full
strength and the unchanged runs at `.secondary`, and the eye goes to the text rather than to the box
— which is §4's call, and the frames use it in all three palettes rather than only in dark.

`MonospacedGrid` stays, because it is right either way: `displayColumns` travels on every line with
tabs already expanded to a stop of four, and a view that handed the raw string to a text engine would
get that engine's tab stops instead — a tab-indented file drawn at one width and measured at another.
The constant now lives in one place and `DisplayWidth` reads it from there.

