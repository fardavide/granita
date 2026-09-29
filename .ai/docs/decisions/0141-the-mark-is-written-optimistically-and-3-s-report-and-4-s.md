# The mark is written optimistically, and §3's report and §4's toggle are one fact

Design §3's row carries a viewed mark and says plainly that it is **not** a control there: a 32pt row
inside a sheet cannot hold two tap targets without generating mis-taps. Design §4 puts the toggle in
the file header, "where the reader is when they finish a file". Built separately those are two
features; built together they are one, and that is why the toggle lands in the same slice as the
selector — a column that reports a state nothing in the app can write is a column that is empty
forever.

`markViewed` is written **against the file's own content hash**, which the Mac refuses on. That is the
one guard that matters: a mark applied to a version nobody saw is the only way this product can
actively mislead someone.

The write is optimistic and taken back on a refusal, with an alert saying so — the same shape the
sidebar's rename and pin already use, and for the same reason: the row has to change under the finger,
and a mark that silently reverted would be the app disagreeing with the reader about the one thing it
is for. A diff arriving from a batch asked for *before* a mark was set keeps the mark rather than the
Mac's older answer, which is asserted.

**Collapsing a viewed file is not built.** `SPEC.md` §10 says a file marked viewed renders collapsed;
design §4's collapsed bars are the piece still drawn and not built, and this slice does not add them.
What the toggle does today is perceivable in three places — the circle fills, the selector's row dims
and takes a check, and the footer counts — so it is a control that works rather than one that waits.

