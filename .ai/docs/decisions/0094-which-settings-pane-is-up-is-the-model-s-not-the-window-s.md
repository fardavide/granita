# Which Settings pane is up is the model's, not the window's

`Pair…` on a refused connection row has exactly one job: bring the reader to the QR. Inside an open
window that is a tab switch rather than a settings request — an open window cannot open itself — and
the obvious way to build it is a `@State` on the screen.

That is the shape this project has already shipped a dead control in. A control whose only effect is
a `@State` two layers up is a control nothing can be asked about: no host test can reach it, and a
`TabView` hosted outside a `Settings` scene draws no tab bar, so no baseline can see it either. So
`SettingsTab` is a `ServerMacDomain` type and `ServerMacModel` owns the selection, which makes "the
control did something" an assertion rather than a claim.

It is also what §1 needs: the menu bar's *Pair a device…* has to open this window **on Devices**, so
`settingsRequests` will have to carry a pane rather than being a bare counter.

**What is still owed is pressing it.** The model transition is asserted; the closure that calls it is
one line in a `…Screen`, which no kind of test in this repository reaches — the macOS UI target
exists and has never been allowed to run. That is the same gap `decisions.md` records above, and it
closes with the Accessibility grant rather than with more unit tests.

