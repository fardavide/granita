# The menu is photographed as a stack, because a menu cannot be photographed at all

`MenuBarContent` gained four controls, and the Snapshot row is scoped to the `Ui` layer — so drawing
code nothing renders would have taken the row down, which is the trap this repository has now met
three times. The obstacle is that a `MenuBarExtra`'s menu is drawn by AppKit outside this process's
view hierarchy: there is no hosting view it can be rendered into, and a test bundle has no `Settings`
scene either, which is the same reason the window's own baselines show no tab bar.

What is committed is the menu's rows laid out in a `VStack` — every row in order, the copy each one
carries, and a disabled row visibly disabled. That is what §1 is about: which rows exist in which
state and what they say. The button styling is the test file's rather than the app's, and the
docstring says so, because a menu item's appearance comes from the menu it is in.

**What no picture here can say is whether anything is behind them**, and that is the honest state of
four new controls rather than a caveat. It is the same gap the Devices tab's `Revoke` and the
connection log's `Pair…` are in, it closes with the Accessibility grant rather than with more tests,
and the four rows are named in `status.md` beside them.

