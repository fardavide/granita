# The logging layer lands without the two rows it unblocks, which inverts what was recorded

`decisions.md` said the verbose switch and *Open in Console* "land with the logging they describe".
The reason it gave is one-directional and still holds: a control over an absent subsystem reads as a
feature, gets pressed, and answers with a silence that looks like *nothing is wrong*. That forbids
rows before a layer. It does not forbid a layer before rows, and the split is now the other way for a
reason that is arithmetic rather than taste.

**Advanced's Diagnostics rows and the lock-file row move the same pictures.** Both change
`AdvancedSettingsView`'s eight baselines and the window's `serving-advanced` pair, and a Mac baseline
costs a full round trip through CI — push a placeholder, download the runner's render, adopt. Landing
them separately is two of those over one set of images. Landing them together is one.

So this pull request is the layer, and the next is both halves of what is left of §7.

**The layer is not inert while it waits**, which is what makes it a slice rather than scaffolding. A
note is never behind the switch — a git invocation that failed and a request that was refused are
written whatever the setting, because a fault a reader has to enable logging to see is one they learn
about after it mattered. What the switch will gate is the detail, and until the switch exists it is
`defaults write dev.fardavide.granita granita.diagnostics.verbose -bool YES`, which is the same key
the switch will write.

**Two decorators rather than two dependencies.** `LoggingGitClient` wraps a `GitClient` and
`DiagnosticsMiddleware` sits on the router, which keeps `ProcessGitClient` doing one thing and means
the libgit2 client the protocol exists for arrives logged without knowing it. It is the shape
`RebindingOnWake` already uses on the host.

**The decision about verbosity is in `Domain`, and the thing that writes to the system log has none
in it.** `VerbosityFilteringDiagnostics` drops the detail and passes notes through, asserted against
a fake; `OsLogDiagnostics` is two calls on `os.Logger`. That is the same split
`SystemSettingsPaneUrl` and `AppKitSystemGestures` already make, and it exists so the one question
worth asking — *did the switch being off hide that* — has an answer rather than a screenshot.

**The verbosity is read per line rather than captured.** The switch will be on a Settings pane and
the server reading it has been running since launch, so a copy taken at composition time would be a
switch that did nothing until the app was restarted — a control that appears to do nothing, on the
tab that exists to explain things.

**What is written is narrower than what is available, and that is the security boundary again.** The
git decorator logs the command and the checkout, never git's standard output, which is the contents
of a private repository. The middleware logs the method and the path, never the query or the body:
`/v1/pair` carries a live pairing code and `?projectID=` resolves to a folder on this Mac. Both are
asserted rather than described. The one exception is a failure's own text, which is git's standard
error — a sentence written for a person, and the rule this layer already follows everywhere.

**`os.Logger` redacts interpolation by default, and that is turned off here, narrowly.** A log full
of `<private>` is the failure this slice exists to prevent. It is safe precisely because of the
paragraph above: what reaches those two calls is a command name, a path on this Mac, a method and a
status.

**A test caught the shape of a refusal, which is why the middleware is on the router.** An
unauthenticated request does not return a 401 through the middleware — the authenticator throws, so
the refusal takes the note path and survives the switch being off. That is the better half to land
in, and it was written down as an assertion only because the first version of the test asserted the
other thing and failed.

**Detail is written at `.notice`, not `.debug`, and no test in this repository could have said so.**
`.debug` is the obvious level for it and the wrong one: the unified log does not persist debug lines,
so they are gone unless somebody enabled debug logging for the subsystem first. A reader who turns
the verbose switch on, presses *Open in Console* and meets an empty window has met the defect this
project cares most about — and every test would have stayed green, because a fake records what it was
handed whatever level it was written at. The level has nothing left to gate anyway, since
`VerbosityFilteringDiagnostics` decided before the line got here.

Confirmed by running `granita-server --add-project` and reading the lines back with `log show`, which
is also how the next fact was found.

**The two roots do not share a defaults domain, and pretending otherwise would have made the switch
look broken.** An executable has no bundle identifier, so `UserDefaults.standard` resolves to the
global domain for `granita-server` and to `dev.fardavide.granita.mac` for the menu bar app: the same
key, two places. Turning verbose on for one does not turn it on for the other. The app's switch is
the pane that lands next; the executable's is `defaults write -g`, and the changelog says both rather
than naming one and being wrong for whoever tried the other.

