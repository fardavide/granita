# The composition roots are a layer called `Main`, and that is what stopped two predicates lying

Three modules mix layers on purpose, because wiring implementations into protocols is their whole
job. Two of the three were filed under `Presentation` — `Client/App/Presentation` and
`Server/App/Presentation` — and the third, the executable, was already at `Server/Cli/Main`. So the
exemption could not be read off a path, and every place that needed it named the modules one by one:
this file, `architecture.md`, the `architecture` skill, the manifest's header comment, and **a clause
inside each of the two coverage scope predicates**.

Those last two are what made it worth fixing rather than tidying. The views scope had to say "a
composed screen, unless it is in a composition root", and the host-reachable scope had to say "not a
composition root", each matching a *pair* of directory names because neither could match a layer. The
same fact, spelled twice, in two different shapes, in the script that decides whether a pull request
may merge. Renaming the two roots to `Main` replaces both with a layer name matched exactly the way
`Ui` already is — and the views clause disappears outright rather than getting shorter, because
`Main` is neither `Ui` nor `Presentation` and so nothing in a root selects into that scope at all.
A test pins that, since the predicate now reads as though the `…Screen.swift` suffix were sufficient.

**The rows stay judged, which was the constraint.** A scope rename un-judges the Unit and All rows
for a run, and they have been unjudged for three of them already. None is needed here: the predicate
selects the same files it always did — the roots moved, the rule did not — so the question each row
answers is unchanged and the ratchet keeps holding.

### What a root may hold, which is the half that is not about a name

A root is exempt from **both** coverage rows, so anything in one that a test would want to assert has
quietly stopped being visible as untested. `Server/App` was carrying two such things behind the
wiring, and neither was a layer's worth of code — which is exactly why they were easy to leave.

**A server host with four sentences nobody could reach.** `KeychainBackedServerHost` turned each
`ServerIdentityError` into a line a reader standing at the Mac acts on — *unlock the login keychain*
— and no test could produce any of them. It is now `TransportResolvingServerHost` in
`Server/Api/Presentation`, beside `ApiServerHost` and `RebindingOnWake`, which is where its siblings
already were. What made the move possible is that it resolves an **`ApiTransport`** rather than a
Keychain identity: the late-bound thing is then the same value the configuration already takes, the
module needs no `Data` dependency, and a host test drives every line of it with plaintext on
loopback. The per-run claim its own comment made — *asked per run, so a rebind after waking can fail
for a reason someone can act on* — is asserted now by counting resolutions across two runs, rather
than described.

**And a wake source that turned out not to need the exemption it was expected to need.**
`WorkspaceWakeNotifications` moved to `Server/Mac/Data`, beside the other conformers that read this
Mac, on the assumption that it would have to join `UNREACHABLE_FILES` — every line is AppKit, and
that list already carries `AppKitSystemGestures` for the same shape of reason. Checked rather than
assumed: `NSWorkspace.shared.notificationCenter` is an ordinary notification centre and a test may
post to it, so the one thing that makes a slept laptop reachable again is now covered by a test
instead of exempted from being one. Worth recording because the expectation was the opposite, and
because the exemption would have forced the scope rename this entry says was avoided.

Rejected: leaving both in the root and noting the exemption in a comment. That is what the root's
previous occupant did — `GranitaMacScene` carried a comment explaining a dead control for eight
releases — and a note beside untested code is not a substitute for a module that measures it.

