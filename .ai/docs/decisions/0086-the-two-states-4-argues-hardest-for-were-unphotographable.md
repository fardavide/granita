# The two states §4 argues hardest for were unphotographable, and that was a layering mistake

`AddRepositoriesSheet` held what was ticked as its own `@State`, and `ProjectsSettingsView` held
which row was selected. Both read like a view's own business and neither is, because of what it
costs: the states those controls turn **on** could then be reached by nothing but a finger. The
sheet's confirm was photographed only saying `Add` and greyed out; the footer's `2 chosen of 30`
never at all; the minus only in the state where it cannot be pressed. Design §4 argues about the
count being in the verb across a whole paragraph, and the suite had no picture of it.

The coverage gate said the same thing in numbers before the eye did — the Snapshot region row fell
9.3 points, which is far outside the ~0.3% noise these rows drift by, and every uncovered region was
in a branch only an interaction could take.

So both move out to the screen that composes them, and both views take a `Binding`. That is what
`architecture.md` already says a `Ui` module is — *each takes what it renders and reports what
happened* — and this is the first time the rule has paid a debt rather than merely been followed.
Two baselines came back with it: a sheet with two ticked, and a list with a row selected.

Rejected: adding a parameter to the views that only a test would pass, which is the same picture
bought by making the production initialiser lie about what the view needs. And rejected: accepting
the lower number as honest, on the grounds that a snapshot cannot click — it can, once the thing it
would have clicked is a value it is handed.

