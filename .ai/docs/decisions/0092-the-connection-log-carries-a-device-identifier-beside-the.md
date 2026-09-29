# The connection log carries a device identifier beside the name, and the Devices tab is why

*Seen 4 min ago* is a join between a paired device and the log of what has reached this Mac, and the
only key the log had was `device.name` — which is whatever the phone's owner called it. Two phones
can carry one string, and a sighting landing on the wrong row is the kind of wrong that reads as
right: nothing looks broken, and the row says something false about the one fact a reader came to
this tab for.

So `ConnectionOutcome.accepted` and `.paired` carry `id` as well. Nothing rendered changes — the log
prints the name and always did — and the router had the identifier at both call sites already.

**The sighting is derived rather than stored.** The model keeps the stored devices and computes the
rows from them and the current log reading, so a phone that connects while the tab is open stops
saying it has not been seen without anything having to notice. That is also why **following the log
moved to the composition root**: it used to start when the Connections tab opened, and a reader who
had never opened that tab would have been told every phone they own had not been seen. It is an
in-memory list of fifty, so following it from launch costs a continuation.

