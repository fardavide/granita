# The bar's rule is a rectangle, because `Divider` picked its own axis

`Divider` takes its orientation from the layout it is in. Inside a `Button`'s label it read the bar's
own `HStack` and drew itself **vertically** — a stray line down the middle of the two bars that are
buttons, and no rule under them, while the two that are not buttons got the horizontal one. The first
baseline is what said so; nothing in the code reads as if it could happen.

It is an explicit rectangle at a stated height now. That is this repository's third measurement that
settled itself differently in two places, after the list margin and the scroll position, and the
answer is the same one: state the value rather than loosen what checks it.

