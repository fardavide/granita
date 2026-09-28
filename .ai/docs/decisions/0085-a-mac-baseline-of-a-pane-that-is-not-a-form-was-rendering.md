# A Mac baseline of a pane that is not a `Form` was rendering on white, and in dark that hid a control

Every Settings pane before Projects was a `Form` with `.formStyle(.grouped)`, which paints its own
background across the whole pane. Projects is a bordered list and a plus/minus bar, so it paints
none — and the snapshot host renders the **view**, not the window, so what came out was the pane
flattened onto nothing, which is white.

In light that is nearly right and hides the problem. **In dark it is catastrophic and silent**: the
pane's own foreground is light, so the add and remove buttons and the footnote under the list came
out white on white. Sixteen baselines were taken, adopted from the runner, and reviewed — and the
dark ones were pictures of a control that was not there. That is the exact failure the whole suite
exists to catch, arriving through the suite itself.

**The fix is in the hosting rather than in the view, and the direction matters.** The product is
correct as written: in the real Settings window the pane is transparent over the window's own
background, which is what a pane that is not a `Form` is supposed to be. Painting a background into
`ProjectsSettingsView` to make the picture right would have been changing the product to flatter a
test. So `hostedInWindow` puts `windowBackgroundColor` behind whatever it is handed, which is the
colour the pane really sits on. The status item's helper does **not** get it: a menu bar item is not
on a window background, and giving its 44 × 22 baseline one would be drawing a backdrop that does not
exist.

Found by looking at the pictures, which is the rule this project already had and the reason it has
it. Nothing else would have said so — the suite was green against baselines it had just written.

