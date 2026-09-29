# One model per unit, not one per view

Davide's correction, 2026-08-21, on seeing a `MenuBarViewModel` and a `ConnectionLogViewModel` land
beside each other in the same module: **a state object per view is a vertical split wearing a
layer's name.** The menu bar item and the Settings window are two views onto one running server, and
splitting that server's state across as many objects as there are places it is drawn puts the seam
in the wrong direction — a screen, rather than a layer.

So a unit's `Presentation` holds **one** `@Observable` model, named for the unit rather than for a
screen: `ServerMacModel` carries what the server is doing and who has reached it, and the four
Settings tabs M3 still has to build add properties to it rather than a type each. Views stay
stateless and are handed values, which is unchanged — that direction was already settled when
`Presentation` was put above `Ui`.

The cost is a type that grows, and it is worth naming: if one model stops being readable, the split
is by **layer concern** — what it wraps — and never by which screen happens to draw it. What is
gone is the reflex that a new screen needs a new state object.

The phone kept `ServerDiscoveryViewModel` from M1 for one release, deliberately, rather than being
swept: the rule was written here and in the architecture skill, and each module converts as it is
next opened. M4 reopened the client's connection feature and converted it — `ClientConnectionModel`
carries the browse, the handshake and the pairing history, and nothing in the client is named for a
screen any more.

