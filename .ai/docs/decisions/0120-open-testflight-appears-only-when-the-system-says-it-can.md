# *Open TestFlight* appears only when the system says it can open it

Design §5's *the phone is behind* state offers it, with the reviewer's own note attached: *only if the
URL opens TestFlight on a device that has it — otherwise delete it.* Neither this machine nor the
simulator can answer that.

So neither answer is picked. The button is rendered only when `canOpenURL` says the device can open
it, which turns an unanswerable question into a condition evaluated on the device where it has an
answer — and it lands on this project's own rule rather than on a guess: a control ships if it works,
is absent, is disabled and says why, or explains what is not built. **Absent is a legitimate state**,
and a reader with no TestFlight is not missing anything, because the sentence above already tells them
what to do.

Rejected: shipping it unconditionally and finding out from Davide. That is the eight-release defect
with a better excuse. Rejected: disabling it with a caption — a greyed *Open TestFlight* explains
less than no button at all on a screen that has already said which end is behind.

