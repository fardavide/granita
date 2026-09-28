# The drawer's presented state is the model's, and a scroll that has not been told where it starts settles there on its own

Two measurements from the same slice, both about state nobody had named.

**The drawer.** `isShowingSelector` began as `@State` on the screen, which is the ordinary SwiftUI
spelling and is wrong here for the reason this repository already wrote down when the Mac's menu had
to open Settings on Devices: *a control whose only effect is a `@State` two layers up is a control
nothing can be asked about.* On the phone the drawer is the only way to the file list, so a presented
state no test can set is a screen that can only ever be photographed with its main affordance shut.
It is on the model, it is asserted — including that **choosing a file leaves it up**, which is the
whole of design §3's argument for a drawer over a modal — and the screen can now be rendered with it
open.

> What that render does **not** show is the drawer, and that is this repository's settled answer
> rather than a surprise: a hosted view presents a sheet into a window of its own and the raster does
> not include it. What the baseline holds is the diff *behind* it, undimmed, which is the visible half
> of the same argument. The suite says so where a reader of it will look.

**The scroll.** `scrollPosition(id:)` is a two-way binding: it is how a jump is asked for, and it is
also where the scroll **writes back** what it settled on. Started empty, that write-back is a value
arriving on its own schedule — and the iPad's split-screen baseline moved between two runs of
unchanged code because the shutter caught it on either side. The position is now seeded from the
state: the jump when there is one, the first file otherwise. The reader gets the same screen; the
difference is that it is a value this view stated rather than one it settled into.

**And a fixture can hide a working control as easily as a broken one.** The jump's first subject
targeted the *last* file, which cannot reach the top of a scroll — it clamps against the end of the
content, so where it stopped depended on how much of the lazy stack had been realised. The target is
a file with hundreds of rows under it now. **It lands about 120pt short of that file's top**, which
the baseline records rather than hides: anchoring, an explicit section identity and the target layout
were each tried and none of them closes it, so it is `scrollPosition` interacting with pinned section
headers. The reader gets the file they tapped, near the top of the screen; the last 120pt is a
question for a thumb.

