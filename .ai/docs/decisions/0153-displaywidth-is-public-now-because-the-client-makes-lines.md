# `DisplayWidth` is public now, because the client makes lines the parser never saw

The type's own comment said it is measured on the server "rather than on the client", and the reason
is the one that matters: two implementations of one Unicode judgement is a disagreement waiting to
become a row-count error in a scroll that must never reflow. Context expansion turns raw text from
`/lines` into diff lines **on the phone**, which need that number like any other.

So the answer is not a second implementation on the client — it is the same one, exported. What the
comment protects is one measurement, not one side.

