# The remembered pane is in user defaults, and its absence is what a first run is

Design §2 asks for two things that are one question: restore the pane the reader was last on, and
open **Projects** the first time. So `SettingsTabMemory` answers with a pane **or nothing**, and the
model turns nothing into Projects. A seam that defaulted internally would answer every launch with a
pane and leave no caller able to tell a return from a first run — which is the decision design §2
actually makes.

**Not the store.** That document is shared with `granita-server`, which has no window and no panes,
and it is about to grow a lock file precisely so the two processes cannot both hold it. A preference
belonging to one of them does not belong in the file they share, and losing it costs nothing: a
reader whose defaults did not follow them to a new Mac lands on Projects, which is what a first run
does anyway.

**Synchronous, which no other seam here is**, and that is what makes the race impossible rather than
unlikely. The rest of them wrap a subprocess, a panel a person is looking at, or a document written
to disk; this wraps a value the system already holds in memory. Read in the model's `init`, there is
no window in which a restore could land *after* the menu's *Pair a device…* and quietly take Devices
back off the screen — and no `Binding` on the tab bar has to defer its own assignment by a turn to
make room for an `await`, which is how a tab bar comes to lag a click it has already accepted. The
pane names are spelled out rather than derived from the case names, because a rename would otherwise
strand a stored word and send a reader to a pane they were not on.

