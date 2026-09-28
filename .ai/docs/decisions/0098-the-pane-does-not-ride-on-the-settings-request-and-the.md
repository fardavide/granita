# The pane does not ride on the settings request, and the entry above predicted that it would

Design §1 and the entry on which pane is up both said the same thing: *Pair a device…* needs
`settingsRequests` to carry a pane rather than being a bare counter. Both were written before
`ServerMacModel` owned the selection, and once it does, carrying the pane on the request is a second
copy of a fact something else already holds.

**The half that makes it wrong rather than merely redundant is `onChange`.** `SettingsOpener` watches
that value, and a value carrying a pane is `Equatable`: asking for Devices twice in a row produces
two identical requests, and the second one fires nothing. A reader who pressed the row, moved to
Advanced, and pressed it again would meet a menu item that did nothing — the exact defect this
project spent eight releases shipping, reintroduced by the mechanism meant to prevent it. Keeping the
counter a counter keeps "open" an event, and opening twice two events.

So `requestSettings(showing:)` takes the pane, hands it to the model, and *then* bumps the counter.
The ordering is the other half: set first, ask second, so the window opens already showing the pane
rather than arriving on one and moving. The design's actual constraint — do not invent a new
mechanism for this — is met; what it guessed about the shape is not, and the guess is superseded
rather than argued with.

